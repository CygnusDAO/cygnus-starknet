//! Periphery

// Libraries
use starknet::ContractAddress;
use cygnus::data::altair::{ShuttleInfoC, ShuttleInfoB};

/// # Interface - Altair
#[starknet::interface]
trait IAltair<TContractState> {
    /// ───────────────────────────── CONSTANT FUNCTIONS ───────────────────────────── ///

    /// # Returns
    /// * Name of the router (`Altair`)
    fn name(self: @TContractState) -> felt252;

    /// # Returns
    /// * The address of the current admin, the pool/orbiter deployer
    fn admin(self: @TContractState) -> ContractAddress;

    fn get_shuttle_info_by_id(
        self: @TContractState, shuttle_id: u32
    ) -> (ShuttleInfoC, ShuttleInfoB);

    /// # Returns
    /// * The address of hangar18 on Starknet
    fn hangar18(self: @TContractState) -> ContractAddress;

    /// # Returns
    /// * The address of USD
    fn usd(self: @TContractState) -> ContractAddress;

    /// # Returns
    /// * The address of native token (ie WETH)
    fn native_token(self: @TContractState) -> ContractAddress;

    /// # Arguments
    /// * `extension_id` - The ID of an extension
    ///
    /// # Returns
    /// * The extension address
    fn all_extensions(self: @TContractState, extension_id: u32) -> ContractAddress;

    /// # Arguments
    /// * `cygnus_vault` - The address of a borrowable, collateral or lp token address
    ///
    /// # Returns
    /// * The extension address
    fn get_extension(self: @TContractState, cygnus_vault: ContractAddress) -> ContractAddress;

    /// # Returns
    /// * The total amount of extensions we have initialized
    fn all_extensions_length(self: @TContractState) -> u32;

    /// # Arguments
    /// * `shuttle_id` - Unique lending pool ID
    ///
    /// # Returns
    /// * The extension that is currently being used for a lending pool id
    fn get_shuttle_extension(self: @TContractState, shuttle_id: u32) -> ContractAddress;

    /// # Arguments
    /// * `extension` - The address of the periphery extension
    ///
    /// # Returns
    /// * Whether the `extension` has been added to this contract or not
    fn is_extension(self: @TContractState, extension: ContractAddress) -> bool;

    /// ─────────────────────────── NON-CONSTANT FUNCTIONS ─────────────────────────── ///

    /// Main borrow function TODO: Implement permit calldata?
    ///
    /// # Arguments
    /// * `borrowable` - The address of a Cygnus borrowable
    /// * `amount` - The amount of USD to borrow
    /// * `recipient` - The address of the recipient of the loan
    /// * `deadline` - The maximum timestamp allowed for tx to succeed
    fn borrow(
        ref self: TContractState,
        borrowable: ContractAddress,
        borrow_amount: u256,
        recipient: ContractAddress,
        deadline: u64
    );

    /// Main repay function TODO: Implement permit calldata?
    ///
    /// # Arguments
    /// * `borrowable` - The address of a Cygnus borrowable
    /// * `repay_amount` - The amount of USD to repay
    /// * `borrower` - The address of the borrower whose loan we are repaying
    /// * `deadline` - The maximum timestamp allowed for tx to succeed
    fn repay(
        ref self: TContractState,
        borrowable: ContractAddress,
        repay_amount: u256,
        borrower: ContractAddress,
        deadline: u64
    );

    /// Main liquidate function to repay a loan and seize CygLP
    ///
    /// # Arguments
    /// * `borrowable` - The address of a Cygnus borrowable
    /// * `repay_amount` - The amount of USD to repay
    /// * `borrower` - The address of the borrower whose loan we are repaying
    /// * `recipient` - The address of the recipient of the CygLP
    /// * `deadline` - The maximum timestamp allowed for tx to succeed
    ///
    /// # Returns
    /// * The total amount of USD repaid
    /// * The total amount of CygLP seized from the borrower and received
    fn liquidate(
        ref self: TContractState,
        borrowable: ContractAddress,
        repay_amount: u256,
        borrower: ContractAddress,
        recipient: ContractAddress,
        deadline: u64
    ) -> (u256, u256);

    fn set_altair_extension(ref self: TContractState, shuttle_id: u32, extension: ContractAddress);
}


// const owner: felt252 = selector!("owner");

