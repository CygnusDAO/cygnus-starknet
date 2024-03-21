//  SPDX-License-Identifier: AGPL-3.0-or-later
//
//  altair.cairo
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
//       PERIPHERY ROUTER (`Altair`) - https://cygnusdao.finance                                                          .                     .
//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════

// Libraries
use starknet::ContractAddress;
use cygnus::data::calldata::{Aggregator};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::periphery::altair_x::{IAltairXDispatcher, IAltairXDispatcherTrait};

/// # Interface - Altair
#[starknet::interface]
trait IAltair<T> {
    /// -------------------------------------------------------------------------------------------------------
    ///                                         CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// # Returns
    /// * Name of the router (`Altair`)
    fn name(self: @T) -> felt252;

    /// # Returns
    /// * The version of this router
    fn version(self: @T) -> felt252;

    /// # Returns
    /// * The address of hangar18 on Starknet
    fn hangar18(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of the current admin, the pool/orbiter deployer
    fn admin(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of USD
    fn usd(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of native token (ie WETH)
    fn native_token(self: @T) -> ContractAddress;

    /// # Returns
    /// * The addres of the Avnu Exchange router
    fn avnu_exchange(self: @T) -> ContractAddress;

    /// # Returns
    /// * The addres of the Fibrous Router V2
    fn fibrous_router(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of the Jediswap Router
    fn jediswap_router(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of Ekubo's Router v2.0.1
    fn ekubo_router(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of Ekubo Core
    fn ekubo_core(self: @T) -> ContractAddress;

    /// # Arguments
    /// * `extension_id` - The ID of an extension
    ///
    /// # Returns
    /// * The extension address
    fn all_extensions(self: @T, extension_id: u32) -> ContractAddress;

    /// # Arguments
    /// * `extension` - The address of the periphery extension
    ///
    /// # Returns
    /// * Whether the `extension` has been added to this contract or not
    fn is_extension(self: @T, extension: ContractAddress) -> bool;

    /// # Arguments
    /// * `cygnus_vault` - The address of a borrowable, collateral or lp token address
    ///
    /// # Returns
    /// * The extension address
    fn get_extension(self: @T, cygnus_vault: ContractAddress) -> ContractAddress;

    /// # Returns
    /// * The total amount of extensions we have initialized
    fn all_extensions_length(self: @T) -> u32;

    /// # Arguments
    /// * `shuttle_id` - Unique lending pool ID
    ///
    /// # Returns
    /// * The extension that is currently being used for a lending pool id
    fn get_shuttle_extension(self: @T, shuttle_id: u32) -> ContractAddress;

    /// Get assets out of token0 and token1 by burning `shares` of `lp_token`
    ///
    /// # Arguments
    /// * `lp_token` - The address of the LP Token
    /// * `shares` - The shares being burnt
    ///
    /// # Returns
    /// * The amount of token0 and token1 received
    fn get_assets_for_shares(self: @T, lp_token: ContractAddress, shares: u128) -> (u128, u128);

    /// -------------------------------------------------------------------------------------------------------
    ///                                      NON-CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// Main function used to borrow stablecoins
    ///
    /// # Arguments
    /// * `borrowable` - The address of a Cygnus borrowable
    /// * `amount` - The amount of USD to borrow
    /// * `recipient` - The address of the recipient of the loan
    /// * `deadline` - The maximum timestamp allowed for tx to succeed
    fn borrow(
        ref self: T, borrowable: IBorrowableDispatcher, borrow_amount: u128, recipient: ContractAddress, deadline: u64
    );

    /// Borrows USDC and buys more LP, depositing back in Cygnus and minting CygLP to the caller
    ///
    /// # Arguments
    /// * `lp_token_pair` - The address of the LP Token
    /// * `collateral` - The address of the Cygnus collateral
    /// * `borrowable` - The address of the Cygnus borrowable
    /// * `borrow_amount` - The amount of USDC to convert into LP
    /// * `lp_amount_min` - The minimum allowed of LP to be minted, else reverts
    /// * `deadline` - TX expires after this timestamp
    /// * `swapdata` - The swapdata for the aggregators (empty if performed on-chain via sithswap, jediswap, etc.)
    ///
    /// # Returns
    /// * The amount of LP minted
    fn leverage(
        ref self: T,
        lp_token_pair: ContractAddress,
        collateral: ContractAddress,
        borrowable: ContractAddress,
        borrow_amount: u128,
        lp_amount_min: u128,
        deadline: u64,
        aggregator: Aggregator,
        swapdata: Array<Span<felt252>>
    ) -> u128;

    /// Burns the LP and buys USDC, repaying any debt the user may have (if any) and burning the user's CygLP
    ///
    /// # Arguments
    /// * `lp_token_pair` - The address of the LP Token
    /// * `collateral` - The address of the Cygnus collateral
    /// * `borrowable` - The address of the Cygnus borrowable
    /// * `cyg_lp_amount` - The amount of CygLP to deleverage
    /// * `usd_amount_min` - The minimum allowed of usdc to be received by redeeming `cyg_lp_amount` and selling assets
    /// * `deadline` - TX expires after this timestamp
    /// * `swapdata` - The swapdata for the aggregators (empty if performed on-chain via sithswap, jediswap, etc.)
    ///
    /// # Returns
    /// * The amount of LP minted
    fn deleverage(
        ref self: T,
        lp_token_pair: ContractAddress,
        collateral: ContractAddress,
        borrowable: ContractAddress,
        cyg_lp_amount: u128,
        usd_amount_min: u128,
        deadline: u64,
        aggregator: Aggregator,
        swapdata: Array<Span<felt252>>
    ) -> u128;

    /// Main function used to repay a loan
    ///
    /// # Arguments
    /// * `borrowable` - The address of a Cygnus borrowable
    /// * `repay_amount` - The amount of USD to repay
    /// * `borrower` - The address of the borrower whose loan we are repaying
    /// * `deadline` - The maximum timestamp allowed for tx to succeed
    fn repay(ref self: T, borrowable: ContractAddress, repay_amount: u128, borrower: ContractAddress, deadline: u64);

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
        ref self: T,
        borrowable: ContractAddress,
        repay_amount: u128,
        borrower: ContractAddress,
        recipient: ContractAddress,
        deadline: u64
    ) -> (u128, u128);

    /// Main function to flash liquidate borrows. Ie, liquidating a user without needing to have USD
    ///
    /// # Arguments
    /// `borrowable` - The address of the CygnusBorrow contract
    /// `amountMax` - The maximum amount to liquidate
    /// `borrower` - The address of the borrower
    /// `deadline` - The time by which the transaction must be included to effect the change
    /// `dexAggregator` - The dex used to sell the collateral (0 for Paraswap, 1 for 1inch)
    /// `swapdata` - Calldata to swap
    ///
    /// # Returns
    /// * The USDC amount received
    fn flash_liquidate(
        ref self: T,
        borrowable: ContractAddress,
        collateral: ContractAddress,
        repay_amount: u128,
        borrower: ContractAddress,
        deadline: u64,
        aggregator: Aggregator,
        swapdata: Array<Span<felt252>>
    ) -> u128;

    /// -------------------------------------------------------------------------------------------------------
    ///                                              CALLBACKS
    /// -------------------------------------------------------------------------------------------------------

    /// Function that is called by the CygnusBorrow contract and decodes data to carry out the leverage
    /// Will only succeed if: Caller is borrow contract & Borrow contract was called by router
    /// 
    /// # Arguments
    /// * `sender` - Address of the contract that initialized the borrow transaction (address of the router)
    /// * `borrow_amount` - The amount of USDC to leverage
    /// * `calldata` - The encoded byte data passed from the CygnusBorrow contract to the router
    ///
    /// # Returns
    /// * The amount of LP minted
    fn altair_borrow_09E(ref self: T, sender: ContractAddress, borrow_amount: u128, calldata: Array<felt252>) -> u128;

    /// Function that is called by the CygnusCollateral contract and decodes data to carry out the deleverage.
    /// Will only succeed if: Caller is collateral contract & collateral contract was called by router
    ///
    /// # Arguments
    /// * `sender` - Address of the contract that initialized the redeem transaction (address of the router)
    /// * `redeem_amount` - The amount of LP to deleverage
    /// * `calldata` - The encoded byte data passed from the CygnusCollateral contract to the router
    ///
    /// # Returns
    /// * The amount of USDC received from deleveraging LP
    fn altair_redeem_u91A(ref self: T, sender: ContractAddress, redeem_amount: u128, calldata: Array<felt252>) -> u128;

    /// Function that is called by the CygnusBorrow contract to carry out the flash liqudiation.
    /// Will only succeed if: Caller is borrow contract & Borrow contract was called by router
    ///
    /// # Arguments
    /// * `sender` - Address of the contract that initialized the borrow transaction (address of the router)
    /// * `cyg_lp_amount` - The amount of CygLP seized
    /// * `repay_amount` - The amount of USDC that the borrowable contract expects back
    /// * `calldata` - The encoded byte data passed from the CygnusBorrow contract to the router
    ///
    /// # Returns
    /// * The amount of LP minted
    fn altair_liquidate_f2x(
        ref self: T, sender: ContractAddress, cyg_lp_amount: u128, repay_amount: u128, calldata: Array<felt252>
    );

    /// -------------------------------------------------------------------------------------------------------
    ///                                            ADMIN
    /// -------------------------------------------------------------------------------------------------------

    /// Admin sets a new extension
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the shuttle we are setting the extension for
    ///
    /// # Security
    /// * Only-admin
    fn set_altair_extension(ref self: T, shuttle_ids: Array<u32>, extension: IAltairXDispatcher);
}


/// # Module - Altair
#[starknet::contract]
mod Altair {
    /// -------------------------------------------------------------------------------------------------------
    ///     1. IMPORTS
    /// -------------------------------------------------------------------------------------------------------

    /// # Interfaces
    use super::IAltair;
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use cygnus::token::univ2pair::{IUniswapV2PairDispatcher, IUniswapV2PairDispatcherTrait};
    use cygnus::terminal::{
        collateral::{ICollateralDispatcher, ICollateralDispatcherTrait},
        borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait}
    };
    use cygnus::periphery::altair_x::{IAltairXDispatcher, IAltairXDispatcherTrait, IAltairXLibraryDispatcher};
    use cygnus::periphery::integrations::jediswap_router::{IJediswapRouterDispatcher, IJediswapRouterDispatcherTrait};
    use ekubo::interfaces::{
        router::{IRouterDispatcher, IRouterDispatcherTrait}, core::{ICoreDispatcher, ICoreDispatcherTrait}
    };

    /// # Imports
    use cygnus::libraries::full_math_lib::FullMathLib::FixedPointMathLibTrait;
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, get_block_timestamp, contract_address_const,
        call_contract_syscall
    };

    /// # Data
    use cygnus::data::{
        shuttle::{Shuttle}, calldata::{LeverageCalldata, DeleverageCalldata, LiquidateCalldata, Aggregator}
    };

    /// # Errors
    use cygnus::periphery::errors::Errors;

    /// -------------------------------------------------------------------------------------------------------
    ///     3. STORAGE
    /// -------------------------------------------------------------------------------------------------------

    #[storage]
    struct Storage {
        /// Current admin, the only one capable of deploying pools
        admin: ContractAddress,
        /// Pending Admin, the address of the new pending admin
        usd: IERC20Dispatcher,
        /// ie WETH
        native_token: IERC20Dispatcher,
        /// Factory
        hangar18: IHangar18Dispatcher,
        /// Total extensions initialized
        total_extensions: u32,
        /// Extensions
        extensions: LegacyMap<ContractAddress, IAltairXDispatcher>,
        /// Array of extensions
        all_extensions: LegacyMap<u32, IAltairXDispatcher>,
        /// Mapping to check if extension exists
        is_extension: LegacyMap<ContractAddress, bool>,
        /// Avnu
        avnu_exchange: ContractAddress,
        /// Fibrous
        fibrous_router: ContractAddress,
        /// Jediswap for on-chain swaps in case somethin goes wrong
        jediswap_router: IJediswapRouterDispatcher,
        /// Ekubo router
        ekubo_router: IRouterDispatcher,
        /// Ekubo Core
        ekubo_core: ICoreDispatcher
    }

    /// Aggregator addresses on Mainnet

    /// Avnu
    const AVNU_ROUTER: felt252 = 0x4270219d365d6b017231b52e92b3fb5d7c8378b05e9abc97724537a80e93b0f;
    /// Fibrous
    const FIBROUS_ROUTER: felt252 = 0x00f6f4CF62E3C010E0aC2451cC7807b5eEc19a40b0FaaCd00CCA3914280FDf5a;
    /// Jediswap
    const JEDISWAP_ROUTER: felt252 = 0x041fd22b238fa21cfcf5dd45a8548974d8263b3a531a60388411c5e230f97023;
    /// Ekubo Router v2.0.1
    const EKUBO_ROUTER: felt252 = 0x03266fe47923e1500aec0fa973df8093b5850bbce8dcd0666d3f47298b4b806e;
    /// Ekubo core
    const EKUBO_CORE: felt252 = 0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b;

    /// Selectors

    /// `multi_route_swap`
    const AVNU_SELECTOR: felt252 = 0x1171593aa5bdadda4d6b0efde6cc94ee7649c3163d5efeb19da6c16d63a2a63;
    /// `swap`
    const FIBROUS_SELECTOR: felt252 = 0x15543c3708653cda9d418b4ccd3be11368e40636c10c44b18cfe756b6d88b29;


    /// -------------------------------------------------------------------------------------------------------
    ///     4. CONSTURCTOR
    /// -------------------------------------------------------------------------------------------------------

    #[constructor]
    fn constructor(ref self: ContractState, hangar18: IHangar18Dispatcher) {
        // Get native and usd from factory
        let native_token = IERC20Dispatcher { contract_address: hangar18.native_token() };
        let usd = IERC20Dispatcher { contract_address: hangar18.usd() };

        // Store factory and dispatchers
        self.hangar18.write(hangar18);
        self.usd.write(usd);
        self.native_token.write(native_token);

        /// ----- These routers are used in most cases ------

        /// Avnu router
        self.avnu_exchange.write(contract_address_const::<AVNU_ROUTER>());
        /// Fibrous router
        self.fibrous_router.write(contract_address_const::<FIBROUS_ROUTER>());

        /// ------- These routers are used to handle the swaps on-chain if needed -----

        /// Jediswap router
        self
            .jediswap_router
            .write(IJediswapRouterDispatcher { contract_address: contract_address_const::<JEDISWAP_ROUTER>() });

        /// Ekubo router
        self.ekubo_router.write(IRouterDispatcher { contract_address: contract_address_const::<EKUBO_ROUTER>() });

        /// Ekubo core
        self.ekubo_core.write(ICoreDispatcher { contract_address: contract_address_const::<EKUBO_CORE>() });
    }

    /// -------------------------------------------------------------------------------------------------------
    ///     5. IMPLEMENTATION
    /// -------------------------------------------------------------------------------------------------------

    #[abi(embed_v0)]
    impl AltairImpl of IAltair<ContractState> {
        /// # Implementation
        /// * IAltair
        fn name(self: @ContractState) -> felt252 {
            'Cygnus: Altair Router'
        }

        /// # Implementation
        /// * IAltair
        fn version(self: @ContractState) -> felt252 {
            '1.0.0'
        }

        /// # Implementation
        /// * IAltair
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * IAltair
        fn admin(self: @ContractState) -> ContractAddress {
            self.hangar18.read().admin()
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

        /// Aggregators

        /// # Implementation
        /// * IAltair
        fn jediswap_router(self: @ContractState) -> ContractAddress {
            self.jediswap_router.read().contract_address
        }

        /// # Implementation
        /// * IAltair
        fn ekubo_router(self: @ContractState) -> ContractAddress {
            self.ekubo_router.read().contract_address
        }

        /// # Implementation
        /// * IAltair
        fn ekubo_core(self: @ContractState) -> ContractAddress {
            self.ekubo_core.read().contract_address
        }

        /// # Implementation
        /// * IAltair
        fn avnu_exchange(self: @ContractState) -> ContractAddress {
            self.avnu_exchange.read()
        }

        /// # Implementation
        /// * IAltair
        fn fibrous_router(self: @ContractState) -> ContractAddress {
            self.fibrous_router.read()
        }

        /// # Implementation
        /// * IAltair
        fn get_extension(self: @ContractState, cygnus_vault: ContractAddress) -> ContractAddress {
            self.extensions.read(cygnus_vault).contract_address
        }

        /// # Implementation
        /// * IAltair
        fn is_extension(self: @ContractState, extension: ContractAddress) -> bool {
            self.is_extension.read(extension)
        }

        /// # Implementation
        /// * IAltair
        fn all_extensions(self: @ContractState, extension_id: u32) -> ContractAddress {
            self.all_extensions.read(extension_id).contract_address
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
            self.extensions.read(shuttle.collateral.contract_address).contract_address
        }

        /// # Implementation
        /// * IAltair
        fn get_assets_for_shares(self: @ContractState, lp_token: ContractAddress, shares: u128) -> (u128, u128) {
            /// Get the extension for the LP
            let extension = self.extensions.read(lp_token);

            /// # Error
            /// * `ALTAIR_EXTENSION_DOESNT_EXIST`
            assert(extension.contract_address.is_non_zero(), Errors::ALTAIR_EXTENSION_DOESNT_EXIST);

            /// The extension handles this logic
            extension.get_assets_for_shares(lp_token, shares)
        }

        /// Start periphery functions:
        ///
        /// 1. Borrow          - Users can borrow and receive USDC as long as they have enough LP collateral.
        /// 2. Repay           - Users can repay a loan by transfering USDC back to the borrowable and calling `borrow`
        /// 3. Liquidate       - Repay a user's shortfall loan and receive the equivalent of the repaid + bonus in CygLP
        /// 4. Flash Liquidate - Sells the shortfall collateral to the market and receive the equivalent + bonus in USDC
        /// 5. Leverage        - Borrows USDC from the borrowable and converts all USDC into LP and deposits back in Cygnus
        /// 6. Deleverage      - Burn LP collateral and convert into USDC and repay a loan (if any) and receive leftover USDC

        /// ---------------------------------------------------------------------------------------------------
        ///                                         1. BORROW
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IAltair
        fn borrow(
            ref self: ContractState,
            borrowable: IBorrowableDispatcher,
            borrow_amount: u128,
            recipient: ContractAddress,
            deadline: u64
        ) {
            /// Check tx deadline
            self._check_deadline(deadline);

            /// Borrow `borrow_amount` of USD, msg.sender always fixed. Pass empty bytes (used for leverage tx)
            borrowable.borrow(get_caller_address(), recipient, borrow_amount, Default::default());
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                         2. REPAY
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IAltair
        fn repay(
            ref self: ContractState,
            borrowable: ContractAddress,
            repay_amount: u128,
            borrower: ContractAddress,
            deadline: u64
        ) {
            /// Check tx deadline
            self._check_deadline(deadline);

            /// Create borrowable dispatcher
            let borrowable = IBorrowableDispatcher { contract_address: borrowable };

            /// Make sure that borrower is never repaying more than they should
            let amount = self._max_repay_amount(borrowable, repay_amount, borrower);

            /// Transfer USD from sender to the borrowable and repay
            let usd = self.usd.read();
            usd.transferFrom(get_caller_address().into(), borrowable.contract_address.into(), amount.into());

            /// Update borrower snapshot
            borrowable.borrow(borrower, Zeroable::zero(), 0, Default::default());
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                         3. LIQUIDATE
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IAltair
        fn liquidate(
            ref self: ContractState,
            borrowable: ContractAddress,
            repay_amount: u128,
            borrower: ContractAddress,
            recipient: ContractAddress,
            deadline: u64
        ) -> (u128, u128) {
            /// Check tx deadline
            self._check_deadline(deadline);

            /// Create borrowable dispatcher
            let borrowable = IBorrowableDispatcher { contract_address: borrowable };

            /// Make sure that liquidator is never repaying more than they should
            let amount = self._max_repay_amount(borrowable, repay_amount, borrower);

            /// Transfer USD from sender to the borrowable
            let usd = self.usd.read();
            usd.transferFrom(get_caller_address().into(), borrowable.contract_address.into(), amount.into());

            /// Liquidate and receive CygLP
            let seize_tokens = borrowable.liquidate(borrower, recipient, amount, Default::default());

            (amount, seize_tokens)
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                         4. LEVERAGE
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IAltair
        fn leverage(
            ref self: ContractState,
            lp_token_pair: ContractAddress,
            collateral: ContractAddress,
            borrowable: ContractAddress,
            borrow_amount: u128,
            lp_amount_min: u128,
            deadline: u64,
            aggregator: Aggregator,
            swapdata: Array<Span<felt252>>
        ) -> u128 {
            /// Check tx deadline
            self._check_deadline(deadline);

            /// Recipient is always caller
            let recipient = get_caller_address();

            /// Encode calldata into array of felts
            let mut calldata = array![];

            LeverageCalldata { lp_token_pair, collateral, borrowable, recipient, lp_amount_min, aggregator, swapdata }
                .serialize(ref calldata);

            let borrowable = IBorrowableDispatcher { contract_address: borrowable };

            /// This contract should be the receiver of USDC to perform the leverage in the `altair_borrow` callback
            borrowable.borrow(recipient, get_contract_address(), borrow_amount, calldata)
        }

        /// This is a callback to this router to leverage a position, which gets delegated to the borrowable/collateral's
        /// extension since each LP/DEX requires different implementation logic.
        ///
        /// # Implementation
        /// * IAltair
        fn altair_borrow_09E(
            ref self: ContractState, sender: ContractAddress, borrow_amount: u128, calldata: Array<felt252>
        ) -> u128 {
            /// Get the extension for the vault
            /// TODO - Replace all_extensions wtih caller_address
            let extension = self.all_extensions.read(0);

            /// # Error
            /// * `ALTAIR_EXTENSION_DOESNT_EXIST`
            assert(extension.contract_address.is_non_zero(), Errors::ALTAIR_EXTENSION_DOESNT_EXIST);

            /// We delegate the call to the extension as each extension handles the logic of leveraging collateral.
            /// For example Jediswap uses different LPs than Ekubo and Sithswap, so each require different logic.
            let altair_x = IAltairXLibraryDispatcher { class_hash: extension.class_hash() };

            altair_x.altair_borrow_09E(sender, borrow_amount, calldata)
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                         5. DELEVERAGE
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IAltair
        fn deleverage(
            ref self: ContractState,
            lp_token_pair: ContractAddress,
            collateral: ContractAddress,
            borrowable: ContractAddress,
            cyg_lp_amount: u128,
            usd_amount_min: u128,
            deadline: u64,
            aggregator: Aggregator,
            swapdata: Array<Span<felt252>>
        ) -> u128 {
            /// Check tx deadline
            self._check_deadline(deadline);

            /// Recipient is always caller
            let recipient = get_caller_address();

            /// Encode calldata into array of felts
            let mut calldata = array![];
            DeleverageCalldata {
                lp_token_pair, collateral, borrowable, recipient, cyg_lp_amount, usd_amount_min, aggregator, swapdata
            }
                .serialize(ref calldata);

            /// Collateral contract to withdraw LPs from
            let collateral = ICollateralDispatcher { contract_address: collateral };

            /// The equivalent of the CygLP in LP tokens
            let redeem_amount = self._convert_to_assets(cyg_lp_amount, collateral);

            /// We receive back LP to this contract to convert to USDC
            collateral.flash_redeem(get_contract_address(), redeem_amount, calldata)
        }


        /// This is a callback to this router to deleverage a position, which gets delegated to the borrowable/collateral's
        /// extension since each LP/DEX requires different implementation logic.
        ///
        /// # Implementation
        /// * IAltair
        fn altair_redeem_u91A(
            ref self: ContractState, sender: ContractAddress, redeem_amount: u128, calldata: Array<felt252>
        ) -> u128 {
            /// Get the extension for the vault
            /// TODO - get the extension from the `caller` address
            let extension = self.all_extensions.read(0);

            /// # Error
            /// * `ALTAIR_EXTENSION_DOESNT_EXIST` - Avoid if no extension is set for this collateral/borrowable
            assert(extension.contract_address.is_non_zero(), Errors::ALTAIR_EXTENSION_DOESNT_EXIST);

            /// We delegate the call to the extension as each extension handles the logic of leveraging collateral.
            /// For example Jediswap uses different LPs than Ekubo and Sithswap, so each require different logic.
            let altair_x = IAltairXLibraryDispatcher { class_hash: extension.class_hash() };

            altair_x.altair_redeem_u91A(sender, redeem_amount, calldata)
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                         6. FLASH LIQUIDATE
        /// ---------------------------------------------------------------------------------------------------

        /// TODO
        /// # Implementation
        /// * IAltair
        fn flash_liquidate(
            ref self: ContractState,
            borrowable: ContractAddress,
            collateral: ContractAddress,
            repay_amount: u128,
            borrower: ContractAddress,
            deadline: u64,
            aggregator: Aggregator,
            swapdata: Array<Span<felt252>>
        ) -> u128 {
            // TODO
            10
        }

        /// # Implementation
        /// * IAltair
        fn altair_liquidate_f2x(
            ref self: ContractState,
            sender: ContractAddress,
            cyg_lp_amount: u128,
            repay_amount: u128,
            calldata: Array<felt252>
        ) {
            /// # Error
            /// * `WRONG_SENDER`
            assert(sender == get_contract_address(), 'wrong_sender');

            /// Get liquidate calldata
            let mut redeem_data = calldata.span();
            let calldata = Serde::<LiquidateCalldata>::deserialize(ref redeem_data).unwrap();

            /// # Error
            /// * `NOT_BORROWABLE` - Avoid if caller is not borrowable
            assert(get_caller_address() == calldata.borrowable, 'not_borrowable');
        /// By now this contract has LPs that were flash redeemed from collateral. Burn the LP, receive
        /// token0 and token1 assets, convert to USDC, repay loan or part of the loan. Collateral contract
        /// is expecting an equivalent amount of the LP redeemed in CygLP, transfer from borrower to collateral
        /// and burn the CygLP.
        // TODO
        //self._flash_liquidate(cyg_lp_amount, repay_amount, calldata)
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                            ADMIN ONLY 👽
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IAltair
        fn set_altair_extension(ref self: ContractState, shuttle_ids: Array<u32>, extension: IAltairXDispatcher) {
            /// Error
            /// `CALLER_NOT_ADMIN`
            assert(get_caller_address() == self.hangar18.read().admin(), Errors::CALLER_NOT_ADMIN);

            let mut index = 0;

            loop {
                /// Break clause
                if (index == shuttle_ids.len()) {
                    break;
                }

                /// Get shuttle id
                let shuttle_id = *shuttle_ids.at(index);

                /// Get shuttle from factory given `shuttle_id`
                let shuttle: Shuttle = self.hangar18.read().all_shuttles(shuttle_id);

                /// Error
                /// `SHUTTLE_NOT_DEPLOYED`
                assert(shuttle.deployed, Errors::SHUTTLE_NOT_DEPLOYED);

                /// If this is a new extension we add to array and mark is_extension to true
                if !self.is_extension.read(extension.contract_address) {
                    /// Get total extensions length to get ID
                    let total_extensions = self.total_extensions.read();

                    /// Mark as true
                    self.is_extension.write(extension.contract_address, true);

                    /// Set extension in `array` (Extension ID => Extension)
                    self.all_extensions.write(total_extensions, extension);

                    /// Update array length
                    self.total_extensions.write(total_extensions + 1);
                }

                /// Write extension to borrowable and collateral

                /// For leveraging USDC into LP tokens
                self.extensions.write(shuttle.borrowable.contract_address, extension);

                /// For deleveraging/flash liquidating LP Tokens into USDC
                self.extensions.write(shuttle.collateral.contract_address, extension);

                /// Write extension to LP Token collateral

                /// For using `get_assets_for_shares` in this router
                self.extensions.write(shuttle.collateral.underlying(), extension);

                index += 1;
            }
        }
    }

    /// -------------------------------------------------------------------------------------------------------
    ///     6. INTERNAL LOGIC
    /// -------------------------------------------------------------------------------------------------------

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
        fn _convert_to_assets(self: @ContractState, shares: u128, collateral: ICollateralDispatcher) -> u128 {
            /// assets = (shares * balance) / supply
            shares.full_mul_div(collateral.total_assets(), collateral.total_supply())
        }

        /// Use deadline control for certain borrow/swap actions
        ///
        /// # Arguments
        /// * `deadline` - The maximum timestamp allowed for tx to succeed
        #[inline(always)]
        fn _check_deadline(ref self: ContractState, deadline: u64) {
            /// # Error
            /// `TRANSACTION_EXPIRED` - Revert if we are passed deadline
            assert(get_block_timestamp() <= deadline, Errors::TRANSACTION_EXPIRED);
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
        fn _max_repay_amount(
            self: @ContractState, borrowable: IBorrowableDispatcher, repay_amount: u128, borrower: ContractAddress
        ) -> u128 {
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

