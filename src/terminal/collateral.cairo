//! Collateral

// Deposit liquidity, borrow USD.
use starknet::ContractAddress;
use cygnus::data::calldata::{DeleverageCalldata};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};

/// Interface - Collateral
#[starknet::interface]
trait ICollateral<T> {
    /// ──────────────────────────────────── ERC20 ───────────────────────────────────────────

    /// # Returns
    /// * The name of the token (`Cygnus: Collateral`)
    fn name(self: @T) -> felt252;

    /// # Returns
    /// * The symbol of the token (`CygLP: ETH/DAI`)
    fn symbol(self: @T) -> felt252;

    /// # Returns
    /// * The decimals used (reads from underlying)
    fn decimals(self: @T) -> u8;

    /// # Returns
    /// * `account`'s balance of CygLP
    fn balance_of(self: @T, account: ContractAddress) -> u256;

    /// # Returns
    /// * The total supply of CygLP
    fn total_supply(self: @T) -> u256;

    /// # Returns
    /// * The allowance that `owner` has granted `spender`
    fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u256;

    /// Transfers CygLP from msg.sender to `recipient`
    fn transfer(ref self: T, recipient: ContractAddress, amount: u256) -> bool;

    /// Transfers CygLP from sender to `recipient`
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

    /// Total LPs we own
    ///
    /// # Returns
    /// The total LPs assets available in the pool
    fn total_assets(self: @T) -> u256;

    /// Total assets we own 
    ///
    /// # Returns
    /// The amount of LP tokens the vault owns
    fn total_balance(self: @T) -> u256;

    /// The exchange rate between CygLP and LP in 18 decimals
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

    /// Redeems CygLP for LP Tokens
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

    /// ─────────────────────────────────── 2. Control ───────────────────────────────────────

    /// # Returns
    /// * Minimum debt ratio allowed
    fn DEBT_RATIO_MIN(self: @T) -> u256;

    /// # Returns
    /// * Maximum debt ratio allowed
    fn DEBT_RATIO_MAX(self: @T) -> u256;

    /// # Returns
    /// * Maximum liquidation incentive allowed
    fn LIQUIDATION_INCENTIVE_MAX(self: @T) -> u256;

    /// # Returns
    /// * Minimum liquidation incentive allowed
    fn LIQUIDATION_INCENTIVE_MIN(self: @T) -> u256;

    /// # Returns
    /// * Maximum liquidation fee allowed
    fn LIQUIDATION_FEE_MAX(self: @T) -> u256;

    /// # Returns
    /// * Current pool's debt ratio
    fn debt_ratio(self: @T) -> u256;

    /// # Returns
    /// * Current pool's liquidation fee
    fn liquidation_fee(self: @T) -> u256;

    /// # Returns
    /// * Current pool's liquidation incentive
    fn liquidation_incentive(self: @T) -> u256;

    /// Sets liquidation fee 
    ///
    /// # Security 
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_liq_fee` - The new liquidation fee
    fn set_liquidation_fee(ref self: T, new_liq_fee: u256);

    /// Sets liquidation incentive
    ///
    /// # Security 
    /// * Only-admin
    ///
    /// # Arguments
    /// * `incentive` - The new liquidation incentive
    fn set_liquidation_incentive(ref self: T, new_incentive: u256);

    /// Sets a new debt ratio
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_ratio` - The new debt ratio
    fn set_debt_ratio(ref self: T, new_ratio: u256);

    /// Sets the borrowable during deployment. Can only be set once (does address zero check).
    ///
    /// # Arguments
    /// * `borrowable` - The address of the borrowable
    fn set_borrowable(ref self: T, borrowable: IBorrowableDispatcher);

    /// ─────────────────────────────────── 3. Model ─────────────────────────────────────────

    /// Checks whether a borrower can borrow a certain amount, used by the borrowable contract
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// * `borrowed_amount` - The amount to borrow
    ///
    /// # Returns 
    /// * Whether or not `borrower` can borrow `borrowed_amount`
    fn can_borrow(self: @T, borrower: ContractAddress, borrowed_amount: u256) -> bool;

