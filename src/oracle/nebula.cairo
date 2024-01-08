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
//       PRAGMA LP ORACLE - https://cygnusdao.finance                                                          .                     .
//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════

/// # Title
/// * `CygnusNebula`
///
/// # Description
/// * Prices Constant Product AMM LPs (ie. UniV2)
///
/// # Author
/// * CygnusDAO
use starknet::ContractAddress;
use cygnus::oracle::pragma_interface::{DataType};
use cygnus::data::nebula::{LPInfo, NebulaOracle};

#[starknet::interface]
trait ICygnusNebula<TState> {
    /// Name of the LP Oracle (ie. UniswapV2, UniswapV3, etc.)
    fn name(self: @TState) -> felt252;

    /// Address of the registry, the owner of this oracle
    fn nebula_registry(self: @TState) -> ContractAddress;

    /// Decimals that this oracle uses
    fn decimals(self: @TState) -> u8;

    /// Returns the price of the 1 LP token denominated in the underlying
    fn lp_token_price(self: @TState, lp_token_pair: ContractAddress) -> u128;

    /// Initializes oracle, only callable from nebula registry
    fn initialize_oracle(ref self: TState, lp_token_pair: ContractAddress, price_feed0: felt252, price_feed1: felt252);

    /// Returns the price of an asset from Pragma Oracle
    fn get_asset_price(self: @TState, asset: DataType) -> u128;

    /// Returns the denomination token price
    fn denomination_token_price(self: @TState) -> u128;

    /// Returns LP Info, reporting
    fn lp_token_info(self: @TState, lp_token_pair: ContractAddress) -> LPInfo;

    /// Mapping of LP address => Oracle struct
    fn get_nebula_oracle(self: @TState, lp_token_pair: ContractAddress) -> NebulaOracle;

    /// Mapping of Oracle ID => Oracle struct
    fn all_oracles(self: @TState, oracle_id: u8) -> NebulaOracle;
}

#[starknet::contract]
mod CygnusNebula {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::ICygnusNebula;
    use cygnus::token::univ2pair::{IUniswapV2PairDispatcher, IUniswapV2PairDispatcherTrait};
    use cygnus::registry::registry::{INebulaRegistryDispatcher, INebulaRegistryDispatcherTrait};
    use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use cygnus::oracle::pragma_interface::{IOracleABIDispatcher, IOracleABIDispatcherTrait, AggregationMode, DataType};

    /// # Libraries
    use cygnus::libraries::full_math_lib::FullMathLib::FixedPointMathLibTrait;

    use integer::{u128_sqrt};
    use cygnus::data::nebula::{LPInfo};

