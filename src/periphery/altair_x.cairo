//  SPDX-License-Identifier: AGPL-3.0-or-later
//
//  altair_x.cairo
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
//       ALTAIR EXTENSION - JEDISWAP LP - https://cygnusdao.finance                                                          .                     .
//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════

use cygnus::data::calldata::{Aggregator};
use starknet::{ContractAddress, ClassHash};
use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::data::altair::{ShuttleInfoC, ShuttleInfoB, BorrowerPosition, LenderPosition};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};

/// # Interface - Altair
#[starknet::interface]
trait IAltairX<T> {
    /// -------------------------------------------------------------------------------------------------------
    ///                                         CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// # Returns
    /// * Name of the router (`Altair`)
    fn name(self: @T) -> felt252;

    /// # Returns
    /// * The address of hangar18 on Starknet
    fn hangar18(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of the current admin, the pool/orbiter deployer
    fn admin(self: @T) -> ContractAddress;

    /// # Returns
    /// * The extension's class hash
    fn class_hash(self: @T) -> ClassHash;

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
    /// * The address of the Ekubo Router (v2.0.1)
    fn ekubo_router(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of Ekubo Core
    fn ekubo_core(self: @T) -> ContractAddress;

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
    ) -> u128;
}


/// # Module - Altair
#[starknet::contract]
mod AltairX {
    /// -------------------------------------------------------------------------------------------------------
    ///     1. IMPORTS
    /// -------------------------------------------------------------------------------------------------------

    /// # Interfaces
    use super::IAltairX;
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use cygnus::token::univ2pair::{IUniswapV2PairDispatcher, IUniswapV2PairDispatcherTrait};
    use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};

