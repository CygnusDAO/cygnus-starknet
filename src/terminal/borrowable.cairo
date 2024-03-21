//  SPDX-License-Identifier: AGPL-3.0-or-later
//
//  borrowable.cairo
//
//  Copyright (C) 2023 CygnusDAO
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════  
//   .              .            .               .      🛰️     .           .                .           .
//          █████████     🛰️      ---======*.                                                 .           ⠀
//         ███░░░░░███                                               📡                🌔                      . 
//        ███     ░░░  █████ ████  ███████ ████████   █████ ████  █████        ⠀
//       ░███         ░░███ ░███  ███░░███░░███░░███ ░░███ ░███  ███░░      .     .⠀           .           .
//       ░███          ░███ ░███ ░███ ░███ ░███ ░███  ░███ ░███ ░░█████       ⠀
//       ░░███     ███ ░███ ░███ ░███ ░███ ░███ ░███  ░███ ░███  ░░░░███              .             .⠀
//        ░░█████████  ░░███████ ░░███████ ████ █████ ░░████████ ██████     .----===*  ⠀
//         ░░░░░░░░░    ░░░░░███  ░░░░░███░░░░ ░░░░░   ░░░░░░░░ ░░░░░░            .                           .⠀
//                      ███ ░███  ███ ░███                .                 .                 .⠀
//       .             ░░██████  ░░██████        🛰️                        🛰️             .                 .     
//                      ░░░░░░    ░░░░░░      -------=========*                      .                     ⠀
//          .                            .       .          .            .                        .             .⠀
//       
//       BORROWABLE (CygUSD) - https://cygnusdao.finance                                                          .                     .
//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════
//
//  Smart contract to lend stbalecoins to liquidity providers.
//
//  Deposit USD, earn USD.
//
//  This is a Cairo implementation of the audited Cygnus Core contracts written originally in Solidity 0.8.9:
//  https://github.com/CygnusDAO/core
//
//  Both borrowable (this) and collateral contracts follow the exact same architecture:
//
//  Architecture of core (`borrowable.cairo` and `collateral.cairo`)
//    ├ 1. ERC20
//    ├ 2. Terminal
//    ├ 3. Control
//    ├ 4. Model
//    ├ 5. Strategy (ie. depositing LPs in a rewarder contract or depositing unused USDC in zkLend, etc.)
//    └ 6. Borrowable/Collateral
//
//  Structure of all Cygnus Contracts in Cairo:
//
//  Interface            (starknet::interface)
//  Module               (starknet::contract)
//    ├ 1. Imports           - Imports from starknet core lib/data structures/intefaces/etc.
//    ├ 2. Events            - Events to emit for imortant contract actions.      
//    ├ 3. Constructor       - Sets important variables upon initialization.
//    ├ 4. Storage           - Stores smart contract variables.
//    ├ 5. Implementation    - Exposes all functions defined in the interface above to users/other contracts
//    │     └ External        
//    └ 6. Internal Logic    - All private/internal functions that handle the logic of the implementation above
//          └ Internal            
//
//  Have fun!

/// # Title
/// * `CygnusBorrow`
///
/// # Description
/// * Smart contracts for stablecoin holders to lend their stablecoins to liquidity providers
///
/// # Author
/// * CygnusDAO
use starknet::ContractAddress;
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::data::interest::{InterestRateModel, BorrowSnapshot};
use cygnus::rewarder::pillars::{IPillarsOfCreationDispatcher, IPillarsOfCreationDispatcherTrait};

/// # Interface
/// * `IBorrowable`
#[starknet::interface]
trait IBorrowable<T> {
    /// --------------------------------------------------------------------------------------------------------
    ///                                          1. ERC20
    /// --------------------------------------------------------------------------------------------------------

    /// Open zeppeplin's implementation of erc20 with u128
    /// https://github.com/OpenZeppelin/cairo-contracts/blob/main/src/token/erc20/erc20.cairo
    ///
    /// commit-hash: 841a073

    /// Returns the name of the token.
    fn name(self: @T) -> felt252;

    /// Returns the ticker symbol of the token, usually a shorter version of the name.
    fn symbol(self: @T) -> felt252;

    /// Returns the number of decimals used to get its user representation.
    fn decimals(self: @T) -> u8;

    /// Returns the amount of tokens owned by `account`.
    fn balance_of(self: @T, account: ContractAddress) -> u128;
    fn balanceOf(self: @T, account: ContractAddress) -> u128;

    /// Returns the value of tokens in existence.
    fn total_supply(self: @T) -> u128;
    fn totalSupply(self: @T) -> u128;

    /// Returns the remaining number of tokens that `spender` is allowed to spend on behalf of `owner` 
    /// through `transfer_from`.
    /// This is zero by default. This value changes when `approve` or `transfer_from` are called.
    fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u128;

    /// Sets `amount` as the allowance of `spender` over the caller’s tokens.
    fn approve(ref self: T, spender: ContractAddress, amount: u128) -> bool;

    /// Moves `amount` tokens from the caller's token balance to `to`.
    /// Emits a `Transfer` event.
    fn transfer(ref self: T, recipient: ContractAddress, amount: u128) -> bool;

    /// Moves `amount` tokens from `from` to `to` using the allowance mechanism.
    /// `amount` is then deducted from the caller's allowance.
    /// Emits a `Transfer` event.
    fn transfer_from(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u128) -> bool;
    fn transferFrom(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u128) -> bool;

    /// Increases the allowance granted from the caller to `spender` by `added_value`.
    /// Emits an `Approval` event indicating the updated allowance.
    fn increase_allowance(ref self: T, spender: ContractAddress, added_value: u128) -> bool;
    fn increaseAllowance(ref self: T, spender: ContractAddress, added_value: u128) -> bool;

    /// Decreases the allowance granted from the caller to `spender` by `subtracted_value`.
    /// Emits an `Approval` event indicating the updated allowance.
    fn decrease_allowance(ref self: T, spender: ContractAddress, subtracted_value: u128) -> bool;
    fn decreaseAllowance(ref self: T, spender: ContractAddress, subtracted_value: u128) -> bool;

    /// --------------------------------------------------------------------------------------------------------
    ///                                          2. TERMINAL
    /// --------------------------------------------------------------------------------------------------------

    /// The factory which deploys pools and has all the important addresses on Starknet
    ///
    /// # Returns
    /// * The address of the factory contract
    fn hangar18(self: @T) -> ContractAddress;

    /// The underlying Stablecoin for this pool
    ///
    /// # Returns
    /// * The address of the stablecoin (USDC, DAI, etc.)
    fn underlying(self: @T) -> ContractAddress;

    /// Each borrowable only has 1 collateral
    ///
    /// # Returns
    /// * The address of the borrowable contract
    fn collateral(self: @T) -> ContractAddress;

    /// The oracle for the underlying LP
    ///
    /// # Returns
    /// * The address of the oracle that prices the LP token
    fn nebula(self: @T) -> ContractAddress;

    /// Unique lending pool ID, shared by the collateral arm
    ///
    /// # Returns
    /// * The lending pool ID
    fn shuttle_id(self: @T) -> u32;

    /// # Returns the total balance of the underlying deposited in the strategy
    fn total_balance(self: @T) -> u128;

    /// Returns the total USD assets held by the vault including assets currently being borrowed.
    /// (ie total_borrows + total_balance)
    fn total_assets(self: @T) -> u128;

    /// Returns the exchange rate between 1 unit of CygLP shares to assets. IE. How much USD
    /// can be redeemed by redeeming 1 unit of CygUSD shares, it should never be below 1e18.
    fn exchange_rate(self: @T) -> u128;

    /// Deposits underlying assets in the pool
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `assets` - The amount of assets to deposit
    /// * `recipient` - The address of the CygUSD recipient
    ///
    /// # Returns
    /// * The amount of shares minted
    fn deposit(ref self: T, assets: u128, recipient: ContractAddress) -> u128;