    /// # Imports
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, contract_address_const};
    use cygnus::data::nebula::{NebulaOracle};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Events
    /// * `NewLPOracle` - Logs when a new LP oracle is set
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewLPOracle: NewLPOracle,
    }

    /// # Event
    /// * `NewLPOracle`
    #[derive(Drop, starknet::Event)]
    struct NewLPOracle {
        lp_token_pair: ContractAddress
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Storage
    #[storage]
    struct Storage {
        name: felt252,
        decimals: u8,
        symbol: felt252,
        nebula_registry: INebulaRegistryDispatcher,
        denomination_token: IERC20Dispatcher,
        pragma_oracle: IOracleABIDispatcher,
        nebula_oracles: LegacyMap<ContractAddress, NebulaOracle>,
        all_oracles: LegacyMap<u8, NebulaOracle>,
        total_oracles: u8
    }


    /// The denomination price feed. To replace just replace `USDC` with other supported asset by Pragma
    /// and replace `DENOMINATION_SCALAR` with the correct asset scalar (ie. The price feed returns the price
    /// of the asset in 6 decimals, so denom scalar is 10 ** (18 -6))
    const DENOMINATION_PRICE_FEED: felt252 = 'USDC/USD';

    /// 8 is the decimals used by Pragma oracles for all SPOT price feeds
    const AGGREGATOR_SCALAR: u128 = 10000000000; // 10 ** (18 - 8)

    /// The scalar of the decimals used by Pragma for the DENOMINATION_PRICE_FEED
    const DENOMINATION_PRICE_SCALAR: u128 = 1000000000000; // 10 ** (18 - 6)

    // LP scalar to simplify getting the price of the LP
    const LP_SCALAR: u128 = 2_000000000_000000000;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(
        ref self: ContractState, denomination_token: IERC20Dispatcher, nebula_registry: INebulaRegistryDispatcher,
    ) {
        /// The oracle registry, basically owner of this contract that initializes oracles
        self.nebula_registry.write(nebula_registry);

        /// The ERC20 token that prices are denominated in
        self.denomination_token.write(denomination_token);

        /// Decimals of the price
        self.decimals.write(denomination_token.decimals());

        /// Pragma oracle on mainnet
        self
            .pragma_oracle
            .write(
                IOracleABIDispatcher {
                    contract_address: contract_address_const::<
                        0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b
                    >()
                }
            );
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl NebulaImpl of ICygnusNebula<ContractState> {
        /// # Implementation
        /// * ICygnusNebula
        fn name(self: @ContractState) -> felt252 {
            'Cygnus Nebula: Jediswap'
        }

        /// # Implementation
        /// * ICygnusNebula
        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        /// # Implementation
        /// * ICygnusNebula
        fn lp_token_price(self: @ContractState, lp_token_pair: ContractAddress) -> u128 {
            /// Get oracle from storage
            let oracle = self.nebula_oracles.read(lp_token_pair);

            /// # Error
            /// * `LP_ORACLE_NOT_INITIALIZED`
            assert(oracle.initialized, 'oracle_not_initialized');

            /// Get the price of token0 and token1 from the oracle struct
            let price0 = self._token_price(oracle.price_feed0);
            let price1 = self._token_price(oracle.price_feed1);

            /// Compute the USD value of each token in the pool in 18 decimals (price[i] * reserves[i])
            let (res0, res1, _) = IUniswapV2PairDispatcher { contract_address: lp_token_pair }.get_reserves();
            let value0 = price0.full_mul_div(res0.try_into().unwrap(), oracle.token0_decimals.into());
            let value1 = price1.full_mul_div(res1.try_into().unwrap(), oracle.token1_decimals.into());

            /// Get total supply of LPs
            let supply = IUniswapV2PairDispatcher { contract_address: lp_token_pair }.totalSupply();

            /// LP Price USD = (2 * sqrt(value0 * value1)) / totalSupply
            let lp_price_usd = LP_SCALAR.full_mul_div(value0.gm(value1), supply.try_into().unwrap());

            /// Return the price of the LP expressed in the denomination token (in our case, USDC, so 6 decimals)
            let denom_price = self._denomination_price();

            lp_price_usd.div_wad(denom_price * DENOMINATION_PRICE_SCALAR)
        }

        /// # Implementation
        /// * ICygnusNebula
        fn nebula_registry(self: @ContractState) -> ContractAddress {
            self.nebula_registry.read().contract_address
        }

        /// # Implementation
        /// * ICygnusNebula
        fn lp_token_info(self: @ContractState, lp_token_pair: ContractAddress) -> LPInfo {
            /// Get oracle from storage
            let oracle = self.nebula_oracles.read(lp_token_pair);

            /// # Error
            /// * `LP_ORACLE_NOT_INITIALIZED`
            assert(oracle.initialized, 'oracle_not_initialized');

            /// Get the price of token0 and token1 from the oracle struct, 18 decimals
            let price0 = self._token_price(oracle.price_feed0);
            let price1 = self._token_price(oracle.price_feed1);

            /// Get the reserves
            let (res0, res1, _) = IUniswapV2PairDispatcher { contract_address: lp_token_pair }.get_reserves();

            /// USD value of each token in the LP
            let value0 = price0.full_mul_div(res0.try_into().unwrap(), oracle.token0_decimals.into());
            let value1 = price1.full_mul_div(res1.try_into().unwrap(), oracle.token1_decimals.into());

            LPInfo {
                token0: oracle.token0,
                token1: oracle.token1,
                token0_price: price0,
                token1_price: price1,
                token0_reserves: res0.try_into().unwrap(),
                token1_reserves: res1.try_into().unwrap(),
                token0_decimals: oracle.token0_decimals,
                token1_decimals: oracle.token1_decimals,
                reserves0_usd: value0,
                reserves1_usd: value1
            }
        }

        /// # Implementation
        /// * ICygnusNebula
        fn all_oracles(self: @ContractState, oracle_id: u8) -> NebulaOracle {
            self.all_oracles.read(oracle_id)
        }

        /// # Implementation
        /// * ICygnusNebula
        fn get_nebula_oracle(self: @ContractState, lp_token_pair: ContractAddress) -> NebulaOracle {
            /// Read lp token pair from storage
            let oracle = self.nebula_oracles.read(lp_token_pair);

            /// # Error
            /// * `LP_ORACLE_NOT_INITIALIZED`
            assert(oracle.initialized, 'oracle_not_initialized');

            oracle
        }


        /// # Implementation
        /// * ICygnusNebula
        fn initialize_oracle(
            ref self: ContractState, lp_token_pair: ContractAddress, price_feed0: felt252, price_feed1: felt252
        ) {
            /// Check sender
            self._check_registry();

            /// Get oracle for `lp_token_pair`
            let mut lp_oracle: NebulaOracle = self.nebula_oracles.read(lp_token_pair);

            /// # Error
            /// * ALREADY_INIT - Revert if already initialized
            assert(!lp_oracle.initialized, 'already_init');

            // Create dispatcher and unique oracle id
            let lp_token_pair = IUniswapV2PairDispatcher { contract_address: lp_token_pair };
            let oracle_id = self.total_oracles.read();

            /// Mark as true, cannot be set again
            lp_oracle.initialized = true;

            /// Assign unique oracle id
            lp_oracle.oracle_id = oracle_id;

            /// Name of the LP (Jediswap BTC/DAI or whatever it uses)
            lp_oracle.name = lp_token_pair.name();

            /// Underlying lp token address
            lp_oracle.underlying = lp_token_pair.contract_address;

            /// Token0 and Token1 
            lp_oracle.token0 = lp_token_pair.token0();
            lp_oracle.token1 = lp_token_pair.token1();

            /// Price feeds of token0 and token1
            lp_oracle.price_feed0 = price_feed0;
            lp_oracle.price_feed1 = price_feed1;

            let decimals0 = IERC20Dispatcher { contract_address: lp_token_pair.token0() }.decimals();
            let decimals1 = IERC20Dispatcher { contract_address: lp_token_pair.token1() }.decimals();

            /// Store decimals
            lp_oracle.token0_decimals = 10_u128.pow(decimals0.into()).try_into().unwrap();
            lp_oracle.token1_decimals = 10_u128.pow(decimals1.into()).try_into().unwrap();

            /// Creation timestamp - This is used in case admin needs to reset the oracle feeds. This can only be done
            /// within 1 hour maximum of the creation timestamp, avoid human errors
            lp_oracle.created_at = get_block_timestamp();

            /// Write oracle to storage mapping and array
            self.nebula_oracles.write(lp_token_pair.contract_address, lp_oracle);
            self.all_oracles.write(oracle_id, lp_oracle);

            /// Increase oracle count
            self.total_oracles.write(oracle_id + 1);

            /// # Event
            /// * `NewLPOracle`
            self.emit(NewLPOracle { lp_token_pair: lp_token_pair.contract_address });
        }

        /// # Implementation
        /// * ICygnusNebula
        fn get_asset_price(self: @ContractState, asset: DataType) -> u128 {
            self.pragma_oracle.read().get_data_median(asset).price
        }

        /// # Implementation
        /// * ICygnusNebula
        fn denomination_token_price(self: @ContractState) -> u128 {
            self._denomination_price()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Internal check to reverts if caller is not registry
        fn _check_registry(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.nebula_registry.read().contract_address, 'wrong caller');
        }

        /// Gets a token's price from pragma internally
        ///
        /// # Arguments
        /// * `token_feed` - The id for this token, ie. 'ETH/USD'
        ///
        /// # Returns
        /// * The price of the token in 18 decimals
        fn _token_price(self: @ContractState, token_feed: felt252) -> u128 {
            /// DataType of asset for Pragma
            let asset = DataType::SpotEntry(token_feed);

            /// Only USDC and USDT use 6 decimals, use this to avoid having to exp the decimals
            if token_feed == 'USDC/USD' || token_feed == 'USDT/USD' {
                return self.pragma_oracle.read().get_data_median(asset).price * DENOMINATION_PRICE_SCALAR;
            }

            /// Normal scalar
            self.pragma_oracle.read().get_data_median(asset).price * AGGREGATOR_SCALAR
        }

        /// Gets a the denomination's price from pragma internally, gas savings
        ///
        /// # Returns
        /// * The price of the denomination token (in our case USDC) in 18 decimals
        fn _denomination_price(self: @ContractState) -> u128 {
            /// DataType of asset for Pragma
            let asset = DataType::SpotEntry(DENOMINATION_PRICE_FEED);

            /// Price of denom in 18 decimals
            self.pragma_oracle.read().get_data_median(asset).price * DENOMINATION_PRICE_SCALAR
        }
    }
}
