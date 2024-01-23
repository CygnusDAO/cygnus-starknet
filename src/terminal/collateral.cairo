//  SPDX-License-Identifier: AGPL-3.0-or-later
//
//  collateral.cairo
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
//       COLLATERAL (CygLP) - https://cygnusdao.finance                                                          .                     .
//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════
//
//  Smart contract to go long on your liquidity.
//
//  Deposit Liquidity, borrow USD.
//
//  This is a Cairo implementation of the audited Cygnus Core contracts written originally in Solidity 0.8.9:
//  https://github.com/CygnusDAO/core
//
//  Both borrowable and collateral (this) contracts follow the exact same architecture:
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
/// * `CygnusCollateral`
///
/// # Description
/// * Smart contract for liquidity providers to deposit their liquidity and use it as collateral to borrow stbalecoins
///
/// # Author
/// * CygnusDAO
use starknet::ContractAddress;
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::data::calldata::{DeleverageCalldata};

/// # Interface
/// * `ICollateral`
#[starknet::interface]
trait ICollateral<T> {
    ///--------------------------------------------------------------------------------------------------------
    ///                                          1. ERC20
    ///--------------------------------------------------------------------------------------------------------

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

    ///--------------------------------------------------------------------------------------------------------
    ///                                          2. TERMINAL
    ///--------------------------------------------------------------------------------------------------------

    /// The factory which deploys pools and has all the important addresses on Starknet
    ///
    /// # Returns
    /// * The address of the factory contract
    fn hangar18(self: @T) -> ContractAddress;

    /// The underlying LP Token for this pool
    ///
    /// # Returns
    /// * The address of the underlying LP
    fn underlying(self: @T) -> ContractAddress;

    /// Each collateral only has 1 borrowable which may borrow funds from
    ///
    /// # Returns
    /// * The address of the borrowable contract
    fn borrowable(self: @T) -> ContractAddress;

    /// The oracle for the underlying LP
    ///
    /// # Returns
    /// * The address of the oracle that prices the LP token
    fn nebula(self: @T) -> ContractAddress;

    /// Unique lending pool ID, shared by the borrowable arm
    ///
    /// # Returns
    /// * The lending pool ID
    fn shuttle_id(self: @T) -> u32;

    /// # Returns the total balance of the underlying deposited in the strategy
    fn total_balance(self: @T) -> u128;

    /// Returns the total LP assets held by the vault (ie. total_balance)
    fn total_assets(self: @T) -> u128;

    /// Returns the exchange rate between 1 unit of CygLP shares to assets. IE. How much LP
    /// can be redeemed by redeeming 1 unit of CygLP shares. It should never be below 1e18.
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

    ///--------------------------------------------------------------------------------------------------------
    ///                                          3. CONTROL
    ///--------------------------------------------------------------------------------------------------------

    /// # Returns the minimum debt ratio allowed
    fn DEBT_RATIO_MIN(self: @T) -> u128;

    /// # Returns the maximum debt ratio allowed
    fn DEBT_RATIO_MAX(self: @T) -> u128;

    /// # Returns the maximum liquidation incentive allowed
    fn LIQUIDATION_INCENTIVE_MAX(self: @T) -> u128;

    /// # Returns the minimum liquidation incentive allowed
    fn LIQUIDATION_INCENTIVE_MIN(self: @T) -> u128;

    /// # Returns the maximum liquidation fee allowed
    fn LIQUIDATION_FEE_MAX(self: @T) -> u128;

    /// # Returns the current pool's debt ratio
    fn debt_ratio(self: @T) -> u128;

    /// # Returns the current pool's liquidation fee
    fn liquidation_fee(self: @T) -> u128;

    /// # Returns the current pool's liquidation incentive
    fn liquidation_incentive(self: @T) -> u128;

    /// Sets the borrowable during deployment. Can only be set once (does address zero check).
    ///
    /// # Security
    /// * Can only be set once, reverts if borrowable address is not zero!
    ///
    /// # Arguments
    /// * `borrowable` - The address of the borrowable
    fn set_borrowable(ref self: T, borrowable: IBorrowableDispatcher);

    /// Sets liquidation fee 
    ///
    /// # Security 
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `new_liq_fee` - The new liquidation fee
    fn set_liquidation_fee(ref self: T, new_liq_fee: u128);

    /// Sets liquidation incentive
    ///
    /// # Security 
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `incentive` - The new liquidation incentive
    fn set_liquidation_incentive(ref self: T, new_incentive: u128);

    /// Sets a new debt ratio
    ///
    /// # Security
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `new_ratio` - The new debt ratio
    fn set_debt_ratio(ref self: T, new_ratio: u128);

    ///--------------------------------------------------------------------------------------------------------
    ///                                          4. MODEL
    ///--------------------------------------------------------------------------------------------------------