    /// Redeems CygUSD for USDC Tokens
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `shares` - The amount of shares to redeem
    /// * `recipient` - The address of the recipient of the assets
    /// * `owner` - The address of the owner of the shares
    ///
    /// # Returns
    /// * The amount of assets withdrawn
    fn redeem(ref self: T, shares: u128, recipient: ContractAddress, owner: ContractAddress) -> u128;

    /// Force sync our balance with the total deposited in the strategy
    ///
    /// # Security
    /// * Non-reentrant
    fn sync(ref self: T);

    /// --------------------------------------------------------------------------------------------------------
    ///                                          3. CONTROL 👽
    /// --------------------------------------------------------------------------------------------------------

    /// # Returns the maximum base rate allowed
    fn BASE_RATE_MAX(self: @T) -> u128;

    /// # Returns the maximum reserve factor allowed
    fn RESERVE_FACTOR_MAX(self: @T) -> u128;

    /// # Returns the minimum util rate allowed
    fn KINK_UTIL_MIN(self: @T) -> u128;

    /// # Returns the maximum util rate allowed
    fn KINK_UTIL_MAX(self: @T) -> u128;

    /// # Returns the maximum ink multiplier allowed
    fn KINK_MULTIPLIER_MAX(self: @T) -> u128;

    /// # Return Seconds per year not taking into account leap years
    fn SECONDS_PER_YEAR(self: @T) -> u128;

    /// The current reserve factor, which gets minted to the DAO Reserves (if > 0)
    ///
    /// # Returns
    /// The percentage of reserves the protocol keeps from borrows
    fn reserve_factor(self: @T) -> u128;

    /// We store the interest rate model as a struct which has the base, slope and kink
    ///
    /// # Returns
    /// The interest rate model struct
    fn interest_rate_model(self: @T) -> InterestRateModel;

    /// The CYG rewarder contract, can be 0
    ///
    /// # Returns
    /// * The owner contract of the CYG token allowed to mint
    fn pillars_of_creation(self: @T) -> ContractAddress;

    /// Setter for the reserve factor, can be 0
    ///
    /// # Security
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `new_reserve_factor` - The new reserve factor percentage
    fn set_reserve_factor(ref self: T, new_reserve_factor: u128);

    /// Setter for the interest rate model for this pool for this pool for this pool for this pool
    ///
    /// # Security
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `base_rate` - The new annualized base rate
    /// * `multiplier` - The new annualized slope
    /// * `kink_muliplier` - The kink multiplier when the util reaches the kink
    /// * `kink` - The point at which util increases steeply
    fn set_interest_rate_model(ref self: T, base_rate: u128, multiplier: u128, kink_muliplier: u128, kink: u128);

    /// Setter for the pillars of creation contract, allowed to be 0
    ///
    /// # Security
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `new_pillars` - The new CYG rewarder
    fn set_pillars_of_creation(ref self: T, new_pillars: IPillarsOfCreationDispatcher);

    /// --------------------------------------------------------------------------------------------------------
    ///                                          4. MODEL
    /// --------------------------------------------------------------------------------------------------------

    /// Uses borrow indices
    /// Returns the latest total borrows (with interest accrued)
    fn total_borrows(self: @T) -> u128;

    /// Uses borrow indices
    /// Returns the latest borrow index (with interest accrued)
    fn borrow_index(self: @T) -> u128;

    /// Uses borrow indices
    /// Returns the timestamp of the last accrual
    fn last_accrual_timestamp(self: @T) -> u64;

    /// Uses borrow indices
    /// # Returns
    /// * The current utilization rate
    fn utilization_rate(self: @T) -> u128;

    /// Uses borrow indices
    /// # Returns
    /// * The latest borrow rate per second (note: not annualized)
    fn borrow_rate(self: @T) -> u128;

    /// Uses borrow indices
    /// # Returns
    /// * The current supply rate for lenders, without taking into account strategy/rewards
    fn supply_rate(self: @T) -> u128;

    /// Uses borrow indices
    /// Reads from the BorrowSnapshot struct and uses the borrow indices to calculate
    /// the current borrows in real time
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    ///
    /// # Returns
    /// * The borrower's principal (ie the borrowed amount without interest rate)
    /// * The borrower's borrow balance (principal with interests)
    fn get_borrow_balance(self: @T, borrower: ContractAddress) -> (u128, u128);

    /// # Returns
    /// * The price of the stablecoin in USD
    fn get_usd_price(self: @T) -> u128;

    /// # Returns
    /// * The lender's CygUSD balance
    /// * The lender's USDC balance
    /// * The lender's position in USD (uses pragma to price USDC)
    fn get_lender_position(self: @T, lender: ContractAddress) -> (u128, u128, u128);

    /// Accrues interest for all borrowers, increasing `total_borrows` and storing the latest `borrow_rate`
    fn accrue_interest(ref self: T);

    /// Tracks the borrower's principal in the rewarder
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    fn track_borrower(ref self: T, borrower: ContractAddress);

    /// Tracks the lenders CygUSD balance in the rewarder
    ///
    /// # Arguments
    /// * `lender` - The address of the lender
    fn track_lender(ref self: T, lender: ContractAddress);

    /// Total position IDs
    fn all_positions_length(self: @T) -> u32;

    /// Get address of position ID
    fn all_positions(self: @T, position_id: u32) -> ContractAddress;

    /// --------------------------------------------------------------------------------------------------------
    ///                                          5. BORROWABLE
    /// --------------------------------------------------------------------------------------------------------

    /// Main function to borrow funds from the pool
    /// This function should be called from a periphery contract only
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower (pricing their collateral)
    /// * `receiver` - The address of the receiver of the borrowed funds
    /// * `borrow_amount` - The amount of stablecoins to borrow
    /// * `calldata` - Calldata passed for leverage/flash loans
    fn borrow(
        ref self: T, borrower: ContractAddress, receiver: ContractAddress, borrow_amount: u128, calldata: Array<felt252>
    ) -> u128;

    /// Main function to liquidate or flash liquidate a borrower.
    /// This function should be called from a periphery contract only
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower being liquidated
    /// * `receiver` - The address of the receiver of the liquidation bonus
    /// * `repay_amount` - The USD amount being repaid
    /// * `calldata` - Calldata passed for flash liquidating
    fn liquidate(
        ref self: T, borrower: ContractAddress, receiver: ContractAddress, repay_amount: u128, calldata: Array<felt252>
    ) -> u128;
}