    /// # Libraries
    use cygnus::libraries::full_math_lib::FullMathLib::FixedPointMathLibTrait;
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, get_block_timestamp, contract_address_const,
        call_contract_syscall, ClassHash, SyscallResultTrait
    };

    /// # Errors
    use cygnus::periphery::errors::Errors;

    /// # Data
    use cygnus::data::{
        shuttle::{Shuttle}, calldata::{LeverageCalldata, DeleverageCalldata, LiquidateCalldata, Aggregator},
        altair::{ShuttleInfoC, ShuttleInfoB, BorrowerPosition, LenderPosition}
    };

    /// Aggregators
    use cygnus::periphery::integrations::{
        jediswap_router::{IJediswapRouterDispatcher, IJediswapRouterDispatcherTrait},
        ekubo_router::{IRouterDispatcher, IRouterDispatcherTrait, TokenAmount, RouteNode}
    };
    use ekubo::{
        interfaces::{core::{ICoreDispatcher, ICoreDispatcherTrait}}, types::{keys::{PoolKey}, i129::{i129, i129_new}},
        components::clear::{IClearDispatcher, IClearDispatcherTrait}
    };


    /// -------------------------------------------------------------------------------------------------------
    ///     3. STORAGE
    /// -------------------------------------------------------------------------------------------------------

    #[storage]
    struct Storage {
        /// Current admin, the only one capable of deploying pools
        admin: ContractAddress,
        /// Our address to enforce delegate calls only
        my_address: ContractAddress,
        /// Class hash
        class_hash: ClassHash,
        /// Pending Admin, the address of the new pending admin
        usd: IERC20Dispatcher,
        /// ie WETH
        native_token: IERC20Dispatcher,
        /// Factory
        hangar18: IHangar18Dispatcher,
        /// Avnu
        avnu_exchange: ContractAddress,
        /// Fibrous
        fibrous_router: ContractAddress,
        /// Jediswap for on-chain swaps
        jediswap_router: IJediswapRouterDispatcher,
        /// Ekubo router
        ekubo_router: IRouterDispatcher,
        /// Core
        ekubo_core: ICoreDispatcher
    }

    /// Selectors

    /// `multi_route_swap`
    const AVNU_SELECTOR: felt252 = 0x1171593aa5bdadda4d6b0efde6cc94ee7649c3163d5efeb19da6c16d63a2a63;

    /// `swap`
    const FIBROUS_SELECTOR: felt252 = 0x15543c3708653cda9d418b4ccd3be11368e40636c10c44b18cfe756b6d88b29;

    /// -------------------------------------------------------------------------------------------------------
    ///     4. CONSTURCTOR
    /// -------------------------------------------------------------------------------------------------------

    #[constructor]
    fn constructor(
        ref self: ContractState, hangar18: IHangar18Dispatcher, altair: IAltairDispatcher, class_hash: ClassHash
    ) {
        /// Write class clash to storage
        self.class_hash.write(class_hash);

        /// Store the address of this extension to make sure some functions can only be called via `library` calls
        /// ie. delegate calls only
        self.my_address.write(get_contract_address());

        // Get native and usd from factory
        let native_token = IERC20Dispatcher { contract_address: hangar18.native_token() };
        let usd = IERC20Dispatcher { contract_address: hangar18.usd() };

        // Store factory, stablecoin we use (usdc) and native (weth) for this chain
        self.hangar18.write(hangar18);
        self.usd.write(usd);
        self.native_token.write(native_token);

        /// Store aggregators we use from altair
        self.avnu_exchange.write(altair.avnu_exchange());
        self.fibrous_router.write(altair.fibrous_router());
        self.jediswap_router.write(IJediswapRouterDispatcher { contract_address: altair.jediswap_router() });
        self.ekubo_router.write(IRouterDispatcher { contract_address: altair.ekubo_router() });
        self.ekubo_core.write(ICoreDispatcher { contract_address: altair.ekubo_core() });
    }

    /// -------------------------------------------------------------------------------------------------------
    ///     5. IMPLEMENTATION
    /// -------------------------------------------------------------------------------------------------------

    #[abi(embed_v0)]
    impl AltairImpl of IAltairX<ContractState> {
        /// # Implementation
        /// * IAltairX
        fn name(self: @ContractState) -> felt252 {
            /// This extension is for jediswap LPs only
            'Altair Extension: Jediswap'
        }

        /// # Implementation
        /// * IAltairX
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * IAltairX
        fn admin(self: @ContractState) -> ContractAddress {
            self.hangar18.read().admin()
        }

        /// # Implementation
        /// * IAltairX
        fn class_hash(self: @ContractState) -> ClassHash {
            self.class_hash.read()
        }

        /// # Implementation
        /// * IAltairX
        fn usd(self: @ContractState) -> ContractAddress {
            self.usd.read().contract_address
        }

        /// # Implementation
        /// * IAltairX
        fn native_token(self: @ContractState) -> ContractAddress {
            self.native_token.read().contract_address
        }

        /// Aggregators

        /// # Implementation
        /// * IAltairX
        fn jediswap_router(self: @ContractState) -> ContractAddress {
            self.jediswap_router.read().contract_address
        }

        /// # Implementation
        /// * IAltairX
        fn ekubo_router(self: @ContractState) -> ContractAddress {
            self.ekubo_router.read().contract_address
        }

        /// # Implementation
        /// * IAltairX
        fn ekubo_core(self: @ContractState) -> ContractAddress {
            self.ekubo_core.read().contract_address
        }

        /// # Implementation
        /// * IAltairX
        fn avnu_exchange(self: @ContractState) -> ContractAddress {
            self.avnu_exchange.read()
        }

        /// # Implementation
        /// * IAltairX
        fn fibrous_router(self: @ContractState) -> ContractAddress {
            self.fibrous_router.read()
        }

        /// # Implementation
        /// * IAltairX
        fn get_assets_for_shares(self: @ContractState, lp_token: ContractAddress, shares: u128) -> (u128, u128) {
            /// LP token (dont use dispatcher in interface so support other dexes/lps)
            let lp_token = IUniswapV2PairDispatcher { contract_address: lp_token };

            /// Get total reserves in LP
            let (reserves0, reserves1, _) = lp_token.get_reserves();

            /// Total supply of LP
            let total_supply: u128 = lp_token.totalSupply().try_into().unwrap();

            /// Same calculation as other vault shares:
            /// assets = (shares * balance) / supply
            let amount0 = shares.full_mul_div(reserves0.try_into().unwrap(), total_supply);
            let amount1 = shares.full_mul_div(reserves1.try_into().unwrap(), total_supply);

            (amount0, amount1)
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
        ///                                         4. LEVERAGE
        /// ---------------------------------------------------------------------------------------------------

        /// # Security
        /// * Only-library-call
        ///
        /// # Implementation
        /// * IAltairX
        fn altair_borrow_09E(
            ref self: ContractState, sender: ContractAddress, borrow_amount: u128, calldata: Array<felt252>
        ) -> u128 {
            /// This function can only be called via library calls only
            self._only_library_call();

            /// # Error
            /// * `WRONG_SENDER`
            assert(sender == get_contract_address(), Errors::SENDER_NOT_ROUTER);

            /// Deserialize the leverage calldata
            let mut borrow_data = calldata.span();
            let calldata = Serde::<LeverageCalldata>::deserialize(ref borrow_data).unwrap();

            /// # Error TODO
            /// * `NOT_BORROWABLE` - Avoid if caller is not borrowable 
            //assert(calldata.borrowable == get_caller_address(), Errors::CALLER_NOT_BORROWABLE);

            /// By now this contract has USDC that were flash borrowed from the collateral. Convert all USDC into
            /// more LP and deposit back in collateral, minting CygLP to the receiver. Borrowable contract does
            /// check at the end that the collateral amount by the borrower is sufficient for the loan.
            self._mint_lp_and_deposit(borrow_amount, calldata)
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                         5. DELEVERAGE
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IAltairX
        fn altair_redeem_u91A(
            ref self: ContractState, sender: ContractAddress, redeem_amount: u128, calldata: Array<felt252>
        ) -> u128 {
            /// This function can only be called via library calls only
            self._only_library_call();

            /// # Error
            /// * `WRONG_SENDER`
            assert(sender == get_contract_address(), Errors::SENDER_NOT_ROUTER);

            /// Get leverage calldata
            let mut redeem_data = calldata.span();
            let calldata = Serde::<DeleverageCalldata>::deserialize(ref redeem_data).unwrap();

            /// # Error TODO
            /// * `NOT_COLLATERAL` - Avoid if caller is not collateral
            /// assert(get_caller_address() == calldata.collateral, Errors::CALLER_NOT_COLLATERAL);

            /// By now this contract has LPs that were flash redeemed from collateral. Burn the LP, receive
            /// token0 and token1 assets, convert to USDC, repay loan or part of the loan. Collateral contract
            /// is expecting an equivalent amount of the LP redeemed in CygLP, transfer from borrower to collateral
            /// and burn the CygLP.
            self._remove_lp_and_repay(redeem_amount, calldata)
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                         6. FLASH LIQUIDATE
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IAltairX
        fn altair_liquidate_f2x(
            ref self: ContractState,
            sender: ContractAddress,
            cyg_lp_amount: u128,
            repay_amount: u128,
            calldata: Array<felt252>
        ) -> u128 {
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
            self._flash_liquidate(cyg_lp_amount, repay_amount, calldata)
        }
    }

    /// -------------------------------------------------------------------------------------------------------
    ///     6. INTERNAL LOGIC
    /// -------------------------------------------------------------------------------------------------------

    #[generate_trait]
    impl LeverageImpl of LeverageImplTrait {
        /// Mints LP to calldata's receiver and deposits it in the Cygnus Collateral contract
        ///
        /// # Arguments
        /// * `borrow_amount` - The USDC amount to convert into LP
        /// * `calldata` - The calldata for the leverage
        ///
        /// # Returns
        /// * The amount of LP minted
        fn _mint_lp_and_deposit(ref self: ContractState, borrow_amount: u128, calldata: LeverageCalldata) -> u128 {
            /// Get underlying LP token for this collateral
            let lp_token = IUniswapV2PairDispatcher { contract_address: calldata.lp_token_pair };

            let token0 = lp_token.token0();
            let token1 = lp_token.token1();

            /// Add liquidity to the pool and mint LP to this router
            let liquidity = self
                ._convert_usd_to_liquidity(token0, token1, borrow_amount, calldata.aggregator, calldata.swapdata);

            /// Collateral contract where we are depositing the LP
            let collateral = ICollateralDispatcher { contract_address: calldata.collateral };

            /// Allow the collateral contract to move our LP
            self._approve_token(lp_token.contract_address, collateral.contract_address, liquidity.into());

            /// Deposit LP in cygnus and mint CygLP to recipient
            collateral.deposit(liquidity, calldata.recipient);

            /// Check for dust to send to receiver
            self._clean_dust(token0, token1, calldata.recipient);

            /// Return LP Minted - useful for static calls, simulate tx, etc. has no use otherwise
            liquidity
        }

        /// Inner function to prepare the data to be sent to the aggregators to leverage, maximum 2 swaps.
        ///
        /// # Arguments
        /// * `token0` - The address of token0 from the LP
        /// * `token1` - The address of token1 from the LP
        /// * `borrow_amount` - The USDC amount to convert into LP
        /// * `swapdata` - The calldata for the leverage (empty if performed on-chain using jedi, sithswap, 10swap, etc.)
        ///
        /// # Returns
        /// * The amount of LP minted
        fn _convert_usd_to_liquidity(
            ref self: ContractState,
            token0: ContractAddress,
            token1: ContractAddress,
            borrow_amount: u128,
            aggregator: Aggregator,
            swapdata: Array<Span<felt252>>
        ) -> u128 {
            /// Fast jediswap quote
            let amount0 = borrow_amount / 2;
            let amount1 = borrow_amount - amount0;

            /// Get stored usdc contract
            let usd = self.usd.read().contract_address;

            /// Convert borrowed usdc to token0 - In case of using AVNU/Fibrous amount0 does not matter
            /// we just pass it for checking allowance and approving if necessary
            if token0 != usd {
                self._swap_tokens_aggregator(usd, token0, amount0.into(), aggregator, *swapdata.at(0));
            }

            /// Convert usdc to token1, same as above, amount1 does not matter for aggregators as the
            /// amount is encoded in the calldata
            if token1 != usd {
                self._swap_tokens_aggregator(usd, token1, amount1.into(), aggregator, *swapdata.at(1));
            }

            /// Receiver of the LP minted is the router as we deposit into collateral after
            let receiver = get_contract_address();
            let bal0 = IERC20Dispatcher { contract_address: token0 }.balanceOf(receiver);
            let bal1 = IERC20Dispatcher { contract_address: token1 }.balanceOf(receiver);

            /// Jediswap router to add liquidity to the pool
            let jediswap_router = self.jediswap_router.read();
            self._approve_token(token0, jediswap_router.contract_address, bal0);
            self._approve_token(token1, jediswap_router.contract_address, bal1);

            /// Mint the LP
            let (_, _, liquidity) = jediswap_router
                .add_liquidity(token0, token1, bal0, bal1, 0, 0, receiver, get_block_timestamp());

            liquidity.try_into().unwrap()
        }
    }

    #[generate_trait]
    impl DeleverageImpl of DeleverageImplTrait {
        /// Repays the borrowable contract and ensures to refund the user of any excess usdc amount left after
        /// deleveraging.
        ///
        /// # Arguments
        /// * `borrowable` - The address of the borrowable
        /// * `token` - The address of the token being refunded (usdc)
        /// * `borrower` - The address of the borrower performing the deleverage
        /// * `amount_max` - The max amount that can be repaid in this transaction
        fn _repay_and_refund(
            ref self: ContractState,
            borrowable: ContractAddress,
            token: ContractAddress,
            borrower: ContractAddress,
            amount_max: u128
        ) {
            /// Borrowable contract
            let borrowable = IBorrowableDispatcher { contract_address: borrowable };

            /// This is the max amount that a user should ever reay so we cap it 
            let amount = self._max_repay_amount(borrowable, amount_max, borrower);

            /// If positive, then send repay amount to the borrowable
            if amount > 0 {
                /// Transfer USDC back to borrowable
                IERC20Dispatcher { contract_address: token }.transfer(borrowable.contract_address, amount.into());
            }

            /// Call `borrow` with 0 borrow_amount to repay and update user's position, pass empty bytes
            borrowable.borrow(borrower, Zeroable::zero(), 0, Default::default());

            /// Refund excess if any (ie. User has $100 in LP and has $80 in borrows. They deleverage $100 of the LP, 
            /// the borrowable contract would have received `amount` which is $80, so this contract now has $20
            /// of usdc to be sent to the borrower)
            if amount_max > amount {
                /// USDC amount held after deleverage
                let refund_amount = amount_max - amount;

                /// Refund back to borrower
                IERC20Dispatcher { contract_address: token }.transfer(borrower, refund_amount.into());
            }
        }

        /// Burns the LP from the liquidity pool and receives token0 and token1 equivalent assets, it then sells
        /// all assets into USDC to repay the loan. This can also be used even if the borrower has no borrows, 
        /// deleveraging will convert all LP into USDC.
        ///
        /// # Arguments
        /// * `redeem_amount` - The amount of LP flash redeemed from the collateral
        /// * `calldata` - The calldata passed for the deleverage (empty if all performed on-chain)
        ///
        /// # Returns
        /// * The amount of USDC received
        #[inline(always)]
        fn _remove_lp_and_repay(ref self: ContractState, redeem_amount: u128, calldata: DeleverageCalldata) -> u128 {
            /// Get underlying LP token for this collateral
            let lp_token = IUniswapV2PairDispatcher { contract_address: calldata.lp_token_pair };

            /// Transfer LP back to the pool to burn
            lp_token.transfer(lp_token.contract_address, redeem_amount.into());

            /// Burn the LP and receive amount0 and amount1 of the underlying LP assets
            let (amount0, amount1) = lp_token.burn(get_contract_address());

            let token0 = lp_token.token0();
            let token1 = lp_token.token1();

            /// Convert all to USDC
            self._convert_liquidity_to_usd(amount0, amount1, token0, token1, calldata.aggregator, calldata.swapdata);

            /// Check that the amount received of USDC after deleveraging is not below min.
            let usd = self.usd.read().contract_address;
            let usd_amount = self._check_balance(usd);

            /// # Error
            /// * `INSUFFICIENT_USD_RECEIVED` - Avoid if is less than min declared
            assert(usd_amount >= calldata.usd_amount_min, Errors::INSUFFICIENT_USD_RECEIVED);

            /// Repay the borrowable contract with the usd received (if necesary) and refund any excess of USDC to the borrower 
            self._repay_and_refund(calldata.borrowable, usd, calldata.recipient, usd_amount);

            /// Transfer CygLP from the borrower to the collateral contract to perform burn
            let collateral = ICollateralDispatcher { contract_address: calldata.collateral };
            collateral.transfer_from(calldata.recipient, collateral.contract_address, calldata.cyg_lp_amount);

            self._clean_dust(token0, token1, calldata.recipient);

            /// Return amount received of USDC, helpful when simulating txns, has no use in core itself
            usd_amount
        }

        /// Inner function to prepare the data to be sent to the aggregators to deleverage
        ///
        /// # Arguments
        /// * `amount0` - Amount of token0 received after burn
        /// * `amount1` - Amount of token1 recieved after burn
        /// * `token0` - The address of token0 from the LP
        /// * `token1` - The address of token1 from the LP
        /// * `swapdata` - The calldata for the deleverage (empty if performed on-chain using jedi, sithswap, 10swap, etc.)
        ///
        /// # Returns
        /// * The amount of USDC received
        fn _convert_liquidity_to_usd(
            ref self: ContractState,
            amount0: u256,
            amount1: u256,
            token0: ContractAddress,
            token1: ContractAddress,
            aggregator: Aggregator,
            swapdata: Array<Span<felt252>>
        ) {
            /// Get stablecoin
            let usd = self.usd.read();

            /// Check if any of the token is already usdc
            if token0 == usd.contract_address || token1 == usd.contract_address {
                /// One is usdc, get the other and swap all to usdc and escape
                let (swap_from, swap_amount, swapdata) = if token0 == usd.contract_address {
                    (token1, amount1, *swapdata.at(1))
                } else {
                    (token0, amount0, *swapdata.at(0))
                };

                /// Swap the other to USDC
                return self._swap_tokens_aggregator(swap_from, usd.contract_address, swap_amount, aggregator, swapdata);
            }

            // Neither are USDC, swap both to USDC
            self._swap_tokens_aggregator(token0, usd.contract_address, amount0, aggregator, *swapdata.at(0));
            self._swap_tokens_aggregator(token1, usd.contract_address, amount1, aggregator, *swapdata.at(1));
        }

        /// TODO
        fn _flash_liquidate(
            ref self: ContractState, cyg_lp_amount: u128, repay_amount: u128, calldata: LiquidateCalldata
        ) -> u128 {
            /// Collateral contract that holds our seized CygLP
            let collateral = ICollateralDispatcher { contract_address: calldata.collateral };

            /// Convert the seized amount of CygLP to LPs
            let redeem_amount = self._convert_to_assets(cyg_lp_amount, collateral);

            /// Flash redeem the LP back to the liquidity pool to call `burn`
            let lp_token = IUniswapV2PairDispatcher { contract_address: calldata.lp_token_pair };
            collateral.flash_redeem(lp_token.contract_address, redeem_amount, Default::default());

            /// Burn the LP and receive amount0 and amount1 of the underlying LP assets
            let (amount0, amount1) = lp_token.burn(get_contract_address());

            /// Convert liquidity burnt to USDC
            self
                ._convert_liquidity_to_usd(
                    amount0, amount1, lp_token.token0(), lp_token.token1(), calldata.aggregator, calldata.swapdata
                );

            /// Manually check the received USDC
            let usd = self.usd.read();
            let usd_received = self._check_balance(usd.contract_address);

            /// # Errors
            /// * `INSUFFICIENT_LIQUIDATED_USD`
            assert(usd_received >= repay_amount, Errors::INSUFFICIENT_LIQUIDATED_USD);

            /// Transfer USD back to borrowable
            usd.transfer(calldata.borrowable, repay_amount.into());

            /// This is positive else we would've reverted by now. This is the liquidation incentive that is sent to the borrower
            /// for liquidating the position.
            usd.transfer(calldata.recipient, (usd_received - repay_amount).into());
            /// TODO - Clean Dust?
            /// TODO - return properly
            10
        }
    }

    /// Logic for handling aggregators and leveraging/deleveraging
    #[generate_trait]
    impl AggregatorsImpl of AggregatorsImplTrait {
        /// Chooses the aggregator from the calldata
        ///
        /// # Arguments
        /// * `token_in` - The address of the token we are swapping
        /// * `token_out` - The address of the token we are receiving
        /// * `aggregator` - Enum representing which aggregator to use
        /// * `amount_in` - The amount of `token_in` we are swapping
        /// * `swapdata` - The swapdata for the aggregator
        fn _swap_tokens_aggregator(
            ref self: ContractState,
            token_in: ContractAddress,
            token_out: ContractAddress,
            amount_in: u256,
            aggregator: Aggregator,
            swapdata: Span<felt252>,
        ) {
            /// Perform the swap with chosen aggregator
            match aggregator {
                Aggregator::AVNU => self._swap_tokens_avnu(token_in, token_out, amount_in, swapdata),
                Aggregator::EKUBO => self._swap_tokens_ekubo(token_in, token_out, amount_in),
                Aggregator::FIBROUS => self._swap_tokens_fibrous(token_in, token_out, amount_in, swapdata),
                Aggregator::JEDISWAP => self._swap_tokens_jediswap(token_in, token_out, amount_in),
            }
        }

        /// Performs the swap with Jediswap's Router (UniV2Router02)
        ///
        /// # Arguments
        /// * `token_in` - The address of the token we are swapping
        /// * `token_out` - The address of the token we are receiving
        /// * `amount_in` - The amount of `token_in` we are swapping
        fn _swap_tokens_jediswap(
            ref self: ContractState, token_in: ContractAddress, token_out: ContractAddress, amount_in: u256
        ) {
            /// Create path of token in to token out
            let path: Array<ContractAddress> = array![token_in, token_out];

            /// Approve router in token_in
            self._approve_token(token_in, self.jediswap_router.read().contract_address, amount_in);

            /// Swap token_in to token_out, min received doesn't matter as we check at the end of leverage/deleverage 
            /// for min LP received (for leverage) or min USDC received (for deleverage)
            self
                .jediswap_router
                .read()
                .swap_exact_tokens_for_tokens(amount_in, 0, path, get_contract_address(), get_block_timestamp());
        }

        /// Performs the swap with Ekubo's Router
        ///
        /// # Arguments
        /// * `token_in` - The address of the token we are swapping
        /// * `token_out` - The address of the token we are receiving
        /// * `amount_in` - The amount of `token_in` we are swapping
        fn _swap_tokens_ekubo(
            ref self: ContractState, token_in: ContractAddress, token_out: ContractAddress, amount_in: u256
        ) {
            /// Read ekubo router from storage
            let ekubo_router = self.ekubo_router.read();

            /// 1. Get optimal `pool_key` given `token_in` and `token_out` (we check which pool has the best quote)
            let pool_key = self._get_optimal_ekubo_pool(token_in, token_out);

            /// 2. Create route and token amounts
            let route_node = RouteNode { pool_key: pool_key, sqrt_ratio_limit: 0, skip_ahead: 0 };
            let token_amount = TokenAmount { token: token_in, amount: i129_new(amount_in.try_into().unwrap(), false) };

            /// 3. Transfer `amount_in` to the router
            IERC20Dispatcher { contract_address: token_in }.transfer(ekubo_router.contract_address, amount_in);

            /// 4. Swap exact amount of `token_in` for `token_out`
            ekubo_router.swap(route_node, token_amount);

            /// 5. Withdraw and receive `token_out`, we check for minimum at the end of the leverage/deleverage call
            ekubo_router.clear(token_out);
        }

        /// Performs the swap with Avnu's Exchange Router
        ///
        /// # Arguments
        /// * `token_in` - The address of the token we are swapping
        /// * `token_out` - The address of the token we are receiving
        /// * `amount_in` - The amount of `token_in` we are swapping
        fn _swap_tokens_avnu(
            ref self: ContractState,
            token_in: ContractAddress,
            token_out: ContractAddress,
            amount_in: u256,
            swapdata: Span<felt252>
        ) {
            /// Get avnu router
            let avnu_exchange = self.avnu_exchange.read();

            /// Approve router in token_in
            self._approve_token(token_in, avnu_exchange, amount_in);

            /// An internal call can’t return Err(_) as this is not handled by the sequencer and the Starknet OS.
            /// If call_contract_syscall fails, this can’t be caught and will therefore result in the entire 
            /// transaction being reverted.
            /// https://book.cairo-lang.org/appendix-07-system-calls.html?highlight=call_contract#call_contract
            call_contract_syscall(avnu_exchange, AVNU_SELECTOR, swapdata).unwrap_syscall();
        }

        /// Performs the swap with Fibrous Router V2
        ///
        /// # Arguments
        /// * `token_in` - The address of the token we are swapping
        /// * `token_out` - The address of the token we are receiving
        /// * `amount_in` - The amount of `token_in` we are swapping
        fn _swap_tokens_fibrous(
            ref self: ContractState,
            token_in: ContractAddress,
            token_out: ContractAddress,
            amount_in: u256,
            swapdata: Span<felt252>
        ) {
            /// Get fibrous router
            let fibrous_router = self.fibrous_router.read();

            /// Approve router in token_in
            self._approve_token(token_in, fibrous_router, amount_in);

            /// An internal call can’t return Err(_) as this is not handled by the sequencer and the Starknet OS.
            /// If call_contract_syscall fails, this can’t be caught and will therefore result in the entire 
            /// transaction being reverted.
            /// https://book.cairo-lang.org/appendix-07-system-calls.html?highlight=call_contract#call_contract
            call_contract_syscall(fibrous_router, FIBROUS_SELECTOR, swapdata).unwrap_syscall();
        }
    }

    #[generate_trait]
    impl HelpersImpl of HelpersImplTrait {
        /// Checks that the call is a delegate call only, reverts if not.
        fn _only_library_call(self: @ContractState) {
            /// # Error 
            /// * `ONLY_DELEGATE_CALL` - Avoid if not called via delegate
            assert(self.my_address.read() != get_contract_address(), 'ONLY DELEGATE CALL')
        }

        /// Checks allowance for a token and a spender to prepare for a swap. Approve max if necessary
        ///
        /// # Arguments
        /// * `token_in` - The token we are swapping
        /// * `spender` - The spender address (jedi router, avnu exchange router, etc.)
        /// * `amount` - The amount of token_in we are swapping
        fn _approve_token(ref self: ContractState, token_in: ContractAddress, spender: ContractAddress, amount: u256) {
            /// Create token disaptcher
            let token = IERC20Dispatcher { contract_address: token_in };

            /// Get current allowance for token of router -> spender
            let allowance = IERC20Dispatcher { contract_address: token_in }.allowance(get_contract_address(), spender);

            /// If more allowance than needed escape
            if allowance >= amount {
                return;
            }

            /// Approve max
            token.approve(spender, integer::BoundedInt::max());
        }

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

        /// Check balance of ERC20 token owned by this contract
        #[inline(always)]
        fn _check_balance(self: @ContractState, contract_address: ContractAddress) -> u128 {
            IERC20Dispatcher { contract_address }.balanceOf(get_contract_address()).try_into().unwrap()
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

        /// Use deadline control for certain borrow/swap actions
        ///
        /// # Arguments
        /// * `deadline` - The maximum timestamp allowed for tx to succeed
        #[inline(always)]
        fn _clean_dust(
            ref self: ContractState, token0: ContractAddress, token1: ContractAddress, recipient: ContractAddress
        ) {
            /// Check token0 and sweep
            let mut balance = self._check_balance(token0);
            if (balance > 0) {
                IERC20Dispatcher { contract_address: token0 }.transfer(recipient, balance.into());
            }

            /// Check token1 and sweep
            balance = self._check_balance(token1);
            if (balance > 0) {
                IERC20Dispatcher { contract_address: token1 }.transfer(recipient, balance.into());
            }

            /// Check for USDC dust
            let usd = self.usd.read().contract_address;
            balance = self._check_balance(usd);
            if (balance > 0) {
                IERC20Dispatcher { contract_address: usd }.transfer(recipient, balance.into());
            }
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

        /// Helpful function to sort through ekubo pools. We skip 1%/2% for gas savings
        ///
        /// # Arguments
        /// * `pool_index` - The index of each pool key
        ///
        /// # Returns
        /// * The fee of the pool at `pool_index`
        /// * The tick spacing of the pool at `pool_index`
        /// * The extension of the pool at `pool_index` (use zero for now)
        fn _get_ekubo_pool(self: @ContractState, pool_index: u32) -> (u128, u128, ContractAddress) {
            /// Index 0 = fee of 0.05% / 0.10% and spacing of 1000
            if pool_index == 0 {
                (170141183460469235273462165868118016, 1000, Zeroable::zero())
            } /// Index 1 = fee of 0.30% / 0.60% and spacing of 5982
            else if pool_index == 1 {
                (1020847100762815411640772995208708096, 5982, Zeroable::zero())
            } /// Index 2 = fee of 0.01% / 0.02% and spacing of 200
            else {
                (34028236692093847977029636859101184, 200, Zeroable::zero())
            }
        }

        /// Helpful function to swap in Ekubo
        ///
        /// # Arguments
        /// * `borrowable` - The address of the borrowable
        /// * `amount_max` - The amount user wants to repay
        /// * `borrower` - The address of the borrower
        ///
        /// # Returns
        /// * The maximum amount that user should repay
        fn _get_optimal_ekubo_pool(self: @ContractState, token0: ContractAddress, token1: ContractAddress) -> PoolKey {
            /// Read ekubo core from storage
            let ekubo_core = self.ekubo_core.read();

            /// Sort tokens if needed
            let (token0, token1) = if token1 < token0 {
                (token1, token0)
            } else {
                (token0, token1)
            };

            /// We try to find the pool with the highest liquidity to filter out dead pools. 
            /// Not sure if we should use Ekubo's `quote` function on-chain (?)

            /// Get ekubo pool at index 0
            let (fee, tick_spacing, extension) = self._get_ekubo_pool(0);
            /// Create pool key with fee and tick spacing at index 0
            let mut optimal_pool_key: PoolKey = PoolKey { token0, token1, fee, tick_spacing, extension };
            /// Cache max liquidity at pool 0
            let mut max_liquidity = ekubo_core.get_pool_liquidity(optimal_pool_key);

            /// Start from index 1
            let mut len = 1;

            loop {
                /// Break
                if len == 3 {
                    break;
                };

                /// Get ekubo pool at index `len`
                let (fee, tick_spacing, extension) = self._get_ekubo_pool(len);
                /// Create pool key with fee and tick spacing at index `len`
                let pool_key: PoolKey = PoolKey { token0, token1, fee, tick_spacing, extension };
                /// Get this pool's liquidity
                let liquidity = ekubo_core.get_pool_liquidity(pool_key);

                /// Cache max liquidity and pool key if needed
                if liquidity > max_liquidity {
                    max_liquidity = liquidity;
                    optimal_pool_key = pool_key;
                };

                /// Next iteration
                len += 1;
            };

            optimal_pool_key
        }
    }
}