    /// Checks whether or not a borrower can redeem a certain amount of CygLP
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// * `amount` - The amount of CygLP to redeem
    ///
    /// # Returns
    /// * Whether or not the borrower can withdraw 'amount' of CygLP. If false then it means withdrawing
    ///   this amount of CygLP would put user in shortfall and withdrawing this would cause the tx to revert
    fn can_redeem(self: @T, borrower: ContractAddress, amount: u256) -> bool;

    /// Checks a borrower's current liquidity and shortfall. 
    /// 
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// 
    /// # Returns
    /// * The maximum amount of USDC that the `borrower` can borrow (if shortfall then this == 0)
    /// * The current shortfall of USDC (if liquidity then this == 0)
    fn get_account_liquidity(self: @T, borrower: ContractAddress) -> (u256, u256);

    /// # Returns
    /// * The price of the underlying LP Token, denominated in the borrowable`s underlying
    fn get_lp_token_price(self: @T) -> u256;

    /// Quick check to see borrower`s position
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    ///
    /// # Returns
    fn get_borrower_position(self: @T, borrower: ContractAddress) -> (u256, u256, u256, u256);

    /// ─────────────────────────────────── 4. Collateral ────────────────────────────────────

    /// Seizes an amount of CygLP from the borrower and transfers it to the liquidator.
    /// Not marked as non-reentrant as only borrowable can call through the non-reentrant `liquidate`
    ///
    /// # Security
    /// * Only-borrowable
    ///
    /// # Arguments
    /// * `liquidator` - The address of the liquidator
    /// * `borrower` - The address of the borrower
    /// * `repay_amount` - The amount of USDC repaid by the liquidator
    ///
    /// # Returns
    /// * The amount of CygLP seized
    fn seize_cyg_lp(
        ref self: T, liquidator: ContractAddress, borrower: ContractAddress, repay_amount: u256
    ) -> u256;

    /// Allows users to flash redeem LP from the contract,  as long as we receive the equivalent of the LPs in CygLP
    /// This function should be called from a periphery contract only
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `redeemer` - The address of the redeemer
    /// * `assets` - The amount of LP assets being redeemed
    /// * `calldata` - Deleverage calldata (can be empty, used by router)
    fn flash_redeem(
        ref self: T, redeemer: ContractAddress, assets: u256, calldata: DeleverageCalldata
    ) -> u256;
}