/// # Module
/// * `Borrowable`
#[starknet::contract]
mod Borrowable {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::IBorrowable;
    use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::rewarder::pillars::{IPillarsOfCreationDispatcher, IPillarsOfCreationDispatcherTrait};
    use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};

    /// # Imports
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use cygnus::libraries::full_math_lib::FullMathLib::FixedPointMathLibTrait;
    use cygnus::data::interest::{InterestRateModel, BorrowSnapshot};

    /// # Errors
    use cygnus::terminal::errors::{BorrowableErrors as Errors};

    /// # Events
    use cygnus::terminal::events::BorrowableEvents::{
        Transfer, Approval, SyncBalance, Deposit, Withdraw, NewReserveFactor, NewInterestRateModel,
        NewPillarsOfCreation, AccrueInterest, Borrow, Liquidate
    };

    /// # Strategy
    use cygnus::voids::zklend::{
        IZKLendMarketDispatcher, IZKLendMarketDispatcherTrait, IZKTokenDispatcher, IZKTokenDispatcherTrait
    };

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        SyncBalance: SyncBalance,
        Deposit: Deposit,
        Withdraw: Withdraw,
        NewReserveFactor: NewReserveFactor,
        NewInterestRateModel: NewInterestRateModel,
        NewPillarsOfCreation: NewPillarsOfCreation,
        AccrueInterest: AccrueInterest,
        Borrow: Borrow,
        Liquidate: Liquidate
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Non-reentrant guard
        guard: bool,
        /// Decimals of the underlying, same as the vault's
        decimals: u8,
        /// Total supply of CygUSD
        total_supply: u128,
        /// Mapping of user => CygUSD balance
        balances: LegacyMap<ContractAddress, u128>,
        /// Mapping of (owner, spender) => allowance
        allowances: LegacyMap<(ContractAddress, ContractAddress), u128>,
        /// Opposite arm (ie. collateral)
        twin_star: ICollateralDispatcher,
        /// The address of the factory
        hangar18: IHangar18Dispatcher,
        /// The address of the underlying asset (ie a stablecoin)
        underlying: IERC20Dispatcher,
        /// The address of the oracle for this lending pool
        nebula: ICygnusNebulaDispatcher,
        /// The lending pool ID (shared by the collateral)
        shuttle_id: u32,
        /// Total balance of the underlying deposited in the strategy (ie. total cash)
        total_balance: u128,
        /// The CYG rewarder contract
        pillars_of_creation: IPillarsOfCreationDispatcher,
        /// The current interest rate model set
        interest_rate_model: InterestRateModel,
        /// The current reserve Factor
        reserve_factor: u128,
        /// Struct that stores users => (principal, borrows)
        borrow_balances: LegacyMap<ContractAddress, BorrowSnapshot>,
        /// timestamp of the last interest accrual
        last_accrual_timestamp: u64,
        /// Total borrows stored
        total_borrows: u128,
        /// Borrow index stored
        borrow_index: u128,
        /// ZK Lend Market contract - Where we deposit/withdraw
        zk_lend_market: IZKLendMarketDispatcher,
        /// ZK Lend USDC contract - Rebase token
        zk_lend_usdc: IERC20Dispatcher,
        /// Borrow positions length
        all_positions_length: u32,
        /// Id to borrower
        all_positions: LegacyMap<u32, ContractAddress>,
        /// Mapping if borrower
        is_borrower: LegacyMap<ContractAddress, bool>
    }

    /// The maximum possible base rate set by admin
    const BASE_RATE_MAX: u128 = 100000000000000000; // 0.1e18 = 10%
    /// The minimum possible kink util rate
    const KINK_UTIL_MIN: u128 = 700000000000000000; // 0.7e18 = 70%
    /// The maximum possible kink util rate
    const KINK_UTIL_MAX: u128 = 990000000000000000; // 0.99e18 = 99%
    /// To calculate annual interest rates
    const SECONDS_PER_YEAR: u128 = 31_536_000;
    /// The maximum possible reserve factor set by admin
    const RESERVE_FACTOR_MAX: u128 = 200000000000000000; // 0.2e18 = 20%
    /// The max kink multiplier
    const KINK_MULTIPLIER_MAX: u128 = 40;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(
        ref self: ContractState,
        hangar18: IHangar18Dispatcher,
        underlying: IERC20Dispatcher,
        collateral: ICollateralDispatcher,
        oracle: ICygnusNebulaDispatcher,
        shuttle_id: u32
    ) {
        self._initialize(hangar18, underlying, collateral, oracle, shuttle_id);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl CygnusBorrow of IBorrowable<ContractState> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                          1. ERC20
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IBorrowable
        fn name(self: @ContractState) -> felt252 {
            'Cygnus: Borrowable'
        }

        /// # Implementation
        /// * IBorrowable
        fn symbol(self: @ContractState) -> felt252 {
            'CygUSD'
        }

        /// # Implementation
        /// * IBorrowable
        fn decimals(self: @ContractState) -> u8 {
            /// Always use decimals of the underlying (6 for USDC, 18 for DAI, etc.)
            self.underlying.read().decimals()
        }

        /// # Implementation
        /// * IBorrowable
        fn total_supply(self: @ContractState) -> u128 {
            self.total_supply.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn totalSupply(self: @ContractState) -> u128 {
            self.total_supply.read()
        }


        /// # Implementation
        /// * IBorrowable
        fn balance_of(self: @ContractState, account: ContractAddress) -> u128 {
            self.balances.read(account)
        }

        /// # Implementation
        /// * IBorrowable
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u128 {
            self.balances.read(account)
        }


        /// # Implementation
        /// * IBorrowable
        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u128 {
            self.allowances.read((owner, spender))
        }

        /// # Implementation
        /// * IBorrowable
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }

        /// # Implementation
        /// * IBorrowable
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u128) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * IBorrowable
        fn transfer_from(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u128
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * IBorrowable
        fn transferFrom(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u128
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }


        /// # Implementation
        /// * IBorrowable
        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u128) -> bool {
            self._increase_allowance(spender, added_value)
        }

        /// # Implementation
        /// * IBorrowable
        fn increaseAllowance(ref self: ContractState, spender: ContractAddress, added_value: u128) -> bool {
            self._increase_allowance(spender, added_value)
        }

        /// # Implementation
        /// * IBorrowable
        fn decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u128) -> bool {
            self._decrease_allowance(spender, subtracted_value)
        }

        /// # Implementation
        /// * IBorrowable
        fn decreaseAllowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u128) -> bool {
            self._decrease_allowance(spender, subtracted_value)
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                          2. TERMINAL
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IBorrowable
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * IBorrowable
        fn underlying(self: @ContractState) -> ContractAddress {
            self.underlying.read().contract_address
        }

        /// # Implementation
        /// * IBorrowable
        fn collateral(self: @ContractState) -> ContractAddress {
            self.twin_star.read().contract_address
        }

        /// # Implementation
        /// * IBorrowable
        fn nebula(self: @ContractState) -> ContractAddress {
            self.nebula.read().contract_address
        }

        /// # Implementation
        /// * IBorrowable
        fn shuttle_id(self: @ContractState) -> u32 {
            self.shuttle_id.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn total_balance(self: @ContractState) -> u128 {
            self.total_balance.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn total_assets(self: @ContractState) -> u128 {
            /// When called externally we always simulate accrual.
            self._total_assets(accrue: true)
        }

        /// # Implementation
        /// * IBorrowable
        fn exchange_rate(self: @ContractState) -> u128 {
            /// Get supply of CygUSD
            let supply = self.total_supply.read();

            // If no supply return shares 
            if supply == 0 {
                return 1_000_000_000_000_000_000;
            }

            /// Return the exhcange rate between 1 CygLP and LP assets (ie. how much LP can be redeemed
            /// for 1 unit of CygUSD)
            return self.total_assets().div_wad(supply);
        }

        /// Transfers USDC from caller and mints them shares. Deposits all USDC into
        /// zkLend's USDC pool.
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn deposit(ref self: ContractState, assets: u128, recipient: ContractAddress) -> u128 {
            /// Locks, accrues and updates our balance
            self._lock_accrue_update();

            /// Convert underlying assets to CygUSD shares
            let mut shares = self._convert_to_shares(assets);

            /// # Error
            /// * `CANT_MINT_ZERO` - Reverts if minting 0 shares
            assert(shares > 0, Errors::CANT_MINT_ZERO);

            /// Get caller address and contract address
            let caller = get_caller_address();
            let receiver = get_contract_address();

            // Transfer USD to vault
            self.underlying.read().transferFrom(caller, receiver, assets.into());

            // Burn 1000 shares to address zero, this is only for the first depositor
            if (self.total_supply.read() == 0) {
                shares -= 1000;
                self._mint(Zeroable::zero(), 1000);
            }

            /// Mint CygUSD
            self._mint(recipient, shares);

            /// Deposit USDC in strategy
            self._after_deposit(assets);

            /// # Event
            /// * Deposit
            self.emit(Deposit { caller, recipient, assets, shares });

            /// Unlock reentrant guard and update our balance
            self._update_unlock();

            shares
        }

        /// Converts `shares` to USDC assets, withdraws assets from zkLend's USDC pool
        /// and sends assets to `recipient`
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn redeem(ref self: ContractState, shares: u128, recipient: ContractAddress, owner: ContractAddress) -> u128 {
            /// Locks, accrues and updates our balance
            self._lock_accrue_update();

            /// Get sender
            let caller = get_caller_address();

            /// Check for allowance
            if caller != owner {
                self._spend_allowance(owner, caller, shares);
            }

            /// Convert to assets
            let assets = self._convert_to_assets(shares);

            /// # Error
            /// * `CANT_REDEEM_ZERO` - Avoid withdrawing 0 assets
            assert(assets != 0, Errors::CANT_REDEEM_ZERO);

            /// Withdraw from strategy
            self._before_withdraw(assets);

            // Burn CygUSD and transfer stablecoin
            self._burn(owner, shares);

            /// Transfer usd to recipient
            self.underlying.read().transfer(recipient, assets.into());

            /// # Event
            /// * Withdraw
            self.emit(Withdraw { caller, recipient, owner, assets, shares });

            // Unlock
            self._update_unlock();

            assets
        }

        /// Force a sync and update our total balance deposited in the strategy
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn sync(ref self: ContractState) {
            /// Locks, accrues and updates our balance
            self._lock_accrue_update();

            /// Unlock
            self.guard.write(false);
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                          3. CONTROL
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IBorrowable
        fn BASE_RATE_MAX(self: @ContractState) -> u128 {
            BASE_RATE_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn RESERVE_FACTOR_MAX(self: @ContractState) -> u128 {
            RESERVE_FACTOR_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn KINK_UTIL_MIN(self: @ContractState) -> u128 {
            KINK_UTIL_MIN
        }

        /// # Implementation
        /// * IBorrowable
        fn KINK_UTIL_MAX(self: @ContractState) -> u128 {
            KINK_UTIL_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn KINK_MULTIPLIER_MAX(self: @ContractState) -> u128 {
            KINK_MULTIPLIER_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn SECONDS_PER_YEAR(self: @ContractState) -> u128 {
            SECONDS_PER_YEAR
        }

        /// # Implementation
        /// * IBorrowable
        fn reserve_factor(self: @ContractState) -> u128 {
            self.reserve_factor.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn interest_rate_model(self: @ContractState) -> InterestRateModel {
            self.interest_rate_model.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn pillars_of_creation(self: @ContractState) -> ContractAddress {
            self.pillars_of_creation.read().contract_address
        }

        /// Sets a new interest rate model
        ///
        /// # Security
        /// * Only-admin 👽
        ///
        /// # Implementation
        /// * IBorrowable
        fn set_interest_rate_model(
            ref self: ContractState, base_rate: u128, multiplier: u128, kink_muliplier: u128, kink: u128
        ) {
            // Check admin
            self._check_admin();

            // Set model internally, emits event
            self._interest_rate_model(base_rate, multiplier, kink_muliplier, kink);
        }

        /// Sets a new reserve factor for the pool
        ///
        /// # Security
        /// * Only-admin 👽
        ///
        /// # Implementation
        /// * IBorrowable
        fn set_reserve_factor(ref self: ContractState, new_reserve_factor: u128) {
            // Check sender is admin
            self._check_admin();

            /// # Error
            /// `INVALID_RANGE` - Avoid if reserve factor is above max range allowed
            assert(new_reserve_factor <= RESERVE_FACTOR_MAX, Errors::INVALID_RANGE);

            // Get reserve factor until now
            let old_reserve_factor = self.reserve_factor.read();

            // Write reserve factor to storage
            self.reserve_factor.write(new_reserve_factor);

            /// # Event
            /// * `NewReserveFactor`
            self.emit(NewReserveFactor { old_reserve_factor, new_reserve_factor });
        }

        /// Sets the pillars of creation contract. This is allowed to be zero as we do checks for zero
        /// address in case it's inactive.
        ///
        /// # Security
        /// * Only-admin 👽
        ///
        /// # Implementation
        /// * IBorrowable
        fn set_pillars_of_creation(ref self: ContractState, new_pillars: IPillarsOfCreationDispatcher) {
            // Check sender is admin
            self._check_admin();

            /// Address of CYG rewarder until now
            let old_pillars = self.pillars_of_creation.read();

            /// Write new pillars to storage
            self.pillars_of_creation.write(new_pillars);

            /// # Event
            /// * NewPillarsOfCreation
            self.emit(NewPillarsOfCreation { old_pillars, new_pillars });
        }

        ///----------------------------------------------------------------------------------------------------
        ///                                          4. MODEL
        ///----------------------------------------------------------------------------------------------------

        /// Uses borrow indices
        ///
        /// # Implmentation
        /// * IBorrowable
        fn total_borrows(self: @ContractState) -> u128 {
            // Get latest borrows from indices (simulates accrual)
            let (_, total_borrows, _, _, _) = self._borrow_indices();

            total_borrows
        }

        /// Uses borrow indices
        ///
        /// # Implmentation
        /// * IBorrowable
        fn borrow_index(self: @ContractState) -> u128 {
            // Get latest index from indices
            let (_, _, index, _, _) = self._borrow_indices();

            index
        }

        /// Uses borrow indices
        ///
        /// # Implmentation
        /// * IBorrowable
        fn last_accrual_timestamp(self: @ContractState) -> u64 {
            self.last_accrual_timestamp.read()
        }

        /// Uses borrow indices
        ///
        /// # Implementation
        /// * IBorrowable
        fn utilization_rate(self: @ContractState) -> u128 {
            /// Get the latest borrow indices
            let (cash, borrows, _, _, _) = self._borrow_indices();

            /// Avoid divide by 0
            if borrows == 0 {
                return 0;
            }

            /// We do not take into account reserves as we mint CygUSD
            borrows.div_wad(cash + borrows)
        }

        /// Uses borrow indices
        ///
        /// # Implementation
        /// * IBorrowable
        fn borrow_rate(self: @ContractState) -> u128 {
            // Get the current borrows with interest
            // Calculates the borrow rate with the stored borrows and simulate interest accrual
            // up to this point.
            let (cash, borrows, _, _, _) = self._borrow_indices();

            // Calculates the latest borrow rate with the new increased borrows
            self._borrow_rate(cash, borrows)
        }

        /// Uses borrow indices
        ///
        /// # Implementation
        /// * IBorrowable
        fn supply_rate(self: @ContractState) -> u128 {
            // Get the current borrows with interest
            // Calculates the borrow rate with the stored borrows and simulate interest accrual
            // up to this point.
            let (cash, borrows, _, _, _) = self._borrow_indices();

            // Calculates the latest borrow rate with the new increased borrows
            let borrow_rate = self._borrow_rate(cash, borrows);

            /// slope = Borrow Rate * (1e18 - reserve_factor)
            let one_minus_reserves = 1_000000000_000000000 - self.reserve_factor.read();
            let rate_to_pool = borrow_rate.mul_wad(one_minus_reserves);

            /// Avoid divide by 0
            if (borrows == 0) {
                return 0;
            }

            /// Get util
            let util = borrows.div_wad(cash + borrows);

            /// Supply rate is slope * util
            util.mul_wad(rate_to_pool)
        }

        /// # Implementation
        /// * IBorrowable
        fn get_usd_price(self: @ContractState) -> u128 {
            self.nebula.read().denomination_token_price()
        }

        /// # Implementation
        /// * IBorrowable
        fn get_lender_position(self: @ContractState, lender: ContractAddress) -> (u128, u128, u128) {
            let cyg_usd_balance = self.balances.read(lender);
            let underlying_balance = cyg_usd_balance.mul_wad(self.exchange_rate());
            let usd_balance = underlying_balance.mul_wad(self.get_usd_price());

            (cyg_usd_balance, underlying_balance, usd_balance)
        }

        /// Uses borrow indices
        ///
        /// # Implementation
        /// * IBorrowable
        fn get_borrow_balance(self: @ContractState, borrower: ContractAddress) -> (u128, u128) {
            // Simulate accrue
            self._borrow_balance(borrower, accrue: true)
        }

        /// # implementation
        /// * iborrowable
        fn all_positions_length(self: @ContractState) -> u32 {
            self.all_positions_length.read()
        }

        /// # implementation
        /// * iborrowable
        fn all_positions(self: @ContractState, position_id: u32) -> ContractAddress {
            self.all_positions.read(position_id)
        }

        /// # Implementation
        /// * IBorrowable
        fn accrue_interest(ref self: ContractState) {
            /// Accrue internally
            self._accrue();
        }

        /// # Implementation
        /// * IBorrowable
        fn track_borrower(ref self: ContractState, borrower: ContractAddress) {
            /// Borrower's receive rewards based on their principal (ie. borrowed amount) so no need to accrue
            let (principal, _) = self._borrow_balance(borrower, false);

            /// Pass balance internally, checks if pillars exists
            self._track_rewards(borrower, principal, self.twin_star.read().contract_address);
        }

        /// # Implementation
        /// * IBorrowable
        fn track_lender(ref self: ContractState, lender: ContractAddress) {
            /// Get lender's CygUSD balance
            let balance = self.balance_of(lender);

            /// Pass balance internally, checks if pillars exists
            self._track_rewards(lender, balance, Zeroable::zero());
        }

        ///----------------------------------------------------------------------------------------------------
        ///                                          5. BORROWABLE
        ///----------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IBorrowable
        ///
        /// # Security
        /// * Non-reentrant
        fn borrow(
            ref self: ContractState,
            borrower: ContractAddress,
            receiver: ContractAddress,
            borrow_amount: u128,
            calldata: Array<felt252>,
        ) -> u128 {
            /// Lock, accrue  and update
            self._lock_accrue_update();

            /// Check that caller has allowance to borrow on behalf of `borrower`
            /// We use the same allowance as redeem.
            let caller = get_caller_address();

            if borrower != caller {
                self._spend_allowance(borrower, caller, borrow_amount);
            }

            /// ────────── 1. Check amount and optimistically send `borrow_amount` to `receiver`
            /// We optimistically transfer borrow amounts and check in step 5 if borrower has enough 
            /// liquidity to borrow. We allow for flash loans only if repaid amount is greater than
            /// borrow amount and we skip step 5
            if borrow_amount > 0 {
                /// Withdraw from strategy
                self._before_withdraw(borrow_amount);

                /// Transfer USD to `receiver`
                self.underlying.read().transfer(receiver, borrow_amount.into());
            }

            /// Helper return val to simulate transaction or make static call to check the amount of LP
            /// received, has no meaning in the function itself.
            let mut liquidity = 0;

            /// ────────── 2. Pass data to the router if needed
            /// Check data for leverage transaction, if any pass data to router. `liquidity` is the 
            /// amount of LP received. Return var to work with a router, has no effect on this function 
            /// itself.

            /// Pass data to caller if necessary
            if calldata.len() > 0 {
                /// Get the caller address, should be any contract that subscribes to the IAltairCall interface
                let altair = IAltairDispatcher { contract_address: caller };

                /// Pass calldata to router
                liquidity = altair.altair_borrow_09E(caller, borrow_amount, calldata);
            }

            /// ────────── 3. Get the repay amount (if any)
            /// Borrow/Repay use this same function. To repay the loan the user must have sent back stablecoins 
            /// to this contract. The borrowable contract should never have any stablecoin assets itself (all is
            /// either being borrowed or deposited in zkLend), so we check for balance of stablecoin in case of repay.
            let repay_amount = self._check_balance(self.underlying.read());

            /// ────────── 4. Update borrow internally with borrowAmount and repayAmount
            /// Update internal record for `borrower` with borrow and repay amount
            let account_usd = self._update_borrow(borrower, borrow_amount, repay_amount);

            /// ────────── 5. Do checks for borrow and repay transactions
            /// Borrow transaction. Check that the borrower has sufficient collateral after borrowing 
            /// `borrowAmount` by passing `accountBorrows` to the collateral contract
            if borrow_amount > repay_amount {
                /// The collateral contract prices the user's deposited liquidity in USD. If the borrowed
                /// amount (+ current borrow balance) would put the user in shortfall then it returns false
                let can_borrow: bool = self.twin_star.read().can_borrow(borrower, account_usd);

                /// # Error
                /// * `INSUFFICIENT_LIQUIDITY` - Revert if user has insufficient collateral amount for this loan
                assert(can_borrow, Errors::INSUFFICIENT_LIQUIDITY);
            }

            /// ────────── 6. Deposit in strategy
            /// Deposit underlying in strategy (only from repay transaction)
            if repay_amount > 0 {
                self._after_deposit(repay_amount);
            };

            /// # Event
            /// * `Borrow`
            self.emit(Borrow { caller, borrower, receiver, borrow_amount, repay_amount });

            /// Unlock
            self._update_unlock();

            liquidity
        }

        /// # Implementation
        /// * IBorrowable
        ///
        /// # Security
        /// * Non-reentrant
        fn liquidate(
            ref self: ContractState,
            borrower: ContractAddress,
            receiver: ContractAddress,
            repay_amount: u128,
            calldata: Array<felt252>
        ) -> u128 {
            /// Lock, accrue  and update
            self._lock_accrue_update();

            /// Get the sender address - We need this for the router to allow flash liquidations
            let caller = get_caller_address();

            /// ────────── 1. Get borrower's latest USD debt - `update` accrued interest before this call
            /// Latest borrow balance - We have already accured so its guaranteed to be the latest balance
            let (_, borrow_balance) = self._borrow_balance(borrower, accrue: false);

            /// Make sure that the amount being repaid is never more than the borrower's borrow balance
            let max = if repay_amount > borrow_balance {
                borrow_balance
            } else {
                repay_amount
            };

            /// ────────── 2. Seize CygLP from borrower
            /// CygLP = (max * liq. incentive) / lp price.
            /// Reverts at Collateral if:
            /// - `max` is 0.
            /// - `borrower`'s position is not in liquidatable state
            let cyg_lp_amount = self.twin_star.read().seize_cyg_lp(receiver, borrower, max);

            /// ────────── 3. Check for data length in case sender sells the collateral to market
            /// If the `receiver` was the router used to flash liquidate then we call the router 
            /// with the data passed, allowing the collateral to be sold to the market
            /// Pass data to caller if necessary
            if calldata.len() > 0 {
                /// Get the caller address, should be any contract that subscribes to the IAltairCall interface
                let altair = IAltairDispatcher { contract_address: caller };

                /// Pass calldata to router
                altair.altair_liquidate_f2x(caller, cyg_lp_amount, max, calldata);
            }

            /// ────────── 4. Get the repaid amount of USD
            /// Our balance of USD not deposited in strategy (if sell to market then router must 
            /// have sent back USD).
            /// The amount received back would have to be equal at least to `max`, allowing liquidator to 
            /// keep the liquidation incentive
            let amount_usd = self._check_balance(self.underlying.read());

            /// # Error
            /// * `INSUFFICIENT_USD_RECEIVED` - Reverts if we received less USD than declared
            assert(amount_usd >= max, Errors::INSUFFICIENT_USD_RECEIVED);

            /// ────────── 5. Update borrow internally with 0 borrow amount and the amount of usd received
            /// Pass to CygnusBorrowModel
            self._update_borrow(borrower, 0, amount_usd);

            /// ────────── 6. Deposit in strategy
            /// Deposit underlying in strategy, if 0 then would've reverted by now
            self._after_deposit(repay_amount);

            /// # Event
            /// * `Liquidate`
            self.emit(Liquidate { caller, borrower, receiver, cyg_lp_amount, max, amount_usd });

            /// Unlock
            self._update_unlock();

            amount_usd
        }
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// Constructor logic
    /// 1. Set immutable variables
    /// 2. Set default borrowable control parameters
    /// 3. Set strategy
    #[generate_trait]
    impl ConstructorImpl of ConstructorTrait {
        fn _initialize(
            ref self: ContractState,
            hangar18: IHangar18Dispatcher,
            underlying: IERC20Dispatcher,
            collateral: ICollateralDispatcher,
            oracle: ICygnusNebulaDispatcher,
            shuttle_id: u32
        ) {
            /// The factory used as control centre
            self.hangar18.write(hangar18);

            /// The underlying stablecoin address
            self.underlying.write(underlying);

            /// The collateral address
            self.twin_star.write(collateral);

            /// The oracle used to price the LP
            self.nebula.write(oracle);

            /// The lending pool ID
            self.shuttle_id.write(shuttle_id);

            /// Borrowable defaults
            self._set_default_borrowable();
        }

        /// Sets the default borrowable values (reserve rate, interest rate, etc.)
        /// Called only in the constructor
        fn _set_default_borrowable(ref self: ContractState) {
            // Store the default borrow index as 1 and the current timestamp 
            self.borrow_index.write(1_000_000_000_000_000_000);
            self.last_accrual_timestamp.write(get_block_timestamp());
            self.reserve_factor.write(200000000000000000); // 0.20e18 = 20%

            /// Initialize borrowable strategy, in this case we use zkLend
            self._initialize_void();
        }

        /// Initialize Strategy
        fn _initialize_void(ref self: ContractState) {
            /// The ZKLend Market contract, which allows users to deposit/withdraw from the markets.
            let zk_lend_market = IZKLendMarketDispatcher {
                contract_address: starknet::contract_address_const::<
                    0x04c0a5193d58f74fbace4b74dcf65481e734ed1714121bdc571da345540efa05
                >()
            };

            /// We approve the zkmarket contract to move our USDC
            /// As soon as users deposit into Cygnus / we deposit the USDC into zkLend through the Market contract, 
            /// so it must have allowance / to move our USDC.
            self.underlying.read().approve(zk_lend_market.contract_address.into(), integer::BoundedInt::max());

            /// This is the zk token that represents our deposits in the market. It is a rebase token that
            /// is received by the vault when we deposit USDC. IMPORTANT: We must disallow admin to move
            /// this token when sweeping incorrect erc20 transfers to this contract, or else malicious admin
            /// can have control of the vault!
            let zk_lend_usdc = IERC20Dispatcher {
                contract_address: starknet::contract_address_const::<
                    0x047ad51726d891f972e74e4ad858a261b43869f7126ce7436ee0b2529a98f486
                >()
            };

            /// Write the market to storage
            self.zk_lend_market.write(zk_lend_market);

            /// Write zUSDC share token to storage
            self.zk_lend_usdc.write(zk_lend_usdc);
        }
    }

    ///----------------------------------------------------------------------------------------------------
    ///                                          LOGIC - ERC20
    ///----------------------------------------------------------------------------------------------------

    /// # Implementation
    /// * `ERC20`
    #[generate_trait]
    impl ERC20Impl of ERC20InternalTrait {
        /// Internal method that sets `amount` as the allowance of `spender` over the
        /// `owner`s tokens.
        /// Emits an `Approval` event.
        fn _approve(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u128) {
            assert(!owner.is_zero(), Errors::APPROVE_FROM_ZERO);
            assert(!spender.is_zero(), Errors::APPROVE_TO_ZERO);
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        /// Updates `owner`s allowance for `spender` based on spent `amount`.
        /// Does not update the allowance value in case of infinite allowance.
        /// Possibly emits an `Approval` event.
        fn _spend_allowance(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u128) {
            let current_allowance = self.allowances.read((owner, spender));
            if current_allowance != integer::BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }

        /// Emits a `Transfer` event.
        fn _transfer(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u128) {
            assert(!sender.is_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(!recipient.is_zero(), Errors::TRANSFER_TO_ZERO);
            self.balances.write(sender, self.balances.read(sender) - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self._after_token_transfer(sender, recipient, amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        /// Internal method for the external `increase_allowance`.
        /// Emits an `Approval` event indicating the updated allowance.
        fn _increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self.allowances.read((caller, spender)) + added_value);
            true
        }

        /// Internal method for the external `decrease_allowance`.
        /// Emits an `Approval` event indicating the updated allowance.
        fn _decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self.allowances.read((caller, spender)) - subtracted_value);
            true
        }

        /// Add mint, burn, after_transfer, before_transfer
        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u128) {
            self.total_supply.write(self.total_supply.read() + amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self._after_token_transfer(Zeroable::zero(), recipient, amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u128) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self.total_supply.write(self.total_supply.read() - amount);
            self.balances.write(account, self.balances.read(account) - amount);
            self._after_token_transfer(account, Zeroable::zero(), amount);
            self.emit(Transfer { from: account, to: Zeroable::zero(), value: amount });
        }

        /// Hook to use after any transfer, mint, transfer_from, burn function.
        /// Gets the lender's balance of CygUSD after the transaction to pass to the rewarder and update
        /// CYG rewards for lender. The rewarder is always in sync with user's balance to adjust rewards.
        ///
        /// # Arguments
        /// * `account` - The address of where the tokens are being sent from
        /// * `to` - The address of the receiver
        /// * `amount` - The amount being transferred
        fn _after_token_transfer(ref self: ContractState, account: ContractAddress, to: ContractAddress, amount: u128) {
            /// Check that account is not zero (in case of mints)
            if !account.is_zero() {
                /// Pass to pillars
                self.track_lender(account);
            }

            /// Check that receiver is not zero (in case of burns)
            if !to.is_zero() {
                /// Pass to pillars
                self.track_lender(to);
            }
        }
    }

    ///----------------------------------------------------------------------------------------------------
    ///                                          LOGIC - TERMINAL
    ///----------------------------------------------------------------------------------------------------

    /// Internal logic that handles the terminal vault token (CygUSD)
    #[generate_trait]
    impl TerminalImpl of TerminalTrait {
        /// Checks that caller is admin
        fn _check_admin(self: @ContractState) {
            /// Get admin from factory
            let admin = self.hangar18.read().admin();

            /// # Error
            /// * `CALLER_NOT_ADMIN` - Reverts if caller is not hangar18's admin
            assert(get_caller_address() == admin, Errors::CALLER_NOT_ADMIN);
        }

        /// Gets the total assets owned by the borrowable vault, ie. total cash + total borrows
        /// 
        /// # Arguments
        /// * `accrue` - Whether we should simulate accrual or not, gas savings
        ///
        /// # Returns
        /// * The total cash deposited in the strategy + the total borrows stored
        fn _total_assets(self: @ContractState, accrue: bool) -> u128 {
            /// Check if we should simulate accrual using indices, avoid when called internally
            if (accrue) {
                /// Total cash
                let balance = self._preview_total_balance();
                /// Latest borrows with interest accrued
                let (_, borrows, _, _, _) = self._borrow_indices();

                return balance + borrows;
            }

            /// Read directly from storage
            self.total_balance.read() + self.total_borrows.read()
        }

        /// Convert CygUSD shares to USD assets
        ///
        /// # Arguments
        /// * `shares` - The amount of CygUSD shares to convert to USD
        ///
        /// # Returns
        /// * The assets equivalent of shares
        #[inline(always)]
        fn _convert_to_assets(self: @ContractState, shares: u128) -> u128 {
            // Gas savings
            let supply = self.total_supply.read();

            // If no supply return shares 
            if supply == 0 {
                return shares;
            }

            // We have already accrued interest since we use `lock_and_update`
            // in redeem, so pass false to avoid loading indicies again and save gas
            // assets = shares * balance / total supply
            shares.full_mul_div(self._total_assets(accrue: false), supply)
        }

        /// Convert USD assets to CygUSD shares - We have already accrued interest
        ///
        /// # Arguments
        /// * `assets` - The amount of USD assets to convert to CygUSD shares
        ///
        /// # Returns
        /// * The shares equivalent of assets
        #[inline(always)]
        fn _convert_to_shares(self: @ContractState, assets: u128) -> u128 {
            // Gas savings
            let supply = self.total_supply.read();

            // If no supply return assets
            if supply == 0 {
                return assets;
            }

            // We have already accrued interest since we use `lock_and_update`
            // in deposit, so pass false to avoid loading indicies again and save gas
            // shares = assets * supply / balance
            assets.full_mul_div(supply, self._total_assets(accrue: false))
        }

        /// Syncs the `total_balance` variable with the currently deposited cash in the strategy.
        /// This should be called after any payable action, and before to prevent deposit spams into
        /// the vault.
        #[inline(always)]
        fn _update(ref self: ContractState) {
            /// Get our cash currently deposited in the strategy
            let balance = self._preview_total_balance();

            /// Update cash to storage
            self.total_balance.write(balance);

            /// # Event
            /// * `SyncBalance`
            self.emit(SyncBalance { balance });
        }
    }

    ///----------------------------------------------------------------------------------------------------
    ///                                          LOGIC - CONTROL
    ///----------------------------------------------------------------------------------------------------

    /// Control
    #[generate_trait]
    impl ControlImpl of ControlTrait {
        /// Updates the interest rate model internally
        ///
        /// # Arguments
        /// * `base_rate` - The annualized base rate
        /// * `multiplier` - The annualized multiplier
        /// * `kink_multiplier` - The kink multiplier
        /// * `kink` - The point at which the borrow rate goes steep
        fn _interest_rate_model(
            ref self: ContractState, base_rate: u128, multiplier: u128, kink_muliplier: u128, kink: u128
        ) {
            /// # Error
            /// * `INVALID_RANGE` - Avoid if not within range
            assert(base_rate < BASE_RATE_MAX, Errors::INVALID_RANGE);
            assert(kink >= KINK_UTIL_MIN && kink <= KINK_UTIL_MAX, Errors::INVALID_RANGE);
            assert(kink_muliplier <= KINK_MULTIPLIER_MAX, Errors::INVALID_RANGE);

            // The annualized slope of the interest rate
            let slope = multiplier.div_wad(SECONDS_PER_YEAR * kink);

            // Create interest rate model struct
            let interest_rate_model: InterestRateModel = InterestRateModel {
                base_rate_per_second: (base_rate / SECONDS_PER_YEAR).try_into().unwrap(),
                multiplier_per_second: slope.try_into().unwrap(),
                jump_multiplier_per_second: (slope * kink_muliplier).try_into().unwrap(),
                kink: kink.try_into().unwrap()
            };

            // Write to storage
            self.interest_rate_model.write(interest_rate_model);

            /// # Event
            /// * `NewInterestRateModel`
            self.emit(NewInterestRateModel { base_rate, multiplier, kink_muliplier, kink });
        }
    }

    ///----------------------------------------------------------------------------------------------------
    ///                                          LOGIC - MODEL
    ///----------------------------------------------------------------------------------------------------

    /// CygnusBorrowModel
    ///
    /// Logic for borrowable model
    #[generate_trait]
    impl ModelImpl of ModelTrait {
        /// Calculates the utilization rate of the pool
        ///
        /// # Arguments
        /// * `cash` - Total cash deposited in the strategy
        /// * `borrows` - Total current borrows from the pool
        ///
        /// # Returns
        /// * The utilization rate of the pool (ie. borrows / (cash + borrows))
        fn _utilization_rate(self: @ContractState, cash: u128, borrows: u128) -> u128 {
            // Avoid divide by 0
            if borrows.is_zero() {
                return 0;
            }

            borrows.div_wad(cash + borrows)
        }

        /// Mints reserves interally if reserve rate is set
        ///
        /// # Arguments
        /// * `interest_accumulated` - The amount of interest accumulated since last accrual
        ///
        /// # Returns
        /// * The amount of shares minted to the DAO Reserves
        fn _mint_reserves(ref self: ContractState, cash: u128, borrows: u128, interest: u128) -> u128 {
            /// Get the reserves (interest accrued * reserve factor)
            let new_reserves = interest.mul_wad(self.reserve_factor.read());

            /// Since we mint CygUSD shares for reserves we use the same calculation as
            /// `convert_to_shares` but use the cash and borrows from the borrow_indices for gas savings
            if (new_reserves > 0) {
                let supply = self.total_supply.read();
                let cyg_usd_amount = new_reserves.full_mul_div(supply, (cash + borrows - new_reserves));
                let dao_reserves = self.hangar18.read().dao_reserves();
                self._mint(dao_reserves, cyg_usd_amount);
            }

            new_reserves
        }

        /// Accrues interest to total borrows and as a result increases `total_borrows`,
        /// `borrow_index` and `last_accrual_timestamp`
        fn _accrue(ref self: ContractState) {
            /// Accrue interest internally
            let (cash, borrows, index, time_elapsed, interest) = self._borrow_indices();

            /// If the timestamp is last accrual then escape
            if (time_elapsed == 0) {
                return;
            }

            // Check for reserves and mint if necessary before updating total_borrows
            let new_reserves = self._mint_reserves(cash, borrows, interest);

            /// Update storage
            self.total_borrows.write(borrows);
            self.borrow_index.write(index);
            self.last_accrual_timestamp.write(get_block_timestamp());

            /// # Emit
            /// * `AccrueInterest`
            self.emit(AccrueInterest { cash, borrows, interest, new_reserves });
        }

        /// Gets the latest borrow indices to calculate the up to date total borrows and borrow index
        ///
        /// # Returns
        /// * The current available cash (ie `total_balance`)
        /// * The latest total pool borrows (with interest accrued)
        /// * The latest borrow index
        /// * The time elapsed since last accrual
        /// * The interest accumulated since last accrual
        fn _borrow_indices(self: @ContractState) -> (u128, u128, u128, u64, u128) {
            /// 1. Get available cash, total borrows and current borrow index stored
            let cash = self.total_balance.read();
            let mut total_borrows = self.total_borrows.read();
            let mut borrow_index = self.borrow_index.read();

            /// 2. Get timestamp and check time elapsed since last interest accrual
            let time_elapsed = get_block_timestamp() - self.last_accrual_timestamp.read();

            if time_elapsed == 0 {
                return (cash, total_borrows, borrow_index, 0, 0);
            }

            /// 3. Calculate the latest borrow rate and calculate interest accumulated
            let borrow_rate = self._borrow_rate(cash, total_borrows);
            let interest_factor = borrow_rate * time_elapsed.into();
            let interest_accumulated = interest_factor.mul_wad(total_borrows);

            /// 4. Calculate latest total borrows and borrow index in this pool
            total_borrows += interest_accumulated;
            borrow_index += interest_factor.mul_wad(borrow_index);

            (cash, total_borrows, borrow_index, time_elapsed, interest_accumulated)
        }

        /// Gets the borrow balance of a user from the snapshot
        ///
        /// # Arguments
        /// * `borrower` - The address of the borrower
        /// * `accrue` - Whether we should simulate accrual or not (gas savings)
        ///
        /// # Returns
        /// * The borrower's principal (actual borrowed amount)
        /// * The borrowed amount with interest
        fn _borrow_balance(self: @ContractState, borrower: ContractAddress, accrue: bool) -> (u128, u128) {
            // Load borrower snapshot
            let snapshot: BorrowSnapshot = self.borrow_balances.read(borrower);

            // If user interest index is 0 then borrows is 0
            if snapshot.interest_index == 0 {
                return (0, 0);
            }

            /// Get latest index
            let mut index = self.borrow_index.read();

            /// If accrue then get indices
            if accrue {
                /// Simulate accrual and get latest borrow index
                let (_, _, new_index, _, _) = self._borrow_indices();

                index = new_index;
            }

            // The borrow balance (ie what the borrower owes with interest) is:
            // (borrower.principal * borrow_index) / borrower.interest_index
            let borrow_balance = snapshot.principal.full_mul_div(index, snapshot.interest_index);

            (snapshot.principal, borrow_balance)
        }

        /// Internal function to calculate the latest borrow rate per second
        ///
        /// # Arguments
        /// Caclulate borrow rate internally
        fn _borrow_rate(self: @ContractState, cash: u128, borrows: u128) -> u128 {
            // Real model stored vars
            let model: InterestRateModel = self.interest_rate_model.read();

            // If borrows is 0, util is 0, return base rate per second
            if (borrows == 0) {
                return model.base_rate_per_second.into();
            }

            // Else return slope
            let util = borrows.div_wad(cash + borrows);

            // Under kink
            if (util <= model.kink.into()) {
                let slope = util.mul_wad(model.multiplier_per_second.into());
                let base_rate = model.base_rate_per_second;
                return slope + base_rate.into();
            }

            // Over kink
            let max_slope = model.kink.into().mul_wad(model.multiplier_per_second.into());
            let base_rate = model.base_rate_per_second;
            let normal_rate = max_slope + base_rate.into();
            let excess_util = util - model.kink.into();

            // normal_rate + excess_util * jump_multiplier
            excess_util.mul_wad(model.jump_multiplier_per_second.into()) + normal_rate
        }

        /// Updates the borrow snapshot after any borrow, repay or liquidation
        ///
        /// # Arguments
        /// * `borrower` - The address of the borrower
        /// * `borrow_amount` - The borrowed amount (can be 0)
        /// * `repay_amount` - The repaid amount (can be 0)
        ///
        /// # Returns
        /// * The total account borrows after the update
        fn _update_borrow(
            ref self: ContractState, borrower: ContractAddress, borrow_amount: u128, repay_amount: u128
        ) -> u128 {
            // Load snapshot - We have already accrued since this function is only called
            // after `borrow()` or `liquidate()` which accrue beforehand
            let (_, borrow_balance) = self._borrow_balance(borrower, accrue: false);

            // In case of flash loan or 0 return current borrow_balance
            if (borrow_amount == repay_amount) {
                return borrow_balance;
            }

            // Read borrow index to adjust
            let borrow_index = self.borrow_index.read();

            // Get snapshot for borrower
            let mut snapshot: BorrowSnapshot = self.borrow_balances.read(borrower);

            /// The return var. Keeps track of the user's account current borrows and pass
            /// it to the rewarder to track rewards
            let mut account_borrows = 0;

            // Borrow transaction
            if (borrow_amount > repay_amount) {
                /// Increase borrower's borrow balance by new borrow amount
                let increase_borrow_amount = borrow_amount - repay_amount;
                account_borrows = borrow_balance + increase_borrow_amount;

                /// Update snapshot
                snapshot.principal = account_borrows;
                snapshot.interest_index = borrow_index;
                self.borrow_balances.write(borrower, snapshot);

                /// Increase total pool borrows
                let total_borrows = self.total_borrows.read() + increase_borrow_amount;
                self.total_borrows.write(total_borrows);

                /// Update position
                self._update_position(borrower)
            } else {
                /// Decrease borrower's borrow balance by repaid amount
                let decrease_borrow_amount = repay_amount - borrow_amount;
                account_borrows =
                    if borrow_balance > decrease_borrow_amount {
                        borrow_balance - decrease_borrow_amount
                    } else {
                        0
                    };

                /// Update snapshot
                snapshot.principal = account_borrows;
                snapshot.interest_index = if account_borrows == 0 {
                    0
                } else {
                    borrow_index
                };
                self.borrow_balances.write(borrower, snapshot);

                /// Decrease total pool borrows
                let actual_decrease_amount = borrow_balance - account_borrows;
                let mut total_borrows = self.total_borrows.read();
                total_borrows =
                    if total_borrows > actual_decrease_amount {
                        total_borrows - actual_decrease_amount
                    } else {
                        0
                    };

                self.total_borrows.write(total_borrows);
            }

            /// Track rewards
            self._track_rewards(borrower, account_borrows, self.twin_star.read().contract_address);

            /// Return the total account borrows after update
            account_borrows
        }

        /// Tracks CYG rewards internally for borrowers and lenders
        ///
        /// # Arguments
        /// * `account` - Address of the borrower or lender
        /// * `balance` - Balance of CygUSD for lenders, the USDC borrow balance for borrowers
        /// * `collateral` - The address of the collateral. For lenders, this is always the zero address
        fn _track_rewards(
            ref self: ContractState, account: ContractAddress, balance: u128, collateral: ContractAddress
        ) {
            /// Get current pillars
            let pillars = self.pillars_of_creation.read();

            /// If it is not set then escape
            if pillars.contract_address.is_zero() {
                return;
            }

            /// Pass lender or borrower info to the rewarder
            pillars.track_rewards(account, balance, collateral);
        }

        /// Updates the total borrowers stored positions
        ///
        /// # Arguments
        /// * `borrower` - The address of the borrower
        fn _update_position(ref self: ContractState, borrower: ContractAddress) {
            /// Check mapping to see if borrower has already been added
            let is_borrower = self.is_borrower.read(borrower);

            /// If not added then add and update `is_borrower`, all positions and total positions length
            if (!is_borrower) {
                /// Get the current position ID
                let position_id = self.all_positions_length.read();

                /// Borrower address cant be added again
                self.is_borrower.write(borrower, true);

                /// Update all positions mapping
                self.all_positions.write(position_id, borrower);

                /// Increase position ID
                self.all_positions_length.write(position_id + 1);
            }
        }
    }

    ///----------------------------------------------------------------------------------------------------
    ///                                          LOGIC - STRATEGY
    ///----------------------------------------------------------------------------------------------------

    /// CygnusBorrowableVoid
    ///
    /// Internal logic that handles the strategy for the underlying
    #[generate_trait]
    impl VoidImpl of VoidTrait {
        /// Preview our total balance deposited in the strategy.
        /// This is a helper function that is used only when syncing our balance with the `_update` function.
        #[inline(always)]
        fn _preview_total_balance(self: @ContractState) -> u128 {
            /// zkUSDC rebases on each interest accrual, so our underlying balance is our zkUSDC balance
            self.zk_lend_usdc.read().balanceOf(get_contract_address()).try_into().unwrap()
        }

        /// Hook that handles underlying deposits into the strategy
        ///
        /// # Arguments
        /// * `amount` - The amount of underlying stablecoin to deposit into the strategy
        #[inline(always)]
        fn _after_deposit(ref self: ContractState, amount: u128) {
            /// Get the zkLend market from storage
            let zk_lend_market = self.zk_lend_market.read();

            /// Deposit `amount` of stablecoin into market
            zk_lend_market.deposit(self.underlying.read().contract_address, amount.into());
        }


        /// Hook that handles underlying withdrawals from the strategy
        ///
        /// # Arguments
        /// * `amount` - The amount of underlying stablecoin to withdraw from the zkLend market
        #[inline(always)]
        fn _before_withdraw(ref self: ContractState, amount: u128) {
            /// Get the zkLend market from storage
            let market = self.zk_lend_market.read();

            /// Withdraw `amount` of stablecoin from zklend market
            market.withdraw(self.underlying.read().contract_address, amount.into());
        }
    }

    /// Utils
    #[generate_trait]
    impl UtilsImpl of UtilsTrait {
        /// It locks and accrues interest. After accrual we update the total_balance var to sync 
        /// our underlying balance with the strategy
        #[inline(always)]
        fn _lock_accrue_update(ref self: ContractState) {
            /// # Error
            /// * `REENTRANT_CALL` - Reverts if already entered
            assert(!self.guard.read(), Errors::REENTRANT_CALL);

            /// Lock
            self.guard.write(true);

            /// Accrue interest
            self._accrue();

            /// Update total balance in terms of underlying
            self._update();
        }

        /// Unlock and update our total_balance var after any payable action
        #[inline(always)]
        fn _update_unlock(ref self: ContractState) {
            /// Update after action
            self._update();

            /// Unlock
            self.guard.write(false);
        }

        /// Get the balance of USDC currently in this contract
        /// The vault should never have USDC unless when repaying and depositing,
        /// and it then gets deposited in the strategy
        fn _check_balance(self: @ContractState, token: IERC20Dispatcher) -> u128 {
            token.balanceOf(get_contract_address()).try_into().unwrap()
        }
    }
}