    /// Checks whether a borrower can borrow a certain amount, used by the borrowable contract
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// * `amount` - The amount to borrow
    ///
    /// # Returns 
    /// * Whether or not `borrower` can borrow `amount`
    fn can_borrow(self: @T, borrower: ContractAddress, amount: u128) -> bool;

    /// Checks whether or not a borrower can redeem a certain amount of CygLP
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// * `amount` - The amount of CygLP to redeem
    ///
    /// # Returns
    /// * Whether or not the borrower can withdraw 'amount' of CygLP. If false then it means withdrawing
    ///   this amount of CygLP would put user in shortfall and withdrawing this would cause the tx to revert
    fn can_redeem(self: @T, borrower: ContractAddress, amount: u128) -> bool;

    /// Checks a borrower's current liquidity and shortfall. 
    /// 
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// 
    /// # Returns
    /// * The maximum amount of USDC that the `borrower` can borrow (if shortfall then this == 0)
    /// * The current shortfall of USDC (if liquidity then this == 0)
    fn get_account_liquidity(self: @T, borrower: ContractAddress) -> (u128, u128);

    /// # Returns
    /// * The price of the underlying LP Token, denominated in the borrowable`s underlying
    fn get_lp_token_price(self: @T) -> u128;

    /// Quick check to see borrower`s position
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    ///
    /// # Returns
    /// * The borrower's position in LPs
    /// * The borrower's position in USD
    /// * The borrower's health (0.5e18 = 50%, liquidatable at 100% ie 1e18)
    fn get_borrower_position(self: @T, borrower: ContractAddress) -> (u128, u128, u128);

    ///--------------------------------------------------------------------------------------------------------
    ///                                          5. COLLATERAL
    ///--------------------------------------------------------------------------------------------------------

    /// Seizes an amount of CygLP from the borrower and transfers it to the liquidator.
    /// Not marked as non-reentrant as only borrowable can call through the non-reentrant `liquidate`
    ///
    /// # Security
    /// * Non-reentrant
    /// * Only-borrowable
    ///
    /// # Arguments
    /// * `liquidator` - The address of the liquidator
    /// * `borrower` - The address of the borrower
    /// * `repay_amount` - The amount of USDC repaid by the liquidator
    ///
    /// # Returns
    /// * The amount of CygLP seized
    fn seize_cyg_lp(ref self: T, liquidator: ContractAddress, borrower: ContractAddress, repay_amount: u128) -> u128;

    /// Flash redeems LP from the vault and sends it to `redeemer`, expecting an equivalent amount of CygLP to be received
    /// by the end of the function.
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `redeemer` - The recipient of the LP tokens
    /// * `redeem_amount,` - The amount of LP to flash redeem
    /// * `calldata` - Calldata passed to the router
    ///
    /// # Returns
    /// * The amount of USDC received (if any)
    fn flash_redeem(ref self: T, redeemer: ContractAddress, redeem_amount: u128, calldata: DeleverageCalldata) -> u128;
}

