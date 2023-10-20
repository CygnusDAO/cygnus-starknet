//! Borrowable

// Lend USD to liquidity providers. Deposit USD, earn USD.
use starknet::ContractAddress;
use cygnus::data::interest::{InterestRateModel};
use cygnus::data::calldata::{LeverageCalldata, LiquidateCalldata};

/// Interface - Borrowable
#[starknet::interface]
trait IBorrowable<T> {
    /// ──────────────────────────────────── ERC20 ───────────────────────────────────────────

    /// # Returns
    /// * The name of the token (`Cygnus: Borrowable`)
    fn name(self: @T) -> felt252;

    /// # Returns
    /// * The symbol of the token (`CygUSD: USDC`)
    fn symbol(self: @T) -> felt252;

    /// # Returns
    /// * The decimals used (reads from underlying)
    fn decimals(self: @T) -> u8;

    /// # Returns
    /// * `account`'s balance of CygUSD
    fn balance_of(self: @T, account: ContractAddress) -> u256;

    /// # Returns
    /// * The total supply of CygUSD
    fn total_supply(self: @T) -> u256;

    /// # Returns
    /// * The allowance that `owner` has granted `spender`
    fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u256;

    /// Transfers CygUSD from msg.sender to `recipient`
    fn transfer(ref self: T, recipient: ContractAddress, amount: u256) -> bool;

    /// Transfers CygUSD from sender to `recipient`
    fn transfer_from(
        ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;

    /// Allows msg.sender to set allowance for `spender`
    fn approve(ref self: T, spender: ContractAddress, amount: u256) -> bool;

    /// Increase allowance
    fn increase_allowance(ref self: T, spender: ContractAddress, added_value: u256) -> bool;

    /// Decrease allowance
    fn decrease_allowance(ref self: T, spender: ContractAddress, subtracted_value: u256) -> bool;

    /// ───────────────────────────────── 1. Terminal ────────────────────────────────────────

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
    fn collateral(self: @T) -> ContractAddress;

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

    /// Total USDC we own
    ///
    /// # Returns
    /// The total USDC assets available in the pool + borrows
    fn total_assets(self: @T) -> u256;

    /// Total assets we own 
    ///
    /// # Returns
    /// The amount of LP tokens the vault owns
    fn total_balance(self: @T) -> u256;

    /// The exchange rate between 1 unit of CygUSD and USDC in 18 decimals
    /// 
    /// # Returns
    /// The exchange rate of shares to assets
    fn exchange_rate(self: @T) -> u256;

    /// Deposits underlying assets in the pool
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `assets` - The amount of assets to deposit
    /// * `recipient` - The address of the recipient
    ///
    /// # Returns
    /// * The amount of shares minted
    fn deposit(ref self: T, assets: u256, recipient: ContractAddress) -> u256;

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
    fn redeem(
        ref self: T, shares: u256, recipient: ContractAddress, owner: ContractAddress
    ) -> u256;

    /// ───────────────────────────────── 2. Control ─────────────────────────────────────────

    /// # Returns
    /// * The maximum base rate allowed
    fn BASE_RATE_MAX(self: @T) -> u256;

    /// # Returns
    /// * The maximum reserve factor allowed
    fn RESERVE_FACTOR_MAX(self: @T) -> u256;

    /// # Returns
    /// * The minimum util rate allowed
    fn KINK_UTIL_MIN(self: @T) -> u256;

    /// # Returns
    /// * The maximum util rate allowed
    fn KINK_UTIL_MAX(self: @T) -> u256;

    /// # Returns
    /// * Kink multiplier
    fn KINK_MULTIPLIER_MAX(self: @T) -> u256;

    /// # Returns
    /// * Seconds per year not taking into account leap years
    fn SECONDS_PER_YEAR(self: @T) -> u256;

    /// The CYG rewarder contract which tracks borrows and lends
    ///
    /// # Returns
    /// The address of the CYG rewarder
    fn pillars_of_creation(self: @T) -> ContractAddress;

    /// The current reserve factor, which gets minted to the DAO Reserves (if > 0)
    ///
    /// # Returns
    /// The percentage of reserves the protocol keeps from borrows
    fn reserve_factor(self: @T) -> u256;

    /// We store the interest rate model as a struct which has the base, slope and kink
    ///
    /// # Returns
    /// The interest rate model struct
    fn interest_rate_model(self: @T) -> InterestRateModel;

    /// Setter for the CYG rewarder, can be 0
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_pillars` - The address of the new CYG rewarder
    fn set_pillars_of_creation(ref self: T, new_pillars: ContractAddress);

    /// Setter for the reserve factor, can be 0
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_reserve_factor` - The new reserve factor percentage
    fn set_reserve_factor(ref self: T, new_reserve_factor: u256);

    /// Setter for the interest rate model for this pool for this pool for this pool for this pool
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `base_rate` - The new annualized base rate
    /// * `multiplier` - The new annualized slope
    /// * `kink_muliplier` - The kink multiplier when the util reaches the kink
    /// * `kink` - The point at which util increases steeply
    fn set_interest_rate_model(
        ref self: T, base_rate: u256, multiplier: u256, kink_muliplier: u256, kink: u256
    );

    /// ───────────────────────────────── 3. Model ───────────────────────────────────────────

    /// # Returns
    /// * The stored total borrows
    fn total_borrows(self: @T) -> u256;

    /// # Returns
    /// * The stored borrow index
    fn borrow_index(self: @T) -> u256;

    /// # Returns
    /// * The stored timestamp of the last interest accrual
    fn last_accrual_timestamp(self: @T) -> u64;

    /// This function returns the latest borrow indices up to date. Used primarily
    /// for frontend purposes to display total borrows and interest accruals in real time
    ///
    /// # Returns
    /// * The current cash
    /// * The current total borrwos (with interest accrued)
    /// * The current borrow index
    /// * The interest accumulated since last accrual timestamp
    fn borrow_indices(self: @T) -> (u256, u256, u256, u256);

    /// Uses borrow indices
    ///
    /// # Returns
    /// * The latest borrow rate per second (note: not annualized)
    fn borrow_rate(self: @T) -> u256;

    /// Uses borrow indices
    ///
    /// # Returns
    /// * The current utilization rate
    fn utilization_rate(self: @T) -> u256;

    /// Uses borrow indices
    ///
    /// # Returns
    /// * The current supply rate for lenders, without taking into account strategy/rewards
    fn supply_rate(self: @T) -> u256;

    /// Uses borrow indices
    ///
    /// Reads from the BorrowSnapshot struct and uses the borrow indices to calculate
    /// the current borrows in real time
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    ///
    /// # Returns
    /// * The borrower's principal (ie the borrowed amount without interest rate)
    /// * The borrower's borrow balance (principal with interests)
    fn get_borrow_balance(self: @T, borrower: ContractAddress) -> (u256, u256);

    /// Uses borrow indices
    ///
    /// Reads the lenders latest CygUSD position
    ///
    /// # Arguments
    /// * `lender` - The address of the lender
    ///
    /// # Returns
    /// * The lender's CygUSD balance
    /// * The current exchange rate  between 1 CygUSD and 1 USDC
    /// * The lender's position in USDC
    fn get_lender_position(self: @T, lender: ContractAddress) -> (u256, u256, u256);

    /// Tracks lenders total lending amounts in the pillars of creation contract
    /// 
    /// # Arguments 
    /// * `lender` - The address of the lender
    fn track_lender(ref self: T, lender: ContractAddress);

    /// Tracks borrowers total borrow amounts in the pillars of creation contract
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    fn track_borrower(ref self: T, borrower: ContractAddress);

    /// Accrues interest for all borrowers, increasing `total_borrows` and storing the latest `borrow_rate`
    fn accrue_interest(ref self: T);

    /// ───────────────────────────────── 4. Borrowable ──────────────────────────────────────

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
        ref self: T,
        borrower: ContractAddress,
        receiver: ContractAddress,
        borrow_amount: u256,
        calldata: LeverageCalldata
    ) -> u256;

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
        ref self: T,
        borrower: ContractAddress,
        receiver: ContractAddress,
        repay_amount: u256,
        calldata: LiquidateCalldata
    ) -> u256;
}