/// # Module - Altair
#[starknet::contract]
mod Altair {
    /// ══════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ══════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::IAltair;
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};

    /// # Libraries
    use cygnus::libraries::full_math_lib::FixedPointMathLib::FixedPointMathLibTrait;
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, library_call_syscall,
        get_block_timestamp
    };

    /// # Errors
    use cygnus::periphery::errors::AltairErrors::{
        CALLER_NOT_ADMIN, TRANSACTION_EXPIRED, SHUTTLE_NOT_DEPLOYED
    };

    /// # Data
    use cygnus::data::shuttle::{Shuttle};
    use cygnus::data::calldata::{LeverageCalldata, DeleverageCalldata, LiquidateCalldata};
    use cygnus::data::altair::{ShuttleInfoC, ShuttleInfoB};

    /// ══════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ══════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Name of the router
        name: felt252,
        /// Current admin, the only one capable of deploying pools
        admin: ContractAddress,
        /// Pending Admin, the address of the new pending admin
        usd: IERC20Dispatcher,
        /// ie WETH
        native_token: IERC20Dispatcher,
        /// Version
        version: felt252,
        /// Factory
        hangar18: IHangar18Dispatcher,
        /// Total extensions initialized
        total_extensions: u32,
        /// Extensions
        extensions: LegacyMap<ContractAddress, ContractAddress>,
        /// Array of extensions
        all_extensions: LegacyMap<u32, ContractAddress>,
        /// Mapping to check if extension exists
        is_extension: LegacyMap<ContractAddress, bool>
    }

    /// ══════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ══════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, hangar18: IHangar18Dispatcher) {
        // Get native and usd from factory
        let native_token = IERC20Dispatcher { contract_address: hangar18.native_token() };
        let usd = IERC20Dispatcher { contract_address: hangar18.usd() };

        /// Store factory and dispatchers
        self.hangar18.write(hangar18);
        self.usd.write(usd);
        self.native_token.write(native_token);

        /// Current altair version
        self.version.write('1.0.0');
    }

    /// ══════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ══════════════════════════════════════════════════════════════════════════════════

    #[external(v0)]
    impl AltairImpl of IAltair<ContractState> {
        /// # Implementation
        /// * IAltair
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        /// # Implementation
        /// * IAltair
        fn admin(self: @ContractState) -> ContractAddress {
            self.hangar18.read().admin()
        }

        /// # Implementation
        /// * IAltair
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * IAltair
        fn usd(self: @ContractState) -> ContractAddress {
            self.usd.read().contract_address
        }

        /// # Implementation
        /// * IAltair
        fn native_token(self: @ContractState) -> ContractAddress {
            self.native_token.read().contract_address
        }

        /// # Implementation
        /// * IAltair
        fn get_extension(self: @ContractState, cygnus_vault: ContractAddress) -> ContractAddress {
            self.extensions.read(cygnus_vault)
        }

        /// # Implementation
        /// * IAltair
        fn all_extensions(self: @ContractState, extension_id: u32) -> ContractAddress {
            self.all_extensions.read(extension_id)
        }

        /// # Implementation
        /// * IAltair
        fn all_extensions_length(self: @ContractState) -> u32 {
            self.total_extensions.read()
        }

        /// # Implementation
        /// * IAltair
        fn get_shuttle_extension(self: @ContractState, shuttle_id: u32) -> ContractAddress {
            // Get the shuttle from the factory to read collateral or borrowable, 
            let shuttle: Shuttle = self.hangar18.read().all_shuttles(shuttle_id);

            /// Return the extension (borrowable, collateral and LP token share extension)
            self.extensions.read(shuttle.collateral.contract_address)
        }

        /// # Implementation
        /// * IAltair
        fn is_extension(self: @ContractState, extension: ContractAddress) -> bool {
            self.is_extension.read(extension)
        }

        /// Quick view function to get a shuttle's info, not used by this contract
        ///
        /// # Implementation
        /// * IAltair
        fn get_shuttle_info_by_id(
            self: @ContractState, shuttle_id: u32
        ) -> (ShuttleInfoC, ShuttleInfoB) {
            let shuttle = self.hangar18.read().all_shuttles(shuttle_id);
            let collateral = shuttle.collateral;
            let borrowable = shuttle.borrowable;

            let shuttleC = ShuttleInfoC {
                shuttle_id: shuttle_id,
                total_supply: collateral.total_supply(),
                total_balance: collateral.total_balance(),
                total_assets: collateral.total_assets(),
                exchange_rate: collateral.exchange_rate(),
                debt_ratio: collateral.debt_ratio(),
                liquidation_fee: collateral.liquidation_fee(),
                liquidation_incentive: collateral.liquidation_incentive(),
            };

            let shuttleB = ShuttleInfoB {
                shuttle_id: shuttle_id,
                total_supply: borrowable.total_supply(),
                total_balance: borrowable.total_balance(),
                total_borrows: borrowable.total_borrows(),
                total_assets: borrowable.total_assets(),
                exchange_rate: borrowable.exchange_rate(),
                reserve_factor: borrowable.reserve_factor(),
                utilization_rate: borrowable.utilization_rate(),
                supply_rate: borrowable.supply_rate(),
                borrow_rate: borrowable.borrow_rate(),
            };

            (shuttleC, shuttleB)
        }

        // Start periphery functions:
        //   1. Borrow
        //   2. Repay
        //   3. Liquidate
        //   4. Flash Liquidate
        //   5. Leverage
        //   6. Deleverage

        //  1. BORROW ────────────────────────────────────

        /// # Implementation
        /// * IAltair
        fn borrow(
            ref self: ContractState,
            borrowable: ContractAddress,
            borrow_amount: u256,
            recipient: ContractAddress,
            deadline: u64
        ) {
            /// Check tx deadline
            self.check_deadline_internal(deadline);

            /// Borrowable contract
            let borrowable = IBorrowableDispatcher { contract_address: borrowable };

            /// Pass empty bytes (used for leverage calldata)
            let empty_bytes = self.local_bytes_borrow();

            /// Borrow `borrow_amount` of USD
            /// Note the fixed msg.sender as borrower
            borrowable.borrow(get_caller_address(), recipient, borrow_amount, empty_bytes);
        }

        //  2. Repay ────────────────────────────────────

        /// # Implementation
        /// * IAltair
        fn repay(
            ref self: ContractState,
            borrowable: ContractAddress,
            repay_amount: u256,
            borrower: ContractAddress,
            deadline: u64
        ) {
            /// Check tx deadline
            self.check_deadline_internal(deadline);

            /// Create borrowable dispatcher
            let borrowable = IBorrowableDispatcher { contract_address: borrowable };

            /// Make sure that borrower is never repaying more than they should
            let amount = self.max_repay_amount_internal(borrowable, repay_amount, borrower);

            /// Transfer USD from sender to the borrowable and repay
            let usd = self.usd.read();
            usd.transfer_from(get_caller_address(), borrowable.contract_address, amount.into());

            /// Pass empty bytes (used for leverage calldata)
            let empty_bytes = self.local_bytes_borrow();

            /// Update borrower snapshot
            borrowable.borrow(borrower, Zeroable::zero(), 0, empty_bytes);
        }

        //  3. Liquidate ────────────────────────────────────

        /// # Implementation
        /// * IAltair
        fn liquidate(
            ref self: ContractState,
            borrowable: ContractAddress,
            repay_amount: u256,
            borrower: ContractAddress,
            recipient: ContractAddress,
            deadline: u64
        ) -> (u256, u256) {
            /// Check tx deadline
            self.check_deadline_internal(deadline);

            /// Create borrowable dispatcher
            let borrowable = IBorrowableDispatcher { contract_address: borrowable };

            /// Make sure that liquidator is never repaying more than they should
            let amount = self.max_repay_amount_internal(borrowable, repay_amount, borrower);

            /// Transfer USD from sender to the borrowable
            let usd = self.usd.read();
            usd.transfer_from(get_caller_address(), borrowable.contract_address, amount.into());

            /// Pass empty bytes (used for flash liquidate calldata)
            let empty_bytes = self.local_bytes_liquidate();

            /// Liquidate and receive CygLP
            let seize_tokens = borrowable.liquidate(borrower, recipient, amount, empty_bytes);

            (amount, seize_tokens)
        }

        /// # Implementation
        /// * IAltair
        fn set_altair_extension(
            ref self: ContractState, shuttle_id: u32, extension: ContractAddress
        ) {
            let caller = get_caller_address();

            /// Error
            /// `CALLER_NOT_ADMIN`
            assert(caller == self.hangar18.read().admin(), CALLER_NOT_ADMIN);

            /// Get shuttle from factory given `shuttle_id`
            let shuttle: Shuttle = self.hangar18.read().all_shuttles(shuttle_id);

            /// Error
            /// `SHUTTLE_NOT_DEPLOYED`
            assert(shuttle.deployed, SHUTTLE_NOT_DEPLOYED);

            /// If this is a new extension we add to array and mark is_extension to true
            if !self.is_extension.read(extension) {
                /// Get total extensions length to get ID, add extension to array and mark as true
                let total_extensions = self.total_extensions.read();
                self.all_extensions.write(total_extensions, extension);
                self.is_extension.write(extension, true);

                /// Update length
                self.total_extensions.write(total_extensions + 1);
            }

            /// Write extension to borrowable and collateral
            self.extensions.write(shuttle.borrowable.contract_address, extension);
            self.extensions.write(shuttle.collateral.contract_address, extension);

            /// Use the extension for the LP token also, this is to use the `get_assets_for_shares`
            /// function which ideally each extension should implement
            self.extensions.write(shuttle.collateral.underlying(), extension);
        }
    }

    /// ══════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ══════════════════════════════════════════════════════════════════════════════════

    /// Calldata
    #[generate_trait]
    impl CalldataImpl of CalldataImplTrait {
        /// Creates leverage calldata which is passed back to the borrowable and back to this router
        ///
        /// # Arguments
        /// * `lp_token_pair` - The address of the LP Token
        /// * `collateral` - The address of the Cygnus collateral
        /// * `borrowable` - The address of the Cygnus borrowable
        /// * `lp_amount_min` - The minimum amount allowed of LP received 
        #[inline(always)]
        fn create_leverage_data(
            self: @ContractState,
            lp_token_pair: ContractAddress,
            collateral: ContractAddress,
            borrowable: ContractAddress,
            lp_amount_min: u256
        ) -> LeverageCalldata {
            /// Recipient is always msg.sender as borrowable checks borrow allowance
            let recipient = get_caller_address();

            /// Return calldata struct
            LeverageCalldata { lp_token_pair, collateral, borrowable, recipient, lp_amount_min }
        }

        /// Empty bytes
        ///
        /// # Returns
        /// * Empty leverage calldata struct
        #[inline(always)]
        fn local_bytes_borrow(self: @ContractState) -> LeverageCalldata {
            /// Create empty bytes in case of no leverage/repay
            LeverageCalldata {
                lp_token_pair: Zeroable::zero(),
                collateral: Zeroable::zero(),
                borrowable: Zeroable::zero(),
                recipient: Zeroable::zero(),
                lp_amount_min: 0,
            }
        }

        /// Empty bytes
        ///
        /// # Returns
        /// * Empty leverage calldata struct
        #[inline(always)]
        fn local_bytes_liquidate(self: @ContractState) -> LiquidateCalldata {
            /// Create empty bytes in case of no leverage/repay
            LiquidateCalldata {
                lp_token_pair: Zeroable::zero(),
                collateral: Zeroable::zero(),
                borrowable: Zeroable::zero(),
                recipient: Zeroable::zero(),
                borrower: Zeroable::zero(),
                repay_amount: 0
            }
        }
    }

    /// Helpers
    #[generate_trait]
    impl HelpersImpl of HelpersImplTrait {
        /// Useful when deleveraging or flash liquidating, and need to convert shares seized/sold into assets
        ///
        /// # Arguments
        /// * `shares` - The amount of CygLP to conver to LP
        /// * `collateral` - The address of the CygLP collateral
        ///
        /// # Returns
        /// * The amount of assets received by redeeming `shares`
        #[inline(always)]
        fn convert_to_assets_internal(
            self: @ContractState, shares: u256, collateral: ICollateralDispatcher
        ) -> u256 {
            /// Supply of CygLP
            let total_supply = collateral.total_supply();
            /// LP Tokens
            let total_assets = collateral.total_assets();

            shares.full_mul_div(total_assets, total_supply)
        }

        /// Use deadline control for certain borrow/swap actions
        ///
        /// # Arguments
        /// * `deadline` - The maximum timestamp allowed for tx to succeed
        #[inline(always)]
        fn check_deadline_internal(ref self: ContractState, deadline: u64) {
            /// # Error
            /// `TRANSACTION_EXPIRED` - Revert if we are passed deadline
            assert(get_block_timestamp() <= deadline, TRANSACTION_EXPIRED);
        }

        /// Helpful function to ensure that borrowers never repay more than their owed amount
        ///
        /// # Arguments
        /// * `borrowable` - The address of the borrowable
        /// * `amount_max` - The amount user wants to repay
        /// * `borrower` - The address of the borrower
        ///
        /// # Returns
        /// * The maximum amount that user should repay
        #[inline(always)]
        fn max_repay_amount_internal(
            self: @ContractState,
            borrowable: IBorrowableDispatcher,
            repay_amount: u256,
            borrower: ContractAddress
        ) -> u256 {
            /// Accrue interest first
            borrowable.accrue_interest();

            /// Get the latest borrow balance
            let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);

            /// Return the correct repay amount
            if repay_amount < borrow_balance {
                repay_amount
            } else {
                borrow_balance
            }
        }
    }
}