#[starknet::contract]
mod Collateral {
    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ══════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::ICollateral;
    use cygnus::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};

    use cygnus::token::erc20::univ2pair::{IUniV2PairDispatcher, IUniV2PairDispatcherTrait};

    /// # Libraries
    use cygnus::libraries::full_math_lib::FixedPointMathLib::FixedPointMathLibTrait;
    use integer::BoundedInt;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    /// # Errors
    use cygnus::terminal::errors::CollateralErrors;

    /// # Data
    use cygnus::data::calldata::{DeleverageCalldata};

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ══════════════════════════════════════════════════════════════════════════════════════

    /// # Events
    /// * `Transfer` - Logs when CygLP is transferred
    /// * `Approval` - Logs when user approves a spender to spend their CygLP
    /// * `SyncBalance` - Logs when `total_balance` is synced with underlying's balance_of
    /// * `Deposit` - Logs when a user deposits LP and receives CygLP
    /// * `Withdraw` - Logs when a user redeems CygLP and receives LP
    /// * `NewLiquidationFee` - Logs when admin sets a new liq. fee
    /// * `NewLiqIncentive` - Logs when admin sets a new liq. incentive
    /// * `NewDebtRatio` - Logs when admin sets a new pool debt ratio
    /// * `Seize` - Logs when a liquidator seizes CygLP from a borrower
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        SyncBalance: SyncBalance,
        Deposit: Deposit,
        Withdraw: Withdraw,
        NewLiquidationFee: NewLiquidationFee,
        NewLiquidationIncentive: NewLiquidationIncentive,
        NewDebtRatio: NewDebtRatio,
        Seize: Seize
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

    // SyncBalance
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


    /// NewLiquidationFee
    #[derive(Drop, starknet::Event)]
    struct NewLiquidationFee {
        old_liq_fee: u256,
        new_liq_fee: u256
    }

    /// NewLiqIncentive
    #[derive(Drop, starknet::Event)]
    struct NewLiquidationIncentive {
        old_incentive: u256,
        new_incentive: u256
    }


    /// NewDebtRatio
    #[derive(Drop, starknet::Event)]
    struct NewDebtRatio {
        old_ratio: u256,
        new_ratio: u256
    }

    /// Seize
    #[derive(Drop, starknet::Event)]
    struct Seize {
        liquidator: ContractAddress,
        borrower: ContractAddress,
        cyg_lp_amount: u256
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ══════════════════════════════════════════════════════════════════════════════════════

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
        total_supply: u256,
        /// Mapping of user => CygLP balance
        balances: LegacyMap<ContractAddress, u256>,
        /// Mapping of (owner, spender) => allowance
        allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        /// Opposite arm (ie. borrowable)
        twin_star: IBorrowableDispatcher,
        /// The address of the factory
        hangar18: IHangar18Dispatcher,
        /// The address of the underlying asset (ie an LP Token)
        underlying: IUniV2PairDispatcher,
        /// The address of the oracle for this lending pool
        nebula: ICygnusNebulaDispatcher,
        /// The lending pool ID (shared by the borrowable)
        shuttle_id: u32,
        /// The current debt ratio for this pool
        debt_ratio: u256,
        /// The current liquidation incentive
        liq_incentive: u256,
        /// The current liquidation fee
        liq_fee: u256,
    }

    /// The lowest possible liquidation profit, which liquidators receive (0%)
    const LIQ_INCENTIVE_MIN: u256 = 1_000000000_000000000_u256;

    /// The highest possible liquidation profit, which liquidators receive (20%)
    const LIQ_INCENTIVE_MAX: u256 = 1_200000000_000000000_u256;

    /// The max possible liquidation fee, which the protocol seizes from the borrower (10%)
    const LIQ_FEE_MAX: u256 = 100000000_000000000_u256;

    /// The minimum possible debt ratio (LTV) for this lending pool (70%)
    const DEBT_RATIO_MIN: u256 = 700000000_000000000_u256;

    /// The maximum possible debt ratio (LTV) for this lending pool (95%)
    const DEBT_RATIO_MAX: u256 = 950000000_000000000_u256;

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(
        ref self: ContractState,
        hangar18: IHangar18Dispatcher,
        underlying: IUniV2PairDispatcher,
        borrowable: IBorrowableDispatcher,
        oracle: ICygnusNebulaDispatcher,
        shuttle_id: u32
    ) {
        self.initialize_internal(hangar18, underlying, borrowable, oracle, shuttle_id);
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[external(v0)]
    impl CollateralImpl of ICollateral<ContractState> {
        /// # Implementation
        /// * ICollateral
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        /// # Implementation
        /// * ICollateral
        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        /// # Implementation
        /// * ICollateral
        fn decimals(self: @ContractState) -> u8 {
            self.underlying.read().decimals()
        }

        /// # Implementation
        /// * ICollateral
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        /// # Implementation
        /// * ICollateral
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        /// # Implementation
        /// * ICollateral
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        /// # Implementation
        /// * ICollateral
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            // Get sender
            let sender = get_caller_address();

            // Hook to check if user has enough liquidity to transfer this amount
            self.before_token_transfer(sender, recipient, amount);

            // Transfer internal
            self.transfer_internal(sender, recipient, amount);

            true
        }

        /// # Implementation
        /// * ICollateral
        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            // Get sender
            let caller = get_caller_address();

            // Hook to check if user has enough liquidity to transfer this amount
            self.before_token_transfer(sender, recipient, amount);

            // Check allowance
            self.spend_allowance_internal(sender, caller, amount);

            // Transfer internal
            self.transfer_internal(sender, recipient, amount);

            true
        }

        /// # Implementation
        /// * ICollateral
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self.approve_internal(caller, spender, amount);
            true
        }

        /// # Implementation
        /// * ICollateral
        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            self.increase_allowance_internal(spender, added_value)
        }

        /// # Implementation
        /// * ICollateral
        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            self.decrease_allowance_internal(spender, subtracted_value)
        }

        /// ───────────────────────────────── 1. Terminal ────────────────────────────────────

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
        fn total_assets(self: @ContractState) -> u256 {
            self.preview_balance()
        }

        /// # Implementation
        /// * ICollateral
        fn total_balance(self: @ContractState) -> u256 {
            self.preview_balance()
        }

        /// # Implementation
        /// * ICollateral
        fn exchange_rate(self: @ContractState) -> u256 {
            // Gas savings
            let supply = self.total_supply.read();

            // 1-to-1
            if supply == 0 {
                return 1_000000000_000000000;
            }

            // Assets / Supply
            self.total_assets().div_wad(supply)
        }

        /// Transfers LP from caller and mints them shares. Deposits all LP into
        /// rewarder.
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * ICollateral
        fn deposit(ref self: ContractState, assets: u256, recipient: ContractAddress) -> u256 {
            /// Lock reentrant guard and accrue interest
            self.lock();

            /// Convert assets to shares
            let shares = self.convert_to_shares(assets);

            /// # Error
            /// * `CANT_MINT_ZERO` - Reverts if minting 0 shares
            assert(shares > 0, CollateralErrors::CANT_MINT_ZERO);

            /// Get caller address
            let caller = get_caller_address();

            /// Transfer LP to collateral
            let receiver = get_contract_address();
            self.underlying.read().transferFrom(caller.into(), receiver.into(), assets);

            /// Mint CygLP
            self.mint_internal(recipient, shares);

            /// Deposit LP in strategy
            self.after_deposit(assets);

            /// # Event
            /// * Deposit
            self.emit(Deposit { caller, recipient, assets, shares });

            /// Unlock reentrant guard
            self.unlock();

            shares
        }

        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * ICollateral
        fn redeem(
            ref self: ContractState,
            shares: u256,
            recipient: ContractAddress,
            owner: ContractAddress
        ) -> u256 {
            /// Lock
            self.lock();

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
            assert(assets != 0, CollateralErrors::CANT_REDEEM_ZERO);

            /// Withdraw from strategy
            self.before_withdraw(assets);

            // Burn CygLP and transfer Lp
            self.burn_internal(owner, shares);

            /// Transfer LP to recipient
            self.underlying.read().transfer(recipient.into(), assets.into());

            /// # Event
            /// * Withdraw
            self.emit(Withdraw { caller, recipient, owner, assets, shares });

            // Unlock and update state
            self.unlock();

            assets
        }

        /// ───────────────────────────────── 2. Control ─────────────────────────────────────

        /// # Security
        /// * Can only be set once
        ///
        /// # Implementation
        /// * ICollateral
        fn set_borrowable(ref self: ContractState, borrowable: IBorrowableDispatcher) {
            /// # Error
            /// * ALREADY_SET
            assert(self.twin_star.read().contract_address.is_zero(), 'already_set');

            /// Write borrowable to storage, cannot be set again
            self.twin_star.write(borrowable);
        }

        /// # Implementation
        /// * ICollateral
        fn LIQUIDATION_INCENTIVE_MIN(self: @ContractState) -> u256 {
            LIQ_INCENTIVE_MIN
        }

        /// # Implementation
        /// * ICollateral
        fn LIQUIDATION_INCENTIVE_MAX(self: @ContractState) -> u256 {
            LIQ_INCENTIVE_MAX
        }

        /// # Implementation
        /// * ICollateral
        fn DEBT_RATIO_MIN(self: @ContractState) -> u256 {
            DEBT_RATIO_MIN
        }

        /// # Implementation
        /// * ICollateral
        fn DEBT_RATIO_MAX(self: @ContractState) -> u256 {
            DEBT_RATIO_MAX
        }

        /// # Implementation
        /// * ICollateral
        fn LIQUIDATION_FEE_MAX(self: @ContractState) -> u256 {
            LIQ_FEE_MAX
        }

        /// # Implementation
        /// * ICollateral
        fn debt_ratio(self: @ContractState) -> u256 {
            self.debt_ratio.read()
        }

        /// # Implementation
        /// * ICollateral
        fn liquidation_incentive(self: @ContractState) -> u256 {
            self.liq_incentive.read()
        }

        /// # Implementation
        /// * ICollateral
        fn liquidation_fee(self: @ContractState) -> u256 {
            self.liq_fee.read()
        }

        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * ICollateral
        fn set_liquidation_fee(ref self: ContractState, new_liq_fee: u256) {
            // Check caller is admin
            self.check_admin();

            /// # Error
            /// * `Invalid Range`
            assert(new_liq_fee >= 0 && new_liq_fee <= LIQ_FEE_MAX, CollateralErrors::INVALID_RANGE);

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
        fn set_liquidation_incentive(ref self: ContractState, new_incentive: u256) {
            // Check caller is admin
            self.check_admin();

            /// # Error
            /// * `Invalid Range`
            assert(
                new_incentive >= LIQ_INCENTIVE_MIN && new_incentive <= LIQ_INCENTIVE_MAX,
                CollateralErrors::INVALID_RANGE
            );

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
        fn set_debt_ratio(ref self: ContractState, new_ratio: u256) {
            // Check caller is admin
            self.check_admin();

            /// # Error
            /// * `Invalid Range`
            assert(
                new_ratio >= DEBT_RATIO_MIN && new_ratio <= DEBT_RATIO_MAX,
                CollateralErrors::INVALID_RANGE
            );

            // Old debt ratio
            let old_ratio = self.debt_ratio.read();

            // Assign new debt ratio
            self.debt_ratio.write(new_ratio);

            /// # Emit
            /// * `NewDebtRatio`
            self.emit(NewDebtRatio { old_ratio, new_ratio });
        }

        /// ───────────────────────────────── 3. Model ───────────────────────────────────────

        /// # Implementation
        /// * ICollateral
        fn can_borrow(
            self: @ContractState, borrower: ContractAddress, borrowed_amount: u256
        ) -> bool {
            // Get shortfall
            let (_, shortfall) = self.account_liquidity_internal(borrower, borrowed_amount);

            // Returns true if borroing `borrowed_amount` would not put user in shortfall
            shortfall == 0
        }

        /// # Implementation
        /// * ICollateral
        fn get_account_liquidity(self: @ContractState, borrower: ContractAddress) -> (u256, u256) {
            /// Get the user's liquidity or shortfall
            self.account_liquidity_internal(borrower, BoundedInt::max())
        }

        /// # Implementation
        /// * ICollateral
        fn get_lp_token_price(self: @ContractState) -> u256 {
            // Get the lp Price
            self.get_price_internal()
        }

        /// # Implementation
        /// * ICollateral
        fn can_redeem(self: @ContractState, borrower: ContractAddress, amount: u256) -> bool {
            /// Get the CygLP balance of the borrower
            let balance = self.balances.read(borrower);

            if (amount > balance || amount == 0) {
                return false;
            }

            // Never underflows
            let final_balance = balance - amount;

            // Get the amount of LPs the borrower currently would have access to from the vault
            // after withdrawing `amount` 
            let lp_amount = self.convert_to_assets(final_balance);

            // Get borrower`s latest borrow balance (with interests)
            let borrowable = self.twin_star.read();
            let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);

            // Given the current borrow balance and the lp amount, get the collateral needed
            let (_, shortfall) = self.collateral_needed_internal(lp_amount, borrow_balance);

            // Ensure shortfall is 0
            shortfall == 0
        }

        /// This is a quick view function to get the current health of the borrower and position.
        /// Not used by any important functions.
        ///
        /// # Implementation
        /// * ICollateral
        fn get_borrower_position(
            self: @ContractState, borrower: ContractAddress
        ) -> (u256, u256, u256, u256) {
            /// Get borrowable
            let borrowable = self.twin_star.read();

            /// Get CygLP Balance
            let cyg_lp_balance = self.balances.read(borrower);

            /// 1. Principal 
            /// 2. Borrow balance
            let (principal, borrow_balance) = borrowable.get_borrow_balance(borrower);

            /// 3. The borrower's position in USD: cyg_lp_balance * exchange_rate * price
            let lp_amount = self.convert_to_assets(cyg_lp_balance); // Convert cygLP to LP

            /// Get the price of 1 unit of the LP
            let price = self.get_price_internal();

            /// position_usd = lp_balance * lp_price
            let position_usd = lp_amount.mul_wad(price); // LP Balance * Price

            /// 4. Health - If the position is 0, then user has no CygLP and thus no borrows.
            /// Positon health: borrow_balance / ((position_usd * debt_ratio) / liq_penalty)
            /// Avoid divide by 0
            if position_usd == 0 {
                return (0, 0, 0, 0);
            }

            /// Calculate denominator = position_usd * debt_ratio / liq_penalty
            let debt_ratio = self.debt_ratio.read();
            let liq_penalty = self.liq_incentive.read() + self.liq_fee.read();
            let denominator = position_usd.full_mul_div(debt_ratio, liq_penalty);

            /// User's current health
            let health = borrow_balance.div_wad(denominator);

            (principal, borrow_balance, position_usd, health)
        }

        /// ───────────────────────────────── 4. Collateral ──────────────────────────────────

        /// Only borrowable can call through the non-reentrant `liquidate`
        ///
        /// # Implementation
        /// * ICollateral
        fn seize_cyg_lp(
            ref self: ContractState,
            liquidator: ContractAddress,
            borrower: ContractAddress,
            repay_amount: u256
        ) -> u256 {
            // Get sender
            let sender = get_caller_address();

            /// # Error
            /// * `SENDER_NOT_BORROWABLE` - Revert if not called by the borrowable contract
            assert(
                sender == self.twin_star.read().contract_address,
                CollateralErrors::SENDER_NOT_BORROWABLE
            );

            /// # Error
            /// * `CANT_SEIZE_ZERO` - Revert if repay amount is 0
            assert(repay_amount > 0, CollateralErrors::CANT_SEIZE_ZERO);

            /// Assert user is liquidatable
            let (_, shortfall) = self.account_liquidity_internal(borrower, BoundedInt::max());

            /// # Error
            /// * `NOT_LIQUIDATABLE` - Revert if position is not in shortfall
            assert(shortfall > 0, CollateralErrors::NOT_LIQUIDATABLE);

            /// Liquidator receives the equivalent of the USDC repaid + liq. incentive in LP Tokens::
            /// (repaid amount * liquidation incentive) / LP token price
            let lp_token_price = self.get_lp_token_price();
            let liq_incentive = self.liq_incentive.read();
            let lp_amount = repay_amount.full_mul_div(liq_incentive, lp_token_price);

            /// Convert seized LPs to CygLP to seize shares
            let cyg_lp_amount = self.convert_to_shares(lp_amount);

            /// Transfer CygLP to the liquidator
            self.transfer_internal(borrower, liquidator, cyg_lp_amount);

            // Check for DAO fee (seized from the borrower, not the liquidator)
            let liq_fee = self.liq_fee.read();

            if liq_fee > 0 {
                // Get the liquidation fee from the total seized
                let dao_fee = cyg_lp_amount.mul_wad(liq_fee);

                /// Liquidation fees are transfered to dao reserves
                let dao_reserves = self.hangar18.read().dao_reserves();

                /// Seize CygLP from borrower to dao reserves
                self.transfer_internal(borrower, dao_reserves, dao_fee);
            }

            /// Emit
            self.emit(Seize { liquidator, borrower, cyg_lp_amount });

            /// Return amount seized
            cyg_lp_amount
        }

        /// TODO: Redeem calldata
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * ICollateral
        fn flash_redeem(
            ref self: ContractState,
            redeemer: ContractAddress,
            assets: u256,
            calldata: DeleverageCalldata
        ) -> u256 {
            /// Lock and update to avoid skim
            self.lock();

            /// # Error
            /// * `CANT_REDEEM_ZERO` - Avoid redeeming 0 assets
            assert(assets > 0, CollateralErrors::CANT_REDEEM_ZERO);

            /// 1. Convert assets redeemed to shares, rounding up
            /// We convert manually since `convert_to_shares` rounds down
            let shares = assets.full_mul_div_up(self.total_supply.read(), self.preview_balance());

            /// 2. Withdraw from strategy
            self.before_withdraw(assets);

            /// 3. Transfer LP to redeemer
            self.underlying.read().transfer(redeemer.into(), assets);

            /// Get sender
            /// let caller = get_caller_address();

            /// 4. Get shares received and revert if received less than the equivalent of assets
            let cyg_lp_received = self.balances.read(get_contract_address());

            /// # Error
            /// * `INSUFFICIENT_CYG_LP_RECEIVED`
            assert(cyg_lp_received >= shares, CollateralErrors::INSUFFICIENT_CYG_LP_RECEIVED);

            /// Burn shares and emit event
            self.burn_internal(get_contract_address(), assets);

            // Unlock and update state
            self.unlock();

            /// TODO: This should be usd amount
            shares
        }
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    //      6. INTERNAL LOGIC
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[generate_trait]
    impl VoidImpl of VoidImplTrait {
        /// Initialize Strategy
        fn initialize_void(ref self: ContractState) { /// Max approve masterchef
        /// self.underlying.read().approve(zk_market.into(), BoundedInt::max());
        }

        /// Deposit into ZK Lend
        ///
        /// # Arguments
        /// * `amount` - The amount of USDC to deposit into the zkLend market
        fn after_deposit(ref self: ContractState, amount: u256) { /// Deposit into MasterChef
        }

        /// Withdraw from ZK Lend
        ///
        /// # Arguments
        /// * `amount` - The amount of USDC to withdraw from the zkLend market
        fn before_withdraw(ref self: ContractState, amount: u256) { /// Withdraw from MasterChef
        }
    /// Get the balance of LP currently in this contract
    /// fn check_balance(self: @ContractState, token: IERC20Dispatcher) -> u256 {}
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initialize_internal(
            ref self: ContractState,
            hangar18: IHangar18Dispatcher,
            underlying: IUniV2PairDispatcher,
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
            self.set_default_collateral();
        }

        /// Sets the default collateral values (the debt ratio, liq. incentive & liq. fee)
        /// Called only in the constructor
        fn set_default_collateral(ref self: ContractState) {
            // Name and symbol
            self.name.write('Cygnus: Collateral');
            self.symbol.write('CygLP');

            /// 90% is the default in all pools
            self.debt_ratio.write(900000000000000000);

            /// 3% liquidation profit for liquidators
            self.liq_incentive.write(1030000000000000000);

            /// 1% Liquidation fee which the protocol keeps
            self.liq_fee.write(10000000000000000);

            /// Initialize strategy
            self.initialize_void();
        }

        /// Convert to assets
        fn convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            let supply = self.total_supply.read();

            // If no supply return shares 
            if supply == 0 {
                return shares;
            }

            // else asset = (shares * balance) / total supply
            shares.full_mul_div(self.total_assets(), supply)
        }

        /// Convert to shares
        fn convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            let supply = self.total_supply.read();

            // If no supply return assets
            if supply == 0 {
                return assets;
            }

            // Else shares = (assets * supply) / balance
            assets.full_mul_div(supply, self.total_assets())
        }

        /// Collateral needed internal
        fn collateral_needed_internal(
            self: @ContractState, lp_token_amount: u256, borrowed_amount: u256
        ) -> (u256, u256) {
            // LP Price
            let price = self.get_price_internal();

            // LP amount * LP Price
            let collateral_usd = lp_token_amount.mul_wad(price);

            // Debt ratio and liquidation penalty
            let debt_ratio = self.debt_ratio.read();
            let liq_penalty = self.liq_incentive.read() + self.liq_fee.read();

            // User's max liquidity
            let max_liquidity = collateral_usd.full_mul_div(debt_ratio, liq_penalty);

            // Return liquidity and shortfall
            if max_liquidity >= borrowed_amount {
                (max_liquidity - borrowed_amount, 0)
            } else {
                (0, borrowed_amount - max_liquidity)
            }
        }

        /// Gets the price of the LP token from the stored oracle for this pool
        ///
        /// # Returns
        /// * The price of the LP denominated in the borrowable's underlying (a stablecoin)
        fn get_price_internal(self: @ContractState) -> u256 {
            10_000_000
        ///            /// LP address
        ///            let lp_token_address = self.underlying.read().contract_address;
        ///
        ///            // Get LP Price
        ///            let price = self.nebula.read().lp_token_price(lp_token_address);
        ///
        ///            /// # Error
        ///            /// * `INVALID_PRICE` - Reverts if price is 0
        ///            assert(price >= 0, INVALID_PRICE);
        ///
        ///            price
        }

        /// Account liquidity internal
        fn account_liquidity_internal(
            self: @ContractState, borrower: ContractAddress, mut borrowed_amount: u256
        ) -> (u256, u256) {
            /// # Error
            /// * `BORROWER_ZERO_ADDRESS` - Revert if the borrower is the zero address
            assert(!borrower.is_zero(), CollateralErrors::BORROWER_ZERO_ADDRESS);

            /// # Error
            /// * `BORROWER_COLLATERAL_ADDRESS` - Reverts if the borrower is this contract
            assert(
                borrower != get_contract_address(), CollateralErrors::BORROWER_COLLATERAL_ADDRESS
            );

            /// We check for the borrow amount passed. This is because this same function
            /// can be called by anyone via the external `get_account_liquidity` which passes the 
            /// max bounded int, but it is / also called by the borrowable during borrows
            /// which passes the current borrows of the user
            if borrowed_amount == BoundedInt::max() {
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
            let lp_token_amount = self.convert_to_assets(balance);

            // Return the collateral needed given the user's lp token amount, and the borrow amount
            self.collateral_needed_internal(lp_token_amount, borrowed_amount)
        }
    }

    #[generate_trait]
    impl ERC20Impl of ERC20InternalTrait {
        /// Before transfer hook to lock collateral tokens in case of insufficient liquidity to transfer.
        ///
        /// It is called during:
        /// - `burn`
        /// - `transfer`
        /// - `transfer_from`
        ///
        /// If moving tokens (transfer/redeems) we revert if moving this amount would put the user in shortfall.
        /// 
        /// # Arguments
        /// * `from` - The sender of CygLP
        /// * `to` - The receiver of CygLP
        /// * `amount` - Amount being transfered
        fn before_token_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            // Escape in case of `flashRedeemAltair()`
            // 1. This contract should never have CygLP outside of flash redeeming. If a user is flash redeeming it requires them
            // to `transfer` or `transfer_from` to this address first, and it will check `can_redeem` before transfer.
            if from == get_contract_address() {
                return;
            }

            /// # Error
            /// * `INSUFFICIENT_LIQUIDITY` - Reverts if withdrawing/transferring this amount would put the user in shortfall
            assert(self.can_redeem(from, amount), CollateralErrors::INSUFFICIENT_LIQUIDITY);
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
            if current_allowance != BoundedInt::max() {
                self.approve_internal(owner, spender, current_allowance - amount);
            }
        }

        // Mint
        fn mint_internal(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.total_supply.write(self.total_supply.read() + amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        /// # Security
        /// * `before_token_transfer` - Checks to see if borrower has enough liquidity to transfer
        fn burn_internal(ref self: ContractState, account: ContractAddress, amount: u256) {
            assert(!account.is_zero(), 'ERC20: burn from 0');

            /// Hook to check liquidity
            self.before_token_transfer(account, Zeroable::zero(), amount);

            self.total_supply.write(self.total_supply.read() - amount);
            self.balances.write(account, self.balances.read(account) - amount);
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

    /// Inlines
    #[generate_trait]
    impl UtilsImpl of UtilsInternalTrait {
        // Reentrancy guard - lock
        #[inline(always)]
        fn lock(ref self: ContractState) {
            let status = self.guard.read();
            assert(!status, CollateralErrors::REENTRANT_CALL);
            self.guard.write(true);
        }

        // Reentrancy guard - unlock
        #[inline(always)]
        fn unlock(ref self: ContractState) {
            self.guard.write(false);
        }

        /// TODO  masterchef
        /// Previews our total balance in terms of the underlying without updating `total_balance`
        #[inline(always)]
        fn preview_balance(self: @ContractState) -> u256 {
            let contract_address = get_contract_address();
            self.underlying.read().balanceOf(contract_address.into())
        }

        /// Admin
        fn check_admin(self: @ContractState) {
            // Get admin address from the hangar18
            let admin = self.hangar18.read().admin();

            /// # Error
            /// * `ONLY_ADMIN` - Reverts if sender is not hangar18 admin 
            assert(get_caller_address() == admin, CollateralErrors::ONLY_ADMIN)
        }
    }
}