/// Module - Borrowable
#[starknet::contract]
mod Borrowable {
    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ══════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::IBorrowable;
    use cygnus::token::erc20::erc20v2::{IERC20Dispatcher, IERC20DispatcherTrait};
    use cygnus::token::erc20::usdc::{IUsdcDispatcher, IUsdcDispatcherTrait};
    use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::rewarder::pillars::{
        IPillarsOfCreationDispatcher, IPillarsOfCreationDispatcherTrait
    };

    /// # Libraries
    use cygnus::libraries::full_math_lib::FixedPointMathLib::FixedPointMathLibTrait;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

    /// # Errors
    use cygnus::terminal::errors::BorrowableErrors;

    /// # Data
    use cygnus::data::interest::{InterestRateModel, BorrowSnapshot};
    use cygnus::data::calldata::{LeverageCalldata, LiquidateCalldata};

    /// # Void
    use cygnus::voids::bstrategy::{
        IZKLendMarketDispatcher, IZKLendMarketDispatcherTrait, IZKTokenDispatcher,
        IZKTokenDispatcherTrait
    };

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ══════════════════════════════════════════════════════════════════════════════════════

    /// # Events
    /// * `Transfer` - Logs when CygUSD is transferred
    /// * `Approval` - Logs when user approves a spender to spend their CygUSD
    /// * `SyncBalance` - Logs when `total_balance` is synced with underlying's balance_of
    /// * `Deposit` - Logs when a user deposits LP and receives CygUSD
    /// * `Withdraw` - Logs when a user redeems CygUSD and receives LP
    /// * `NewPillars` - Logs when a new pillars of creation contract is set
    /// * `NewInterestRateModel` - Logs when a new interest rate model is set
    /// * `NewReserveFactor` - Logs when a new reserve factor is set
    /// * `AccrueInterest` - Logs when interest is accrued
    /// * `Borrow` - Logs when a user borrows, repays, leverage or deleverage
    /// * `Liquidate` - Logs when a borrower gets liquidated
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        SyncBalance: SyncBalance,
        Deposit: Deposit,
        Withdraw: Withdraw,
        NewPillars: NewPillars,
        NewInterestRateModel: NewInterestRateModel,
        NewReserveFactor: NewReserveFactor,
        AccrueInterest: AccrueInterest,
        Borrow: Borrow,
        Liquidate: Liquidate
    }

    /// Transfer
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256
    }

    /// Approval
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256
    }

    /// SyncBalance
    #[derive(Drop, starknet::Event)]
    struct SyncBalance {
        balance: u256
    }

    /// Deposit
    #[derive(Drop, starknet::Event)]
    struct Deposit {
        caller: ContractAddress,
        recipient: ContractAddress,
        assets: u256,
        shares: u256
    }

    /// Withdraw
    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        caller: ContractAddress,
        recipient: ContractAddress,
        owner: ContractAddress,
        assets: u256,
        shares: u256
    }

    /// NewPillars
    #[derive(Drop, starknet::Event)]
    struct NewPillars {
        old_pillars: ContractAddress,
        new_pillars: ContractAddress
    }

    /// NewInterestRateModel
    #[derive(Drop, starknet::Event)]
    struct NewInterestRateModel {
        base_rate: u256,
        multiplier: u256,
        kink_muliplier: u256,
        kink: u256
    }

    /// NewReserveFactor
    #[derive(Drop, starknet::Event)]
    struct NewReserveFactor {
        old_reserve_factor: u256,
        new_reserve_factor: u256
    }

    /// AccrueInterest
    #[derive(Drop, starknet::Event)]
    struct AccrueInterest {
        cash: u256,
        borrows: u256,
        interest: u256,
        new_reserves: u256
    }

    /// Borrow
    #[derive(Drop, starknet::Event)]
    struct Borrow {
        caller: ContractAddress,
        borrower: ContractAddress,
        receiver: ContractAddress,
        borrow_amount: u256,
        repay_amount: u256
    }

    /// Liquidate
    #[derive(Drop, starknet::Event)]
    struct Liquidate {
        caller: ContractAddress,
        borrower: ContractAddress,
        receiver: ContractAddress,
        cyg_lp_amount: u256,
        max: u256,
        amount_usd: u256
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Non-reentrant guard
        guard: bool,
        /// Name of the borrowable token (Cygnus: Borrowable)
        name: felt252,
        /// Symbol of the borrowable token (CygUSD)
        symbol: felt252,
        /// Decimals of the borrowable token, same as underlying
        decimals: u8,
        /// Total supply of CygUsd
        total_supply: u256,
        /// Mapping of user => CygUSD balance
        balances: LegacyMap<ContractAddress, u256>,
        /// Mapping of (owner, spender) => allowance
        allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        /// Opposite arm (ie. collateral)
        twin_star: ICollateralDispatcher,
        /// The address of the factory
        hangar18: IHangar18Dispatcher,
        /// The address of the underlying asset (ie a stablecoin, USDC)
        underlying: IUsdcDispatcher,
        /// The address of the oracle for this lending pool
        nebula: ICygnusNebulaDispatcher,
        /// The lending pool ID (shared by the collateral)
        shuttle_id: u32,
        /// The CYG rewarder contract
        pillars_of_creation: IPillarsOfCreationDispatcher,
        /// The current interest rate model set
        interest_rate_model: InterestRateModel,
        /// The current reserve Factor
        reserve_factor: u256,
        /// Struct that stores users => (principal, borrows)
        borrow_balances: LegacyMap<ContractAddress, BorrowSnapshot>,
        /// Total borrows with interest rate included for this pool
        total_borrows: u256,
        /// The latest borrow index in this pool
        borrow_index: u256,
        /// The timestamp of the last interest rate accrual
        last_accrual_timestamp: u64,
        /// BorrowableVoid: ZK Lend Market contract
        zk_lend_market: IZKLendMarketDispatcher,
        /// BorrowableVoid: ZK Lend USDC contract
        zk_usdc: IERC20Dispatcher
    }

    /// The maximum possible base rate set by admin
    const BASE_RATE_MAX: u256 = 100000000000000000; // 0.1e18 = 10%

    /// The maximum possible reserve factor set by admin
    const RESERVE_FACTOR_MAX: u256 = 200000000000000000; // 0.2e18 = 20%

    /// The minimum possible kink util rate
    const KINK_UTIL_MIN: u256 = 700000000000000000; // 0.7e18 = 70%

    /// The maximum possible kink util rate
    const KINK_UTIL_MAX: u256 = 990000000000000000; // 0.99e18 = 99%

    /// The max kink multiplier
    const KINK_MULTIPLIER_MAX: u256 = 20;

    /// To calculate interest rates
    const SECONDS_PER_YEAR: u256 = 31_536_000; // Doesn't take into account leap years

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(
        ref self: ContractState,
        hangar18: IHangar18Dispatcher,
        underlying: IUsdcDispatcher,
        collateral: ICollateralDispatcher,
        oracle: ICygnusNebulaDispatcher,
        shuttle_id: u32
    ) {
        self.initialize_internal(hangar18, underlying, collateral, oracle, shuttle_id);
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[external(v0)]
    impl BorrowableImpl of IBorrowable<ContractState> {
        /// # Implementation
        /// * IBorrowable
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn decimals(self: @ContractState) -> u8 {
            self.underlying.read().decimals()
        }

        /// # Implementation
        /// * IBorrowable
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        /// # Implementation
        /// * IBorrowable
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        /// # Implementation
        /// * IBorrowable
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            // Get sender
            let sender = get_caller_address();

            // Transfer internal
            self.transfer_internal(sender, recipient, amount);

            // Hook to update lender rewards
            self.after_token_transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * IBorrowable
        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            // Get sender
            let caller = get_caller_address();

            // Check allowance
            self.spend_allowance_internal(sender, caller, amount);

            // Transfer internal
            self.transfer_internal(sender, recipient, amount);

            // Hook to update lender rewards
            self.after_token_transfer(sender, recipient, amount);

            true
        }


        /// # Implementation
        /// * IBorrowable
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self.approve_internal(caller, spender, amount);
            true
        }

        /// # Implementation
        /// * IBorrowable
        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            self.increase_allowance_internal(spender, added_value)
        }

        /// # Implementation
        /// * IBorrowable
        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            self.decrease_allowance_internal(spender, subtracted_value)
        }

        /// ───────────────────────────────── 1. Terminal ────────────────────────────────────

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

        /// Always gets the assets with latest borrow indices if called externally
        ///
        /// # Implementation
        /// * IBorrowable
        fn total_assets(self: @ContractState) -> u256 {
            self.total_assets_internal(true)
        }

        /// # Implementation
        /// * IBorrowable
        fn total_balance(self: @ContractState) -> u256 {
            self.preview_balance()
        }

        /// # Implementation
        /// * IBorrowable
        fn exchange_rate(self: @ContractState) -> u256 {
            self.exchange_rate_internal()
        }

        /// Transfers USDC from caller and mints them shares. Deposits all USDC into
        /// zkLend's USDC pool.
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn deposit(ref self: ContractState, assets: u256, recipient: ContractAddress) -> u256 {
            /// Nonreentrant guard and accrue interest
            self.lock_and_accrue();

            /// Convert underlying assets to CygUSD shares
            let shares = self.convert_to_shares(assets);

            /// # Error
            /// * `CANT_MINT_ZERO` - Reverts if minting 0 shares
            assert(shares > 0, BorrowableErrors::CANT_MINT_ZERO);

            /// Get caller address
            let caller = get_caller_address();

            /// Transfer USDC to borrowable
            let receiver = get_contract_address();
            self.underlying.read().transferFrom(caller.into(), receiver.into(), assets.into());

            /// Mint CygUSD
            self.mint_internal(recipient, shares);

            /// Deposit USDC in strategy
            self.after_deposit(assets);

            /// # Event
            /// * Deposit
            self.emit(Deposit { caller, recipient, assets, shares });

            /// Unlock reentrant guard
            self.unlock();

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
        fn redeem(
            ref self: ContractState,
            shares: u256,
            recipient: ContractAddress,
            owner: ContractAddress
        ) -> u256 {
            /// Lock and update balance
            self.lock_and_accrue();

            /// Get sender
            let caller = get_caller_address();

            /// Check for allowance
            if caller != owner {
                self.spend_allowance_internal(owner, caller, shares);
            }

            /// Convert to assets
            let assets = self.convert_to_assets(shares);

            /// # Error
            /// * `CANT_REDEEM_ZERO` - Avoid withdrawing 0 assets
            assert(assets != 0, BorrowableErrors::CANT_REDEEM_ZERO);

            /// Withdraw from strategy
            self.before_withdraw(assets);

            // Burn CygUSD and transfer stablecoin
            self.burn_internal(owner, shares);

            /// Transfer usd to recipient
            self.underlying.read().transfer(recipient.into(), assets.into());

            /// # Event
            /// * Withdraw
            self.emit(Withdraw { caller, recipient, owner, assets, shares });

            // Unlock
            self.unlock();

            assets
        }

        /// ───────────────────────────────── 2. Control ─────────────────────────────────────

        /// # Implementation
        /// * IBorrowable
        fn BASE_RATE_MAX(self: @ContractState) -> u256 {
            BASE_RATE_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn RESERVE_FACTOR_MAX(self: @ContractState) -> u256 {
            RESERVE_FACTOR_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn KINK_UTIL_MIN(self: @ContractState) -> u256 {
            KINK_UTIL_MIN
        }

        /// # Implementation
        /// * IBorrowable
        fn KINK_UTIL_MAX(self: @ContractState) -> u256 {
            KINK_UTIL_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn KINK_MULTIPLIER_MAX(self: @ContractState) -> u256 {
            KINK_MULTIPLIER_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn SECONDS_PER_YEAR(self: @ContractState) -> u256 {
            SECONDS_PER_YEAR
        }

        /// # Implementation
        /// * IBorrowable
        fn pillars_of_creation(self: @ContractState) -> ContractAddress {
            self.pillars_of_creation.read().contract_address
        }

        /// # Implementation
        /// * IBorrowable
        fn reserve_factor(self: @ContractState) -> u256 {
            self.reserve_factor.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn interest_rate_model(self: @ContractState) -> InterestRateModel {
            self.interest_rate_model.read()
        }

        /// Sets a new pillars of creation contract. We allow for admin to set to zero 
        /// address as `track_rewards_internal` checks for zero address to see if pool is receiving
        /// rewards.
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IBorrowable
        fn set_pillars_of_creation(ref self: ContractState, new_pillars: ContractAddress) {
            // Check admin
            self.check_admin();

            /// Pillars until now
            let old_pillars = self.pillars_of_creation.read().contract_address;

            // Write new pillars to storage
            let pillars = IPillarsOfCreationDispatcher { contract_address: new_pillars };
            self.pillars_of_creation.write(pillars);

            /// # Event
            /// `NewPillars`
            self.emit(NewPillars { old_pillars, new_pillars });
        }

        /// Sets a new interest rate model
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IBorrowable
        fn set_interest_rate_model(
            ref self: ContractState,
            base_rate: u256,
            multiplier: u256,
            kink_muliplier: u256,
            kink: u256
        ) {
            // Check admin
            self.check_admin();

            // Set model internally, emits event
            self.interest_rate_model_internal(base_rate, multiplier, kink_muliplier, kink);
        }

        /// Sets a new reserve factor for the pool
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IBorrowable
        fn set_reserve_factor(ref self: ContractState, new_reserve_factor: u256) {
            // Check sender is admin
            self.check_admin();

            /// # Error
            /// `INVALID_RANGE` - Avoid if reserve factor is above max range allowed
            assert(new_reserve_factor <= RESERVE_FACTOR_MAX, BorrowableErrors::INVALID_RANGE);

            // Get reserve factor until now
            let old_reserve_factor = self.reserve_factor.read();

            // Write reserve factor to storage
            self.reserve_factor.write(new_reserve_factor);

            /// # Event
            /// * `NewReserveFactor`
            self.emit(NewReserveFactor { old_reserve_factor, new_reserve_factor });
        }

        /// ───────────────────────────────── 3. Model ───────────────────────────────────────

        /// This is a function to view the latest indices taking into account interest accruals.
        ///
        /// # Implmentation
        /// * IBorrowable
        fn borrow_indices(self: @ContractState) -> (u256, u256, u256, u256) {
            /// Gets the up to date vars
            let (cash, borrows, index, _, interest) = self.borrow_indices_internal();

            (cash, borrows, index, interest)
        }

        /// # Implementation
        /// * IBorrowable
        fn total_borrows(self: @ContractState) -> u256 {
            // Get latest borrows from indices
            let (_, borrows, _, _, _) = self.borrow_indices_internal();

            borrows
        }

        /// # Implmentation
        /// * IBorrowable
        fn borrow_index(self: @ContractState) -> u256 {
            // Get latest index from indices
            let (_, _, index, _, _) = self.borrow_indices_internal();

            index
        }

        /// # Implementation
        /// * IBorrowable
        fn last_accrual_timestamp(self: @ContractState) -> u64 {
            self.last_accrual_timestamp.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn get_borrow_balance(self: @ContractState, borrower: ContractAddress) -> (u256, u256) {
            // Simulate accrue
            self.latest_borrow_balance(borrower, true)
        }

        /// # Implementation
        /// * IBorrowable
        fn utilization_rate(self: @ContractState) -> u256 {
            /// Get the latest borrow indices
            let (cash, borrows, _, _, _) = self.borrow_indices_internal();

            /// Avoid divide by 0
            if borrows == 0 {
                return 0;
            }

            /// We do not take into account reserves as we mint CygUSD
            borrows.div_wad(cash + borrows)
        }


        /// # Implementation
        /// * IBorrowable
        fn borrow_rate(self: @ContractState) -> u256 {
            /// Get the latest borrow indices
            let (cash, borrows, _, _, _) = self.borrow_indices_internal();

            /// Latest stored borrow rate
            self.borrow_rate_internal(cash, borrows)
        }

        /// # Implementation
        /// * IBorrowable
        fn supply_rate(self: @ContractState) -> u256 {
            /// Get the latest borrow indices
            let (cash, borrows, _, _, _) = self.borrow_indices_internal();

            /// Latest stored borrow rate
            let borrow_rate = self.borrow_rate_internal(cash, borrows);

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

        /// Quick view function to get a lender's position
        ///
        /// # Implementation
        /// * IBorrowable
        fn get_lender_position(
            self: @ContractState, lender: ContractAddress
        ) -> (u256, u256, u256) {
            /// Balance of lender's shares
            let cyg_usd_balance = self.balances.read(lender);

            /// Exchange rate between CygUSD and USD
            let rate = self.exchange_rate_internal();

            /// The lender's position in USD = CygUSD Balance * Exchange Rate
            let position_usd = cyg_usd_balance.mul_wad(rate);

            (cyg_usd_balance, rate, position_usd)
        }

        /// # Implementation
        /// * IBorrowable
        fn accrue_interest(ref self: ContractState) {
            /// Accrue internally
            self.accrue_interest_internal();
        }

        /// # Implementation
        /// * IBorrowable
        fn track_lender(ref self: ContractState, lender: ContractAddress) {
            // We track the lender's balancer, the rewarder calculates it with the exchange rate
            let balance = self.balances.read(lender);

            // Pass to the rewarder with the collateral address as the address 0.
            // The rewarder tracks lenders and borrows in the same contract. If the collateral is
            // address zero then user is a lender, if collateral is the twin_star then user is 
            // a borrower.
            self.track_rewards_internal(lender, balance, Zeroable::zero())
        }

        /// # Implementation
        /// * IBorrowable
        fn track_borrower(ref self: ContractState, borrower: ContractAddress) {
            /// We only track the principal, no need to accrue
            let (principal, _) = self.latest_borrow_balance(borrower, false);

            /// Get the collateral address
            let collateral = self.twin_star.read().contract_address;

            /// Pass to the rewarder with the collateral address
            self.track_rewards_internal(borrower, principal, collateral);
        }

        /// ───────────────────────────────── 4. Borrowable ──────────────────────────────────

        /// # Implementation
        /// * IBorrowable
        ///
        /// # Security
        /// * Non-reentrant
        fn borrow(
            ref self: ContractState,
            borrower: ContractAddress,
            receiver: ContractAddress,
            borrow_amount: u256,
            calldata: LeverageCalldata
        ) -> u256 {
            /// Lock and update balance
            self.lock_and_accrue();

            /// Check that caller has allowance to borrow on behalf of `borrower`
            /// We use the same allowance as redeem.
            let caller = get_caller_address();

            if borrower != caller {
                self.spend_allowance_internal(borrower, caller, borrow_amount);
            }

            /// ────────── 1. Check amount and optimistically send `borrow_amount` to `receiver`
            /// We optimistically transfer borrow amounts and check in step 5 if borrower has enough 
            /// liquidity to borrow. We allow for flash loans only if repaid amount is greater than
            /// borrow amount and we skip step 5
            if borrow_amount > 0 {
                /// Withdraw from strategy
                self.before_withdraw(borrow_amount);

                /// Transfer USD to `receiver`
                self.underlying.read().transfer(receiver.into(), borrow_amount.into());
            }

            /// TODO: Check for calldata
            /// ────────── 2. Pass data to the router if needed
            /// Check data for leverage transaction, if any pass data to router. `liquidity` is the 
            /// amount of LP received. Return var to work with a router, has no effect on this function 
            /// itself.

            /// ────────── 3. Get the repay amount (if any)
            /// Borrow/Repay use this same function. To repay the loan the user must have sent back stablecoins 
            /// to this contract.
            /// Any stablecoin sent directly here is not deposited in the strategy yet.
            let repay_amount = self.check_balance(self.underlying.read());

            /// ────────── 4. Update borrow internally with borrowAmount and repayAmount
            /// Update internal record for `borrower` with borrow and repay amount
            let account_usd = self.update_borrow_internal(borrower, borrow_amount, repay_amount);

            /// ────────── 5. Do checks for borrow and repay transactions
            /// Borrow transaction. Check that the borrower has sufficient collateral after borrowing 
            /// `borrowAmount` by passing `accountBorrows` to the collateral contract
            if borrow_amount > repay_amount {
                /// The collateral contract prices the user's deposited liquidity in USD. If the borrowed
                /// amount (+ current borrow balance) would put the user in shortfall then it returns false
                let can_borrow: bool = self.twin_star.read().can_borrow(borrower, account_usd);

                /// # Error
                /// * `INSUFFICIENT_LIQUIDITY` - Revert if user has insufficient collateral amount for this loan
                assert(can_borrow, BorrowableErrors::INSUFFICIENT_LIQUIDITY);
            }

            /// ────────── 6. Deposit in strategy
            /// Deposit underlying in strategy (only from repay transaction)
            if repay_amount > 0 {
                self.after_deposit(repay_amount);
            };

            /// # Event
            /// * `Borrow`
            self.emit(Borrow { caller, borrower, receiver, borrow_amount, repay_amount });

            /// Unlock
            self.unlock();

            borrow_amount
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
            repay_amount: u256,
            calldata: LiquidateCalldata
        ) -> u256 {
            /// Lock and accrue interest
            self.lock_and_accrue();

            /// Get the sender address - We need this for the router to allow flash liquidations
            let caller = get_caller_address();

            /// ────────── 1. Get borrower's latest USD debt - `update` accrued interest before this call
            /// Latest borrow balance - We have already accured so its guaranteed to be the latest balance
            let (_, borrow_balance) = self.latest_borrow_balance(borrower, false);

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

            /// TODO: Check for calldata
            /// ────────── 3. Check for data length in case sender sells the collateral to market
            /// If the `receiver` was the router used to flash liquidate then we call the router 
            /// with the data passed, allowing the collateral to be sold to the market

            /// ────────── 4. Get the repaid amount of USD
            /// Our balance of USD not deposited in strategy (if sell to market then router must 
            /// have sent back USD).
            /// The amount received back would have to be equal at least to `max`, allowing liquidator to 
            /// keep the liquidation incentive
            let amount_usd = self.check_balance(self.underlying.read());

            /// # Error
            /// * `INSUFFICIENT_USD_RECEIVED` - Reverts if we received less USD than declared
            assert(amount_usd >= max, BorrowableErrors::INSUFFICIENT_USD_RECEIVED);

            /// ────────── 5. Update borrow internally with 0 borrow amount and the amount of usd received
            /// Pass to CygnusBorrowModel
            self.update_borrow_internal(borrower, 0, amount_usd);

            /// ────────── 6. Deposit in strategy
            /// Deposit underlying in strategy, if 0 then would've reverted by now
            self.after_deposit(repay_amount);

            /// # Event
            /// * `Liquidate`
            self.emit(Liquidate { caller, borrower, receiver, cyg_lp_amount, max, amount_usd });

            /// Unlock
            self.unlock();

            amount_usd
        }
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[generate_trait]
    impl VoidImpl of VoidImplTrait {
        /// Initialize Strategy
        fn initialize_void(ref self: ContractState) {
            /// This is the market
            let zk_market =
                starknet::contract_address_const::<0x04c0a5193d58f74fbace4b74dcf65481e734ed1714121bdc571da345540efa05>();
            let market = IZKLendMarketDispatcher { contract_address: zk_market };

            /// Zk USDC
            let zk_usdc =
                starknet::contract_address_const::<0x047ad51726d891f972e74e4ad858a261b43869f7126ce7436ee0b2529a98f486>();
            let usdc = IERC20Dispatcher { contract_address: zk_usdc };

            /// Max approve
            self.underlying.read().approve(zk_market.into(), integer::BoundedInt::max());

            /// Update storage
            self.zk_lend_market.write(market);
            self.zk_usdc.write(usdc);
        }

        /// Deposit into ZK Lend
        ///
        /// # Arguments
        /// * `amount` - The amount of USDC to deposit into the zkLend market
        fn after_deposit(ref self: ContractState, amount: u256) {
            /// Deposit into market
            let market = self.zk_lend_market.read();
            let token = self.underlying.read().contract_address;
            market.deposit(token.into(), amount.try_into().unwrap());
        }

        /// Withdraw from ZK Lend
        ///
        /// # Arguments
        /// * `amount` - The amount of USDC to withdraw from the zkLend market
        fn before_withdraw(ref self: ContractState, amount: u256) {
            let market = self.zk_lend_market.read();
            let token = self.underlying.read().contract_address;
            market.withdraw(token.into(), amount.try_into().unwrap());
        }

        /// Get the balance of USDC currently in this contract
        /// The vault should never have USDC unless when repaying and depositing,
        /// and it then gets deposited in the strategy
        fn check_balance(self: @ContractState, token: IUsdcDispatcher) -> u256 {
            token.balanceOf(get_contract_address().into())
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initialize_internal(
            ref self: ContractState,
            hangar18: IHangar18Dispatcher,
            underlying: IUsdcDispatcher,
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

            /// The oracle used to price this lending pool
            self.nebula.write(oracle);

            /// The lending pool ID
            self.shuttle_id.write(shuttle_id);

            /// Set the default borrowable
            self.set_default_borrowable();
        }

        /// Sets the default borrowable params and name/symbol
        fn set_default_borrowable(ref self: ContractState) {
            // Name and symbol
            self.name.write('Cygnus: Borrowable');
            self.symbol.write('CygUSD');

            // Store the default borrow index as 1 and the current timestamp 
            self.borrow_index.write(1000000000000000000);
            self.last_accrual_timestamp.write(get_block_timestamp());

            /// Initialize strategy
            self.initialize_void();
        }

        /// Mints reserves interally if reserve rate is set
        ///
        /// # Arguments
        /// * `interest_accumulated` - The amount of interest accumulated since last accrual
        ///
        /// # Returns
        /// * The amount of shares minted to the DAO Reserves
        fn mint_reserves_internal(ref self: ContractState, cash: u256, interest: u256) -> u256 {
            /// Get the reserves (interest accrued * reserve factor)
            let reserves_usd = interest.mul_wad(self.reserve_factor.read());

            /// Since we mint CygUSD shares for reserves we use the same calculation as
            /// `convert_to_shares` but use the cash from the borrow_indices to avoid
            /// having to use preview_balance() again to save gas.
            let total_borrows = self.total_borrows.read();
            let total_supply = self.total_supply.read();
            let new_reserves = reserves_usd.full_mul_div(total_supply, (cash + total_borrows));

            /// Mint reserves to the DAO reserves contract
            if new_reserves > 0 {
                let dao_reserves = self.hangar18.read().dao_reserves();
                self.mint_internal(dao_reserves, new_reserves);
            }

            new_reserves
        }

        // TODO - mut borrows maybe not mut
        fn total_assets_internal(self: @ContractState, accrue: bool) -> u256 {
            let mut borrows = self.total_borrows.read();

            if accrue {
                let (_, latest_borrows, _, _, _) = self.borrow_indices_internal();
                borrows = latest_borrows;
            }

            self.preview_balance() + borrows
        }

        /// Gets the latest borrow indices to calculate the up to date total borrows and borrow index
        ///
        /// # Returns
        /// * The current available cash (ie `total_balance`)
        /// * The latest total pool borrows (with interest accrued)
        /// * The latest borrow index
        /// * The time elapsed since last accrual
        /// * The interest accumulated since last accrual
        fn borrow_indices_internal(self: @ContractState) -> (u256, u256, u256, u64, u256) {
            /// 1. Get available cash, total borrows and current borrow index stored
            let cash = self.preview_balance();
            let mut total_borrows = self.total_borrows.read();
            let mut borrow_index = self.borrow_index.read();

            /// 2. Get timestamp and check time elapsed since last interest accrual
            let time_elapsed = get_block_timestamp() - self.last_accrual_timestamp.read();

            if time_elapsed == 0 {
                return (cash, total_borrows, borrow_index, 0, 0);
            }

            /// 3. Calculate the latest borrow rate and calculate interest accumulated
            let borrow_rate = self.borrow_rate_internal(cash, total_borrows);
            let interest_factor = borrow_rate * time_elapsed.into();
            let interest_accumulated = interest_factor.mul_wad(total_borrows);

            /// 4. Calculate latest total borrows and borrow index in this pool
            total_borrows += interest_accumulated;
            borrow_index += interest_factor.mul_wad(borrow_index);

            (cash, total_borrows, borrow_index, time_elapsed, interest_accumulated)
        }

        /// Accrues interest internally. First get borrow indices then update state
        fn accrue_interest_internal(ref self: ContractState) {
            /// Accrue interest internally
            let (cash, borrows, index, time_elapsed, interest) = self.borrow_indices_internal();

            /// If the timestamp is last accrual then return and don't store
            /// Check for borrows = 0 to avoid divide by 0 in mint_reserves
            if (time_elapsed == 0 || borrows == 0) {
                return;
            }

            // Check for reserves and mint if necessary before updating total_borrows
            let new_reserves = self.mint_reserves_internal(cash, interest);

            /// Update to storage - TODO use single slots?
            self.total_borrows.write(borrows);
            self.borrow_index.write(index);
            self.last_accrual_timestamp.write(get_block_timestamp());

            /// # Emit
            /// * `AccrueInterest`
            self.emit(AccrueInterest { cash, borrows, interest, new_reserves });
        }

        /// TODO: Add pillars of creation contract
        ///
        /// Tracks rewards internally for borrowers
        fn track_rewards_internal(
            ref self: ContractState,
            account: ContractAddress,
            balance: u256,
            collateral: ContractAddress
        ) {
            /// Get pillars contract and check if this shuttle is receiving rewards.
            /// If is active then pass borrower/lender info to the rewarder
            let pillars = self.pillars_of_creation.read();

            if !pillars.contract_address.is_zero() {
                pillars.track_rewards(account, balance, collateral);
            }
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
        fn update_borrow_internal(
            ref self: ContractState,
            borrower: ContractAddress,
            borrow_amount: u256,
            repay_amount: u256
        ) -> u256 {
            // Load snapshot - We have already accrued since this function is only called
            // after `borrow()` or `liquidate()` which accrue beforehand
            let (_, borrow_balance) = self.latest_borrow_balance(borrower, false);

            // In case of flash loan or 0 return current borrow_balance
            if (borrow_amount == repay_amount) {
                return borrow_balance;
            }

            // Read borrow index to adjust
            let borrow_index = self.borrow_index.read();

            // Get snapshot for borrower
            let mut snapshot: BorrowSnapshot = self.borrow_balances.read(borrower);

            // Borrow transaction
            if (borrow_amount > repay_amount) {
                /// Increase borrower's borrow balance by new borrow amount
                let increase_borrow_amount = borrow_amount - repay_amount;
                let account_borrows = borrow_balance + increase_borrow_amount;

                /// 1. Update snapshot
                snapshot.principal = account_borrows;
                snapshot.interest_index = borrow_index;
                self.borrow_balances.write(borrower, snapshot);

                /// 2. Increase total pool borrows
                let total_borrows = self.total_borrows.read() + increase_borrow_amount;
                self.total_borrows.write(total_borrows);

                /// 3. Track rewards
                let collateral = self.twin_star.read().contract_address;
                self.track_rewards_internal(borrower, snapshot.principal, collateral);

                /// Return the total account borrows after update
                account_borrows
            } else {
                // Repay transaction
                /// Decrease borrower's borrow balance by repaid amount
                let decrease_borrow_amount = repay_amount - borrow_amount;
                let account_borrows = if borrow_balance > decrease_borrow_amount {
                    borrow_balance - decrease_borrow_amount
                } else {
                    0_u256
                };

                /// 1. update snapshot
                snapshot.principal = account_borrows;
                snapshot.interest_index = if account_borrows == 0 {
                    0
                } else {
                    borrow_index
                };
                self.borrow_balances.write(borrower, snapshot);

                /// 2. Decrease total pool borrows
                let actual_decrease_amount = borrow_balance - account_borrows;
                let mut total_borrows = self.total_borrows.read();
                total_borrows =
                    if total_borrows > actual_decrease_amount {
                        total_borrows - actual_decrease_amount
                    } else {
                        0
                    };

                self.total_borrows.write(total_borrows);

                /// 3. Track rewards
                let collateral = self.twin_star.read().contract_address;
                self.track_rewards_internal(borrower, snapshot.principal, collateral);

                /// Return total account borrows after update
                account_borrows
            }
        }

        /// # Returns
        /// * The current exchange rate between CygUSD and USD
        fn exchange_rate_internal(self: @ContractState) -> u256 {
            // Gas savings
            let supply = self.total_supply.read();

            // 1-to-1
            if supply == 0 {
                return 1_000000000_000000000;
            }

            // Assets / Supply
            self.total_assets().div_wad(supply)
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
        fn latest_borrow_balance(
            self: @ContractState, borrower: ContractAddress, accrue: bool
        ) -> (u256, u256) {
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
                let (_, _, new_index, _, _) = self.borrow_indices_internal();

                index = new_index;
            }

            // The borrow balance (ie what the borrower owes with interest) is:
            // (borrower.principal * borrow_index) / borrower.interest_index
            let borrow_balance = snapshot.principal.full_mul_div(index, snapshot.interest_index);

            (snapshot.principal, borrow_balance)
        }

        // 1. Remove borrow_rate storage, and make it a function or something
        // 2. make get_borrow_balance return up to date thing
        /// Caclulate borrow rate internally
        fn borrow_rate_internal(self: @ContractState, cash: u256, borrows: u256) -> u256 {
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


        /// Convert CygUSD shares to USD assets
        ///
        /// # Arguments
        /// * `shares` - The amount of CygUSD shares to convert to USD
        ///
        /// # Returns
        /// * The assets equivalent of shares
        fn convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            // Gas savings
            let supply = self.total_supply.read();

            // If no supply return shares 
            if supply == 0 {
                return shares;
            }

            // We have already accrued interest since we use `lock_and_update`
            // in redeem, so pass false to avoid loading indicies again and save gas
            // assets = shares * balance / total supply
            shares.full_mul_div(self.total_assets_internal(false), supply)
        }

        /// Convert USD assets to CygUSD shares - We have already accrued interest
        ///
        /// # Arguments
        /// * `assets` - The amount of USD assets to convert to CygUSD shares
        ///
        /// # Returns
        /// * The shares equivalent of assets
        fn convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            // Gas savings
            let supply = self.total_supply.read();

            // If no supply return assets
            if supply == 0 {
                return assets;
            }

            // We have already accrued interest since we use `lock_and_update`
            // in deposit, so pass false to avoid loading indicies again and save gas
            // shares = assets * supply / balance
            assets.full_mul_div(supply, self.total_assets_internal(false))
        }


        /// Updates the interest rate model internally
        ///
        /// # Arguments
        /// * `base_rate` - The annualized base rate
        /// * `multiplier` - The annualized multiplier
        /// * `kink_multiplier` - The kink multiplier
        /// * `kink`
        fn interest_rate_model_internal(
            ref self: ContractState,
            base_rate: u256,
            multiplier: u256,
            kink_muliplier: u256,
            kink: u256
        ) {
            /// # Error
            /// * `INVALID_RANGE` - Avoid if not within range
            assert(base_rate < BASE_RATE_MAX, BorrowableErrors::INVALID_RANGE);
            assert(kink >= KINK_UTIL_MIN && kink <= KINK_UTIL_MAX, BorrowableErrors::INVALID_RANGE);
            assert(kink_muliplier <= KINK_MULTIPLIER_MAX, BorrowableErrors::INVALID_RANGE);

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

    /// TODO: Replace standard
    #[generate_trait]
    impl ERC20Impl of ERC20InternalTrait {
        /// After token transfer hook to track lender's CYG rewards.
        ///
        /// It is called during:
        /// `mint`
        /// `burn`
        /// `transfer`
        /// `transfer_from`
        ///
        /// # Arguments
        /// * `from` - The address of the CygUSD sender
        /// * `to` - The address of the CygUSD receiver
        /// * `amount` - The amount being transfered (not used)
        fn after_token_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            /// Track the CygUSD balance of `from` after the transfer
            if !from.is_zero() {
                self.track_lender(from);
            }

            /// Track the CygUSD balance of `to` after the transfer
            if !to.is_zero() {
                self.track_lender(to);
            }
        }

        // Transfer
        fn transfer_internal(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self.balances.write(sender, self.balances.read(sender) - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        // Approve
        fn approve_internal(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(!owner.is_zero(), 'ERC20: approve from 0');
            assert(!spender.is_zero(), 'ERC20: approve to 0');
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn spend_allowance_internal(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self.allowances.read((owner, spender));
            if current_allowance != integer::BoundedInt::max() {
                self.approve_internal(owner, spender, current_allowance - amount);
            }
        }

        // Mint
        fn mint_internal(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.total_supply.write(self.total_supply.read() + amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.after_token_transfer(Zeroable::zero(), recipient, amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        // Burn
        fn burn_internal(ref self: ContractState, account: ContractAddress, amount: u256) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self.total_supply.write(self.total_supply.read() - amount);
            self.balances.write(account, self.balances.read(account) - amount);
            self.after_token_transfer(account, Zeroable::zero(), amount);
            self.emit(Transfer { from: account, to: Zeroable::zero(), value: amount });
        }

        /// Increases allowance of spender
        fn increase_allowance_internal(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            let caller = get_caller_address();
            let new_allowance = self.allowances.read((caller, spender)) + added_value;
            self.approve_internal(caller, spender, new_allowance);

            true
        }

        /// Decreases allowance of spender
        fn decrease_allowance_internal(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            let caller = get_caller_address();
            let new_allowance = self.allowances.read((caller, spender)) - subtracted_value;
            self.approve_internal(caller, spender, new_allowance);

            true
        }
    }

    /// # Inlines
    #[generate_trait]
    impl UtilsImpl of UtilsInternalTrait {
        /// Previews our total balance in terms of the underlying without updating `total_balance`
        /// This is always the strategy's balance
        #[inline(always)]
        fn preview_balance(self: @ContractState) -> u256 {
            /// We deposit into zkLend via the zkMarket contract and receive zkUSDC 
            let zk_usdc = self.zk_usdc.read();

            /// zkUSDC rebases on each interest accrual, so our underlying balance is our zkUSDC balance
            zk_usdc.balanceOf(get_contract_address().into())
        }

        /// Guard for reentrancy
        #[inline(always)]
        fn lock(ref self: ContractState) {
            let status = self.guard.read();
            assert(!status, BorrowableErrors::REENTRANT_CALL);
            self.guard.write(true);
        }

        /// Guard for reentrancy
        #[inline(always)]
        fn unlock(ref self: ContractState) {
            self.guard.write(false);
        }

        /// Lock and update, used at the start of function
        #[inline(always)]
        fn lock_and_accrue(ref self: ContractState) {
            self.lock();
            self.accrue_interest_internal();
        }

        /// # Security
        /// * Checks that caller is admin
        fn check_admin(self: @ContractState) {
            // Get admin address from the hangar18
            let admin = self.hangar18.read().admin();

            /// # Error
            /// * `ONLY_ADMIN` - Reverts if sender is not hangar18 admin 
            assert(get_caller_address() == admin, BorrowableErrors::ONLY_ADMIN)
        }
    }
}