/// # Module
/// * `Collateral`
#[starknet::contract]
mod Collateral {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::ICollateral;
    use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};

    /// # Imports
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use cygnus::libraries::full_math_lib::FullMathLib::FixedPointMathLibTrait;

    /// # Errors
    use cygnus::terminal::errors::{CollateralErrors as Errors};

    /// # Data
    use cygnus::data::calldata::{DeleverageCalldata};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Events
    /// * `Transfer` - Logs when CygLP is transferred
    /// * `Approval` - Logs when user approves a spender to spend their CygLP
    /// * `SyncBalance` - Logs when `total_balance` is synced with underlying's balance_of
    /// * `Deposit` - Logs when a user deposits LP and receives CygLP
    /// * `Withdraw` - Logs when a user redeems CygLP and receives LP
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        SyncBalance: SyncBalance,
        Deposit: Deposit,
        Withdraw: Withdraw,
        NewDebtRatio: NewDebtRatio,
        NewLiquidationIncentive: NewLiquidationIncentive,
        NewLiquidationFee: NewLiquidationFee,
        Seize: Seize
    }

    /// Transfer
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u128
    }

    /// Approval
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u128
    }

    // SyncBalance
    #[derive(Drop, starknet::Event)]
    struct SyncBalance {
        balance: u128
    }

    /// Deposit
    #[derive(Drop, starknet::Event)]
    struct Deposit {
        caller: ContractAddress,
        recipient: ContractAddress,
        assets: u128,
        shares: u128
    }

    /// Withdraw
    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        caller: ContractAddress,
        recipient: ContractAddress,
        owner: ContractAddress,
        assets: u128,
        shares: u128
    }


    /// NewLiquidationFee
    #[derive(Drop, starknet::Event)]
    struct NewLiquidationFee {
        old_liq_fee: u128,
        new_liq_fee: u128
    }

    /// NewLiqIncentive
    #[derive(Drop, starknet::Event)]
    struct NewLiquidationIncentive {
        old_incentive: u128,
        new_incentive: u128
    }


    /// NewDebtRatio
    #[derive(Drop, starknet::Event)]
    struct NewDebtRatio {
        old_ratio: u128,
        new_ratio: u128
    }

    /// Seize
    #[derive(Drop, starknet::Event)]
    struct Seize {
        liquidator: ContractAddress,
        borrower: ContractAddress,
        cyg_lp_amount: u128
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Non-reentrant guard
        guard: bool,
        /// Name of the collateral token (Cygnus: Collateral)
        name: felt252,
        /// Symbol of the collateral token (CygLP)
        symbol: felt252,
        /// Decimals of the collateral token, same as underlying
        decimals: u8,
        /// Total supply of CygLP
        total_supply: u128,
        /// Mapping of user => CygLP balance
        balances: LegacyMap<ContractAddress, u128>,
        /// Mapping of (owner, spender) => allowance
        allowances: LegacyMap<(ContractAddress, ContractAddress), u128>,
        /// Opposite arm (ie. borrowable)
        twin_star: IBorrowableDispatcher,
        /// The address of the factory
        hangar18: IHangar18Dispatcher,
        /// The address of the underlying asset (ie an LP Token)
        underlying: IERC20Dispatcher,
        /// The address of the oracle for this lending pool
        nebula: ICygnusNebulaDispatcher,
        /// The lending pool ID (shared by the borrowable)
        shuttle_id: u32,
        /// Total balance of the underlying deposited in the strategy (ie. total cash)
        total_balance: u128,
        /// The current debt ratio for this pool
        debt_ratio: u128,
        /// The current liquidation incentive
        liq_incentive: u128,
        /// The current liquidation fee
        liq_fee: u128,
    }

    /// The lowest possible liquidation profit, which liquidators receive (0%)
    const LIQ_INCENTIVE_MIN: u128 = 1_000000000_000000000;
    /// The highest possible liquidation profit, which liquidators receive (20%)
    const LIQ_INCENTIVE_MAX: u128 = 1_200000000_000000000;
    /// The max possible liquidation fee, which the protocol seizes from the borrower (10%)
    const LIQ_FEE_MAX: u128 = 100000000_000000000;
    /// The minimum possible debt ratio (LTV) for this lending pool (70%)
    const DEBT_RATIO_MIN: u128 = 700000000_000000000;
    /// The maximum possible debt ratio (LTV) for this lending pool (95%)
    const DEBT_RATIO_MAX: u128 = 950000000_000000000;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(
        ref self: ContractState,
        hangar18: IHangar18Dispatcher,
        underlying: IERC20Dispatcher,
        borrowable: IBorrowableDispatcher,
        oracle: ICygnusNebulaDispatcher,
        shuttle_id: u32
    ) {
        self._initialize(hangar18, underlying, borrowable, oracle, shuttle_id);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl CygnusCollateral of ICollateral<ContractState> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                          1. ERC20
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICollateral
        fn name(self: @ContractState) -> felt252 {
            'Cygnus: Collateral'
        }

        /// # Implementation
        /// * ICollateral
        fn symbol(self: @ContractState) -> felt252 {
            'CygLP'
        }

        /// # Implementation
        /// * ICollateral
        fn decimals(self: @ContractState) -> u8 {
            /// Always use decimals of the underlying (Most LPs are 18)
            self.underlying.read().decimals()
        }

        /// # Implementation
        /// * ICollateral
        fn total_supply(self: @ContractState) -> u128 {
            self.total_supply.read()
        }

        /// # Implementation
        /// * ICollateral
        fn totalSupply(self: @ContractState) -> u128 {
            self.total_supply.read()
        }

        /// # Implementation
        /// * ICollateral
        fn balance_of(self: @ContractState, account: ContractAddress) -> u128 {
            self.balances.read(account)
        }

        /// # Implementation
        /// * ICollateral
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u128 {
            self.balances.read(account)
        }


        /// # Implementation
        /// * ICollateral
        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u128 {
            self.allowances.read((owner, spender))
        }

        /// # Implementation
        /// * ICollateral
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }

        /// # Implementation
        /// * ICollateral
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u128) -> bool {
            /// Get caller address
            let caller = get_caller_address();

            /// Before transfer hook - Before any transfer, we check that the user can transfer collateral
            /// if it would not put their position in shortfall. Used here instead of the internal `_transfer`
            /// as we use it the internal to escape in liquidations
            self._before_token_transfer(caller, recipient, amount);

            /// Transfer CygLP to recipient
            self._transfer(caller, recipient, amount);
            true
        }

        /// # Implementation
        /// * ICollateral
        fn transfer_from(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u128
        ) -> bool {
            /// Before transfer hook - Same as above
            self._before_token_transfer(sender, recipient, amount);

            /// Check allowance and transfer
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * ICollateral
        fn transferFrom(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u128
        ) -> bool {
            /// Before transfer hook - Same as above
            self._before_token_transfer(sender, recipient, amount);

            /// Check allowance and transfer
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * ICollateral
        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u128) -> bool {
            self._increase_allowance(spender, added_value)
        }

        /// # Implementation
        /// * ICollateral
        fn increaseAllowance(ref self: ContractState, spender: ContractAddress, added_value: u128) -> bool {
            self._increase_allowance(spender, added_value)
        }

        /// # Implementation
        /// * ICollateral
        fn decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u128) -> bool {
            self._decrease_allowance(spender, subtracted_value)
        }

        /// # Implementation
        /// * ICollateral
        fn decreaseAllowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u128) -> bool {
            self._decrease_allowance(spender, subtracted_value)
        }


        /// ---------------------------------------------------------------------------------------------------
        ///                                          2. TERMINAL
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICollateral
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn underlying(self: @ContractState) -> ContractAddress {
            self.underlying.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn borrowable(self: @ContractState) -> ContractAddress {
            self.twin_star.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn nebula(self: @ContractState) -> ContractAddress {
            self.nebula.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn shuttle_id(self: @ContractState) -> u32 {
            self.shuttle_id.read()
        }

        /// # Implementation
        /// * ICollateral
        fn total_balance(self: @ContractState) -> u128 {
            self.total_balance.read()
        }

        /// Kept here for consistency with borrowable, for collateral total assets is just total balance of LPs
        ///
        /// # Implementation
        /// * ICollateral
        fn total_assets(self: @ContractState) -> u128 {
            self.total_balance.read()
        }

        /// # Implementation
        /// * ICollateral
        fn exchange_rate(self: @ContractState) -> u128 {
            /// Get supply of CygLP
            let supply = self.total_supply.read();

            // If no supply return shares 
            if supply == 0 {
                return 1_000_000_000_000_000_000;
            }

            /// Return the exhcange rate between 1 CygLP and LP assets (ie. how much LP can be redeemed
            /// for 1 unit of CygLP)
            return self.total_assets().div_wad(supply);
        }

        /// Transfers LP from caller and mints them shares.
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn deposit(ref self: ContractState, assets: u128, recipient: ContractAddress) -> u128 {
            /// Lock
            self._lock();

            /// Convert underlying assets to CygLP shares
            let mut shares = self._convert_to_shares(assets);

            /// # Error
            /// * `CANT_MINT_ZERO` - Reverts if minting 0 shares
            assert(shares > 0, Errors::CANT_MINT_ZERO);

            /// Get caller address and contract address
            let caller = get_caller_address();
            let receiver = get_contract_address();

            // Transfer LPs to vault
            self.underlying.read().transferFrom(caller, receiver, assets.into());

            // Burn 1000 shares to address zero, this is only for the first depositor
            if (self.total_supply.read() == 0) {
                shares -= 1000;
                self._mint(Zeroable::zero(), 1000);
            }

            /// Mint CygLP
            self._mint(recipient, shares);

            /// Deposit USDC in strategy
            self._after_deposit(assets);

            /// # Event
            /// * Deposit
            self.emit(Deposit { caller, recipient, assets, shares });

            /// Unlock and update
            self._update_and_unlock();

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
            self._lock();

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
            self._update_and_unlock();

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
            /// Lock
            self._lock();

            // Update, unlock
            self._update_and_unlock();
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                          3. CONTROL
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICollateral
        fn LIQUIDATION_INCENTIVE_MIN(self: @ContractState) -> u128 {
            LIQ_INCENTIVE_MIN
        }

        /// # Implementation
        /// * ICollateral
        fn LIQUIDATION_INCENTIVE_MAX(self: @ContractState) -> u128 {
            LIQ_INCENTIVE_MAX
        }

        /// # Implementation
        /// * ICollateral
        fn DEBT_RATIO_MIN(self: @ContractState) -> u128 {
            DEBT_RATIO_MIN
        }

        /// # Implementation
        /// * ICollateral
        fn DEBT_RATIO_MAX(self: @ContractState) -> u128 {
            DEBT_RATIO_MAX
        }

        /// # Implementation
        /// * ICollateral
        fn LIQUIDATION_FEE_MAX(self: @ContractState) -> u128 {
            LIQ_FEE_MAX
        }

        /// # Implementation
        /// * ICollateral
        fn debt_ratio(self: @ContractState) -> u128 {
            self.debt_ratio.read()
        }

        /// # Implementation
        /// * ICollateral
        fn liquidation_incentive(self: @ContractState) -> u128 {
            self.liq_incentive.read()
        }

        /// # Implementation
        /// * ICollateral
        fn liquidation_fee(self: @ContractState) -> u128 {
            self.liq_fee.read()
        }

        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * ICollateral
        fn set_liquidation_fee(ref self: ContractState, new_liq_fee: u128) {
            // Check caller is admin
            self._check_admin();

            /// # Error
            /// * `Invalid Range`
            assert(new_liq_fee >= 0 && new_liq_fee <= LIQ_FEE_MAX, Errors::INVALID_RANGE);

            // Old fee
            let old_liq_fee = self.liq_fee.read();

            // Assign new fee
            self.liq_fee.write(new_liq_fee);

            /// # Emit
            /// * `NewLiquidationFee`
            self.emit(NewLiquidationFee { old_liq_fee, new_liq_fee });
        }

        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * ICollateral
        fn set_liquidation_incentive(ref self: ContractState, new_incentive: u128) {
            // Check caller is admin
            self._check_admin();

            /// # Error
            /// * `Invalid Range`
            assert(new_incentive >= LIQ_INCENTIVE_MIN && new_incentive <= LIQ_INCENTIVE_MAX, Errors::INVALID_RANGE);

            // Old incentive
            let old_incentive = self.liq_incentive.read();

            // Assign new incentive
            self.liq_incentive.write(new_incentive);

            /// # Emit
            /// * `NewLiquidationIncentive`
            self.emit(NewLiquidationIncentive { old_incentive, new_incentive });
        }

        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * ICollateral
        fn set_debt_ratio(ref self: ContractState, new_ratio: u128) {
            // Check caller is admin
            self._check_admin();

            /// # Error
            /// * `Invalid Range`
            assert(new_ratio >= DEBT_RATIO_MIN && new_ratio <= DEBT_RATIO_MAX, Errors::INVALID_RANGE);

            // Old debt ratio
            let old_ratio = self.debt_ratio.read();

            // Assign new debt ratio
            self.debt_ratio.write(new_ratio);

            /// # Emit
            /// * `NewDebtRatio`
            self.emit(NewDebtRatio { old_ratio, new_ratio });
        }


        /// # Security
        /// * Checks that borrowable is the zero address before setting. Can only be set once!
        ///
        /// # Implementation
        /// * ICollateral
        fn set_borrowable(ref self: ContractState, borrowable: IBorrowableDispatcher) {
            /// # Error
            /// * `BORROWABLE_ALREADY_SET` - Reverts if borrowable is not zero
            assert(self.twin_star.read().contract_address.is_zero(), Errors::BORROWABLE_ALREADY_SET);

            /// Write borrowable to storage, cannot be set again
            self.twin_star.write(borrowable);
        }

        ///----------------------------------------------------------------------------------------------------
        ///                                          4. MODEL
        ///----------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICollateral
        fn can_borrow(self: @ContractState, borrower: ContractAddress, amount: u128) -> bool {
            // Get shortfall
            let (_, shortfall) = self._account_liquidity(borrower, amount);

            // Returns true if borroing `borrowed_amount` would not put user in shortfall
            shortfall == 0
        }

        /// # Implementation
        /// * ICollateral
        fn get_account_liquidity(self: @ContractState, borrower: ContractAddress) -> (u128, u128) {
            /// Get the user's liquidity or shortfall
            self._account_liquidity(borrower, integer::BoundedInt::max())
        }

        /// # Implementation
        /// * ICollateral
        fn get_lp_token_price(self: @ContractState) -> u128 {
            /// LP address
            let lp_token_address = self.underlying.read().contract_address;

            // Get LP Price
            let price = self.nebula.read().lp_token_price(lp_token_address);

            /// # Error
            /// * `INVALID_PRICE` - Reverts if price is 0
            assert(price >= 0, Errors::INVALID_PRICE);

            price
        }

        /// # Implementation
        /// * ICollateral
        fn can_redeem(self: @ContractState, borrower: ContractAddress, amount: u128) -> bool {
            /// Get the CygLP balance of the borrower
            let balance = self.balances.read(borrower);

            if (amount > balance || amount == 0) {
                return false;
            }

            // Get the amount of LPs the borrower currently would have access to from the vault after withdrawing `amount` 
            let lp_amount = self._convert_to_assets(balance - amount);

            // Get borrower`s latest borrow balance (with interests)
            let (_, borrow_balance) = self.twin_star.read().get_borrow_balance(borrower);

            // Given the current borrow balance and the lp amount, get the collateral needed
            let (_, shortfall) = self._collateral_needed(lp_amount, borrow_balance);

            // Ensure shortfall is 0
            shortfall == 0
        }

        /// # Implementation
        /// * ICollateral
        fn get_borrower_position(self: @ContractState, borrower: ContractAddress) -> (u128, u128, u128) {
            /// 1. The borrower's position in LP tokens (ie CygLP Balance * Exchange Rate)
            let position_lp = self.balances.read(borrower).mul_wad(self.exchange_rate());

            /// 2. The borrower's position in USD (ie. Position LP * LP Price)
            let position_usd = position_lp.mul_wad(self.get_lp_token_price()); // LP Balance * Price

            /// Avoid divide by 0
            if position_usd == 0 {
                return (0, 0, 0);
            }

            /// Calculate the user's adjusted position with this pool's debt ratio and liquidation penalties.
            /// adjusted_position = (position_usd * debt_ratio) / (liquidation penalty + liquidation fee)
            let debt_ratio = self.debt_ratio.read();
            let liq_penalty = self.liq_incentive.read() + self.liq_fee.read();
            let adjusted_position = position_usd.full_mul_div(debt_ratio, liq_penalty);

            /// 3. The borrower's health, liquidatable at 100% (ie. borrow_balance / adjusted_position)
            let (_, borrow_balance) = self.twin_star.read().get_borrow_balance(borrower);
            let health = borrow_balance.div_wad(adjusted_position);

            (position_lp, position_usd, health)
        }

        ///----------------------------------------------------------------------------------------------------
        ///                                          5. COLLATERAL
        ///----------------------------------------------------------------------------------------------------

        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * ICollateral
        fn seize_cyg_lp(
            ref self: ContractState, liquidator: ContractAddress, borrower: ContractAddress, repay_amount: u128
        ) -> u128 {
            /// Lock
            self._lock();

            /// Get sender
            let caller = get_caller_address();

            /// # Error
            /// * `SENDER_NOT_BORROWABLE` - Revert if not called by the borrowable contract
            assert(caller == self.twin_star.read().contract_address, Errors::SENDER_NOT_BORROWABLE);

            /// # Error
            /// * `CANT_SEIZE_ZERO` - Revert if repay amount is 0
            assert(repay_amount > 0, Errors::CANT_SEIZE_ZERO);

            /// Assert user is liquidatable
            let (_, shortfall) = self._account_liquidity(borrower, integer::BoundedInt::max());

            /// # Error
            /// * `NOT_LIQUIDATABLE` - Revert if position is not in shortfall
            assert(shortfall > 0, Errors::NOT_LIQUIDATABLE);

            /// Liquidator receives the equivalent of the USDC repaid + liq. incentive in LP Tokens::
            /// (repaid amount * liquidation incentive) / LP token price
            let lp_token_price = self.get_lp_token_price();
            let lp_equivalent = repay_amount.div_wad(lp_token_price);
            /// Convert seized LPs to CygLP to seize shares with liq. incentive (for the liquidator)
            let cyg_lp_amount = self._convert_to_shares(lp_equivalent);

            /// The amount for the liquidator
            let liquidator_amount = cyg_lp_amount.mul_wad(self.liq_incentive.read());

            /// Transfer CygLP to the liquidator
            /// Escapes `can_redeem`
            self._transfer(borrower, liquidator, liquidator_amount);

            // Check for DAO fee (seized from the borrower, not the liquidator)
            let liq_fee = self.liq_fee.read();

            if liq_fee > 0 {
                // Get the liquidation fee from the total seized
                let dao_fee = cyg_lp_amount.mul_wad(liq_fee);

                /// Liquidation fees are transfered to dao reserves
                let dao_reserves = self.hangar18.read().dao_reserves();

                /// Seize CygLP from borrower to dao reserves - daoReserves is never zero
                /// Escapes `can_redeem`
                self._transfer(borrower, dao_reserves, dao_fee);
            }

            /// Emit
            self.emit(Seize { liquidator, borrower, cyg_lp_amount });

            /// Unlock
            self._update_and_unlock();

            /// Return amount seized
            cyg_lp_amount
        }

        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * ICollateral
        fn flash_redeem(
            ref self: ContractState, redeemer: ContractAddress, redeem_amount: u128, calldata: DeleverageCalldata
        ) -> u128 {
            /// Lock
            self._lock();

            /// # Error
            /// * `CANT_REDEEM_ZERO` - Avoid redeeming 0 LP
            assert(redeem_amount > 0, Errors::CANT_REDEEM_ZERO);

            /// The equivalent of the LP redeemed in CygLP shares, rounding up
            let shares = redeem_amount.full_mul_div_up(self.total_supply.read(), self.total_balance.read());

            /// Get sender
            let caller = get_caller_address();

            /// before withdraw hook (if any strategy is set)
            self._before_withdraw(redeem_amount);

            /// Optimistically transfer LP amount to `redeemer`
            self.underlying.read().transfer(redeemer, redeem_amount.into());

            /// Helper return val to simulate transaction or make static call to check the amount of USDC
            /// received, has no meaning in the function itself.
            let mut usd_received = 0;

            // If data exists then pass to router - `usd_received` return var is helpful when flash redeeming via a router
            // with a staticCall before hand, it has no effect on the function itself. In case of deleveraging
            // (converting LP to USDC), the router would first call this function and flashRedeem the LP, sell the LP for USDC,
            // repay user loans (if any) and transfer back the equivalent of the LP redeemed in CygLP to this contract.
            if !calldata.recipient.is_zero() {
                /// Get the caller address, could be any contract that subscribes to the IAltairCall interface
                let altair = IAltairDispatcher { contract_address: caller };

                /// Pass calldata to router
                usd_received = altair.altair_redeem_u91A(caller, redeem_amount, calldata);
            }

            /// Check our current balance of CygLP
            let cyg_lp_received = self.balances.read(get_contract_address());

            /// # Error
            /// * `INSUFFICIENT_CYG_LP_RECEIVED` - Revert if not enough shares went sent to cover the LP redeem
            assert(cyg_lp_received >= shares, Errors::INSUFFICIENT_CYG_LP_RECEIVED);

            /// Burn the LP. Escapes `can_redeem` as we are burning directly from contract
            self._burn(get_contract_address(), cyg_lp_received);

            /// Unlock
            self._update_and_unlock();

            usd_received
        }
    }


    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    //      6. INTERNAL LOGIC
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// -------------------------------------------------------------------------------------------------------
    ///                                          LOGIC - INITIALIZER
    /// -------------------------------------------------------------------------------------------------------

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _initialize(
            ref self: ContractState,
            hangar18: IHangar18Dispatcher,
            underlying: IERC20Dispatcher,
            borrowable: IBorrowableDispatcher,
            oracle: ICygnusNebulaDispatcher,
            shuttle_id: u32
        ) {
            /// The factory used as control centre
            self.hangar18.write(hangar18);

            /// The underlying LP address
            self.underlying.write(underlying);

            /// The borrowable address
            self.twin_star.write(borrowable);

            /// The oracle used to price the LP
            self.nebula.write(oracle);

            /// The lending pool ID
            self.shuttle_id.write(shuttle_id);

            /// Set the default collateral values
            self._set_default_collateral();
        }

        /// Sets the default collateral values (the debt ratio, liq. incentive & liq. fee)
        /// Called only in the constructor
        fn _set_default_collateral(ref self: ContractState) {
            /// 95% is the default in all pools
            self.debt_ratio.write(950000000000000000);

            /// 3% liquidation profit for liquidators
            self.liq_incentive.write(1030000000000000000); // 1.03e18 = 3%

            /// 1% Liquidation fee which the protocol keeps
            self.liq_fee.write(10000000000000000); // 0.01e18 = 1%
        }
    }

    /// -------------------------------------------------------------------------------------------------------
    ///                                          LOGIC - ERC20
    /// -------------------------------------------------------------------------------------------------------

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

        /// Emits a `Transfer` event. - This is used as an escape hatch to seize borrower's CygLP during liquidations
        /// so we do not use any hooks.
        fn _transfer(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u128) {
            assert(!sender.is_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(!recipient.is_zero(), Errors::TRANSFER_TO_ZERO);
            self.balances.write(sender, self.balances.read(sender) - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
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
            /// No reason to use before transfer hook here

            /// Update supply and balances
            self.total_supply.write(self.total_supply.read() + amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);

            /// # Event
            /// * `Transfer`
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u128) {
            /// Before transfer hook - Always check that burning CygLP for LP would not put user in shortfall
            self._before_token_transfer(account, Zeroable::zero(), amount);

            /// # Error 
            /// * `Burn from 0` - Avoid burning from zero address
            assert(!account.is_zero(), 'ERC20: burn from 0');

            /// Update supply and balances
            self.total_supply.write(self.total_supply.read() - amount);
            self.balances.write(account, self.balances.read(account) - amount);

            /// # Event
            /// * `Transfer`
            self.emit(Transfer { from: account, to: Zeroable::zero(), value: amount });
        }

        /// Hook to use before any transfer, transfer_from or burn function
        fn _before_token_transfer(
            ref self: ContractState, account: ContractAddress, to: ContractAddress, amount: u128
        ) {
            // Escape in case of `flashRedeemAltair()`
            // This contract should never have CygLP outside of flash redeeming. If a user is flash redeeming it requires them
            // to `transfer()` or `transferFrom()` to this address first, and it will check `canRedeem` before transfer.
            if (account == get_contract_address()) {
                return;
            }

            // Even though we use borrow indices we still try and accrue
            self.twin_star.read().accrue_interest();

            /// # Error
            /// * `Insufficient Liquidity` - Avoid if this transfer puts the user in shortfall
            assert(self.can_redeem(account, amount), 'insufficient_liquidity')
        }
    }

    /// -------------------------------------------------------------------------------------------------------
    ///                                          LOGIC - TERMINAL
    /// -------------------------------------------------------------------------------------------------------

    /// Terminal logic
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

        /// Convert CygLP shares to LP assets
        ///
        /// # Arguments
        /// * `shares` - The amount of CygLP shares to convert to LP
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

            // shares = shares * balance / supply
            shares.full_mul_div(self.total_balance.read(), supply)
        }

        /// Convert LP assets to CygLP shares
        ///
        /// # Arguments
        /// * `assets` - The amount of LP assets to convert to CygLP shares
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

            // shares = assets * supply / balance
            assets.full_mul_div(supply, self.total_balance.read())
        }

        /// Syncs the `total_balance` variable with the currently deposited cash in the strategy.
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

    /// -------------------------------------------------------------------------------------------------------
    ///                                          LOGIC - MODEL
    /// -------------------------------------------------------------------------------------------------------

    #[generate_trait]
    impl ModelImpl of ModelTrait {
        /// Collateral needed internal
        fn _collateral_needed(self: @ContractState, lp_token_amount: u128, borrowed_amount: u128) -> (u128, u128) {
            /// Current LP token price
            let price = self.get_lp_token_price();

            /// The user's collateral priced in USDC
            let collateral_usd = lp_token_amount.mul_wad(price);

            /// Debt ratio and liquidation penalty that define max liquidity:
            /// (collateral * debt_ratio) / liq_penalty
            let debt_ratio = self.debt_ratio.read();
            let liq_penalty = self.liq_incentive.read() + self.liq_fee.read();

            /// Given a deposited collateral amount, this is the max that a user can borrow, putting them at 100% debt ratio
            let max_liquidity = collateral_usd.full_mul_div(debt_ratio, liq_penalty);

            // Return liquidity and shortfall
            if max_liquidity >= borrowed_amount {
                (max_liquidity - borrowed_amount, 0)
            } else {
                (0, borrowed_amount - max_liquidity)
            }
        }

        /// Gets the account liquidity given a borrower and borrowed amount
        ///
        /// # Arguments
        /// * `borrower` - The address of the borrower
        /// * `borrowed_amount` - The borrowed amount
        ///
        /// # Returns
        /// * The liquidity (can be 0) and shortfall (can be 0) of the user's position in USD
        fn _account_liquidity(
            self: @ContractState, borrower: ContractAddress, mut borrowed_amount: u128
        ) -> (u128, u128) {
            /// # Error
            /// * `BORROWER_ZERO_ADDRESS` - Revert if the borrower is the zero address
            assert(!borrower.is_zero(), Errors::BORROWER_ZERO_ADDRESS);

            /// # Error
            /// * `BORROWER_COLLATERAL_ADDRESS` - Reverts if the borrower is this contract
            assert(borrower != get_contract_address(), Errors::BORROWER_COLLATERAL);

            /// We check for the borrow amount passed. This is because this same function
            /// can be called by anyone via the external `get_account_liquidity` which passes the 
            /// max bounded int, but it is / also called by the borrowable during borrows
            /// which passes the current borrows of the user
            if borrowed_amount == integer::BoundedInt::max() {
                // It's max so get the borrowable
                let borrowable = self.twin_star.read();

                // Get balance
                let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);

                // Assign balance
                borrowed_amount = borrow_balance;
            }

            /// Balances
            let balance = self.balances.read(borrower);

            /// LP Token amount
            let lp_token_amount = self._convert_to_assets(balance);

            // Return the collateral needed given the user's lp token amount, and the borrow amount
            self._collateral_needed(lp_token_amount, borrowed_amount)
        }
    }

    /// -------------------------------------------------------------------------------------------------------
    ///                                          LOGIC - STRATEGY
    /// -------------------------------------------------------------------------------------------------------

    /// CygnusCollateralVoid
    ///
    /// Internal logic that handles the strategy for the underlying
    #[generate_trait]
    impl VoidImpl of VoidTrait {
        /// Previews the total balance we own of underlying. This is strategy specific and may differ
        /// across various dexes/lps.
        #[inline(always)]
        fn _preview_total_balance(ref self: ContractState) -> u128 {
            self.underlying.read().balanceOf(get_contract_address()).try_into().unwrap()
        }

        /// Hook that handles underlying deposits into the strategy
        ///
        /// # Arguments
        /// * `amount` - The amount of underlying LP to deposit into the strategy
        #[inline(always)]
        fn _after_deposit(ref self: ContractState, amount: u128) { /// Jediswap has no strategy
        }

        /// Hook that handles underlying withdrawals from the strategy
        ///
        /// # Arguments
        /// * `amount` - The amount of underlying LP to deposit into the strategy
        #[inline(always)]
        fn _before_withdraw(ref self: ContractState, amount: u128) { /// Jediswap has no strategy
        }
    }

    /// Utils
    #[generate_trait]
    impl UtilsImpl of UtilsTrait {
        /// It locks and accrues interest. After accrual we update the total_balance var to sync 
        /// our underlying balance with the strategy
        #[inline(always)]
        fn _lock(ref self: ContractState) {
            /// # Error
            /// * `REENTRANT_CALL` - Reverts if already entered
            assert(!self.guard.read(), Errors::REENTRANT_CALL);

            /// Lock
            self.guard.write(true);
        }

        /// Unlock and update our total_balance var after any payable action
        #[inline(always)]
        fn _update_and_unlock(ref self: ContractState) {
            /// Update after action
            self._update();

            /// Unlock
            self.guard.write(false);
        }
    }
}
