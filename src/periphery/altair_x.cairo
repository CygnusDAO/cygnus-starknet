//! Periphery

// Libraries
use starknet::ContractAddress;
use cygnus::data::altair::{ShuttleInfoC, ShuttleInfoB, BorrowerPosition};
use cygnus::data::calldata::{LeverageCalldata, DeleverageCalldata, Aggregator};

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
    fn altair_borrow_09E(ref self: T, sender: ContractAddress, borrow_amount: u128, calldata: LeverageCalldata) -> u128;

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
    fn altair_redeem_u91A(
        ref self: T, sender: ContractAddress, redeem_amount: u128, calldata: DeleverageCalldata
    ) -> u128;

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
        ref self: T, sender: ContractAddress, cyg_lp_amount: u128, repay_amount: u128, calldata: DeleverageCalldata
    );
}

/// # Module - AltairX
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

    /// # Libraries
    use cygnus::libraries::full_math_lib::FullMathLib::FixedPointMathLibTrait;
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, get_block_timestamp, contract_address_const,
        call_contract_syscall
    };

    /// # Errors
    use cygnus::periphery::errors::AltairErrors as Errors;

    /// # Data
    use cygnus::data::{
        shuttle::{Shuttle}, calldata::{LeverageCalldata, DeleverageCalldata, Aggregator},
        altair::{ShuttleInfoC, ShuttleInfoB, BorrowerPosition}
    };

    /// Aggregators
    use cygnus::periphery::integrations::jediswap_router::{IJediswapRouterDispatcher, IJediswapRouterDispatcherTrait};

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
        extensions: LegacyMap<ContractAddress, ContractAddress>,
        /// Array of extensions
        all_extensions: LegacyMap<u32, ContractAddress>,
        /// Mapping to check if extension exists
        is_extension: LegacyMap<ContractAddress, bool>,
        /// Avnu
        avnu_exchange: ContractAddress,
        /// Fibrous
        fibrous_router: ContractAddress,
        /// Jediswap for on-chain swaps
        jediswap_router: IJediswapRouterDispatcher
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
    fn constructor(ref self: ContractState, hangar18: IHangar18Dispatcher) {
        // Get native and usd from factory
        let native_token = IERC20Dispatcher { contract_address: hangar18.native_token() };
        let usd = IERC20Dispatcher { contract_address: hangar18.usd() };

        // Store factory and dispatchers
        self.hangar18.write(hangar18);
        self.usd.write(usd);
        self.native_token.write(native_token);

        /// AVNU ROUTER
        self
            .avnu_exchange
            .write(contract_address_const::<0x4270219d365d6b017231b52e92b3fb5d7c8378b05e9abc97724537a80e93b0f>());

        /// FIBROUS ROUTER
        self
            .fibrous_router
            .write(contract_address_const::<0x00f6f4CF62E3C010E0aC2451cC7807b5eEc19a40b0FaaCd00CCA3914280FDf5a>());

        let jediswap_router = IJediswapRouterDispatcher {
            contract_address: contract_address_const::<
                0x041fd22b238fa21cfcf5dd45a8548974d8263b3a531a60388411c5e230f97023
            >()
        };

        self.jediswap_router.write(jediswap_router);
    }

    /// -------------------------------------------------------------------------------------------------------
    ///     5. IMPLEMENTATION
    /// -------------------------------------------------------------------------------------------------------

    #[abi(embed_v0)]
    impl AltairXImpl of IAltairX<ContractState> {
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

        /// LEVERAGE -------------------------------------------------

        /// # Implementation
        /// * IAltair
        fn altair_borrow_09E(
            ref self: ContractState, sender: ContractAddress, borrow_amount: u128, calldata: LeverageCalldata
        ) -> u128 {
            /// # Error
            /// * `WRONG_SENDER`
            assert(sender == get_contract_address(), Errors::SENDER_NOT_ROUTER);

            /// # Error TODO
            /// * `NOT_BORROWABLE` - Avoid if caller is not borrowable
            ///assert(get_caller_address() == calldata.borrowable, Errors::CALLER_NOT_BORROWABLE);

            /// By now this contract has USDC that were flash borrowed from the collateral. Convert all USDC into
            /// more LP and deposit back in collateral, minting CygLP to the receiver. Borrowable contract does
            /// check at the end that the collateral amount by the borrower is sufficient for the loan.
            self._mint_lp_and_deposit(borrow_amount, calldata)
        }

        /// # Implementation
        /// * IAltair
        fn altair_redeem_u91A(
            ref self: ContractState, sender: ContractAddress, redeem_amount: u128, calldata: DeleverageCalldata
        ) -> u128 {
            /// # Error
            /// * `WRONG_SENDER`
            assert(sender == get_contract_address(), Errors::SENDER_NOT_ROUTER);

            /// # Error TODO
            /// * `NOT_COLLATERAL` - Avoid if caller is not collateral
            ///assert(get_caller_address() == calldata.collateral, Errors::CALLER_NOT_COLLATERAL);

            /// By now this contract has LPs that were flash redeemed from collateral. Burn the LP, receive
            /// token0 and token1 assets, convert to USDC, repay loan or part of the loan. Collateral contract
            /// is expecting an equivalent amount of the LP redeemed in CygLP, transfer from borrower to collateral
            /// and burn the CygLP.
            self._remove_lp_and_repay(redeem_amount, calldata)
        }

        /// # Implementation
        /// * IAltair
        fn altair_liquidate_f2x(
            ref self: ContractState,
            sender: ContractAddress,
            cyg_lp_amount: u128,
            repay_amount: u128,
            calldata: DeleverageCalldata
        ) {
            /// # Error
            /// * `WRONG_SENDER`
            assert(sender == get_contract_address(), 'wrong_sender');

            /// # Error TODO
            /// * `NOT_BORROWABLE` - Avoid if caller is not borrowable
            ///assert(get_caller_address() == calldata.borrowable, 'not_borrowable');

            /// By now this contract has LPs that were flash redeemed from collateral. Burn the LP, receive
            /// token0 and token1 assets, convert to USDC, repay loan or part of the loan. Collateral contract
            /// is expecting an equivalent amount of the LP redeemed in CygLP, transfer from borrower to collateral
            /// and burn the CygLP.
            self._flash_liquidate(cyg_lp_amount, repay_amount, calldata)
        }
    }

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

            /// Return LP Minted - useful for static calls, simulate tx, etc. has no use otherwise
            liquidity
        }

        /// Check for dust and send to LP recipient
        /// self._clean_dust(token0, token1, left_over_bal0, left_over_bal1, calldata.recipient);

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
            /// Fast quote
            let amount0 = borrow_amount / 2;
            let amount1 = borrow_amount - amount0;

            /// Get stored usdc contract
            let usd = self.usd.read().contract_address;

            /// Actual amount0 does not matter as it's encoded in the swapdata, it's used for checking allowance
            if token0 != usd {
                self._swap_tokens_aggregator(usd, token0, amount0.into(), aggregator, *swapdata.at(0));
            }

            /// Amount1 doesnt matter
            if token1 != usd {
                self._swap_tokens_aggregator(usd, token1, amount1.into(), aggregator, *swapdata.at(1));
            }

            /// Jediswap router to add liquidity to the pool
            let jediswap_router = self.jediswap_router.read();

            /// Receiver of the LP minted is the router as we deposit into collateral after
            let receiver = get_contract_address();
            let bal0 = IERC20Dispatcher { contract_address: token0 }.balanceOf(receiver);
            let bal1 = IERC20Dispatcher { contract_address: token1 }.balanceOf(receiver);

            /// Approve Jediswap router in token_in
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

            /// Convert all to USDC - TODO CLEAN DUST?
            self
                ._convert_liquidity_to_usd(
                    amount0, amount1, lp_token.token0(), lp_token.token1(), calldata.aggregator, calldata.swapdata
                );

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

        fn _flash_liquidate(
            ref self: ContractState, cyg_lp_amount: u128, repay_amount: u128, calldata: DeleverageCalldata
        ) {
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
        }
    }

    /// Logic for handling aggregators and leveraging/deleveraging
    #[generate_trait]
    impl AggregatorsImpl of AggregatorsImplTrait {
        /// Performs the swap with Jediswap's Router (UniV2Router02)
        ///
        /// # Arguments
        /// * `token_in` - The address of the token we are swapping
        /// * `token_out` - The address of the token we are receiving
        /// * `amount_in` - The amount of `token_in` we are swapping
        fn _swap_tokens_jediswap(
            ref self: ContractState, token_in: ContractAddress, token_out: ContractAddress, amount_in: u256
        ) {
            /// Get native token (ie. WETH)
            let native_token = self.native_token.read().contract_address;

            /// Swap token_in to token_out
            let receiver = get_contract_address();
            let deadline = get_block_timestamp();

            /// Always bridge through naitve token first if necessary. Checks if both token_in AND token_out are not 
            /// native and adds extra path if necesary.
            let path: Array<ContractAddress> = if token_in != native_token && token_out != native_token {
                array![token_in, native_token, token_out]
            } else {
                array![token_in, token_out]
            };

            /// Approve router in token_in
            self._approve_token(token_in, self.jediswap_router.read().contract_address, amount_in);

            /// Swap token_in to token_out
            self.jediswap_router.read().swap_exact_tokens_for_tokens(amount_in, 0, path, receiver, deadline);
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

            /// Swap
            call_contract_syscall(avnu_exchange, AVNU_SELECTOR, swapdata);
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

            /// Swap
            call_contract_syscall(fibrous_router, FIBROUS_SELECTOR, swapdata);
        }

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
                Aggregator::NONE => (()),
                Aggregator::AVNU => self._swap_tokens_avnu(token_in, token_out, amount_in, swapdata),
                Aggregator::FIBROUS => self._swap_tokens_fibrous(token_in, token_out, amount_in, swapdata),
                Aggregator::JEDISWAP => self._swap_tokens_jediswap(token_in, token_out, amount_in),
            }
        }
    }

    #[generate_trait]
    impl HelpersImpl of HelpersImplTrait {
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
            let allowance = token.allowance(get_contract_address(), spender);

            /// If more allowance than needed escape
            if allowance >= amount.into() {
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

        /// Check balance of ERC20 token
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
