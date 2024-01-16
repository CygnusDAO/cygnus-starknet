use starknet::ContractAddress;
use cygnus::data::registry::{Nebula};
use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
use cygnus::data::nebula::{LPInfo};
use array::ArrayTrait;

/// Interface - Oracle Registry
#[starknet::interface]
trait INebulaRegistry<T> {
    /// ─────────────────────────────── CONSTANT FUNCTIONS ───────────────────────────────────

    /// # Returns
    /// * The address of the registry admin, only one that can initialize oracles
    fn admin(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of the pending admin (can be zero)
    fn pending_admin(self: @T) -> ContractAddress;

    /// # Returns
    /// * The total amounts of oracle logics (nebulas) we have
    fn all_nebulas_length(self: @T) -> u32;

    /// # Returns
    /// * The total amount of LPs we are tracking
    fn all_lp_tokens_length(self: @T) -> u32;

    /// IMPORTANT: Do not use this price as it does no safety checks if the aggregators fail.
    ///            This is only kept here for reporting purposes.
    ///
    /// # Arguments
    /// * `lp_token_pair` - The address of the LP token
    ///
    /// # Returns
    /// * The price of the lp token (gets the nebula for the LP, and calls `lp_token_price_usd`)
    fn get_lp_token_price_usd(self: @T, lp_token_pair: ContractAddress) -> u128;

    /// # Arguments
    /// * `nebula_address` - The address of the nebula implementation
    ///
    /// # Returns
    /// * The nebula struct given the nebula address
    fn get_nebula(self: @T, nebula_address: ContractAddress) -> Nebula;

    /// # Arguments
    /// * `lp_token_pair` - The address of the LP token
    ///
    /// # Returns
    /// * The nebula struct given an LP token pair (if we are tracking it)
    fn get_lp_token_nebula(self: @T, lp_token_pair: ContractAddress) -> Nebula;

    /// This is used by the factory to deploy pools as it's more gas efficient
    ///
    /// # Arguments
    /// * `lp_token_pair` - The address of the LP token
    ///
    /// # Returns
    /// * The nebula address given an LP Token pair
    fn get_lp_token_nebula_address(self: @T, lp_token_pair: ContractAddress) -> ContractAddress;

    /// Gets a quick overview of the LP Token
    ///
    /// # Arguments
    /// * `lp_token_pair` - The address of the LP Token
    ///
    /// # Returns
    /// * Array of all token addresses that compose the LP
    /// * Array of the reserves of each token in the LP
    /// * Array of decimals of each token in the LP
    /// * Array of prices of each token in the LP
    fn get_lp_token_info(self: @T, lp_token_pair: ContractAddress) -> LPInfo;

    /// Array of nebulas
    ///
    /// # Arguments
    /// * `nebula_id` - The unique ID of a nebula
    ///
    /// # Returns
    /// * The Nebula struct for this `nebula_id`
    fn all_nebulas(self: @T, nebula_id: u32) -> Nebula;

    /// ───────────────────────────── NON-CONSTANT FUNCTIONS ─────────────────────────────────

    /// Stores a new nebula logic in this registry and assigns it a unique ID.
    /// The nebula logic is basically an oracle that prices specific lp tokens such as 
    /// Balancer's BPT Weighted Pools or UniswapV2 pools.
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `nebula_address` - The address of the new nebula
    fn create_nebula(ref self: T, nebula_address: ContractAddress);

    /// Adds an LP oracle to a nebula in the registry. Only the registry can initialize
    /// Nebulas and Oracles. If an oracle for an LP is not set, then pools cannot be deployed
    /// as collaterals cannot be priced.
    ///
    /// # Security
    /// * Only-admin
    /// 
    /// # Arguments
    /// * `nebula_id` - The unique ID of the nebula where we are initializing the oracle
    /// * `lp_token_pair` - The address of the LP Token
    /// * `price_feeds` - Array of price feeds for each token in the LP
    /// * `is_override` - Whether we are overriding an already existing LP oracle for future pools.
    fn create_nebula_oracle(
        ref self: T,
        nebula_id: u32,
        lp_token_pair: ContractAddress,
        price_feed0: felt252,
        price_feed1: felt252,
        is_override: bool
    );

    /// Sets a new pending admin, for them to accept and transfer ownership of this registry
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_pending` - The address of the new pending admin
    fn set_pending_admin(ref self: T, new_pending: ContractAddress);

    /// Pending admin accepts ownership of the registry
    ///
    /// # Security
    /// * Only-pending-admin
    fn accept_admin(ref self: T);
}

#[starknet::contract]
mod NebulaRegistry {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::INebulaRegistry;
    use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};

    /// # Libraries
    use starknet::{get_contract_address, ContractAddress, get_caller_address, get_block_timestamp};

    /// # Errors
    use cygnus::registry::errors::RegistryErrors;

    /// # Data
    use cygnus::data::registry::{Nebula};
    use cygnus::data::nebula::{LPInfo};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Events
    /// * `NewPendingAdmin` - Emitted when a new pending admin for the registry is set 
    /// * `NewAdmin` - Emitted when pending admin accepts admin role
    /// * `NewNebula` - Emitted when a new nebula implementation is set
    /// * `NewOracle` - Emitted when a new LP Token oracle is set in the nebula and this registry
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewPendingAdmin: NewPendingAdmin,
        NewAdmin: NewAdmin,
        NewNebula: NewNebula,
        NewOracle: NewOracle
    }

    /// # Event
    /// * `NewPendingAdmin`
    #[derive(Drop, starknet::Event)]
    struct NewPendingAdmin {
        old_pending: ContractAddress,
        new_pending: ContractAddress
    }

    /// # Event
    /// * `NewAdmin`
    #[derive(Drop, starknet::Event)]
    struct NewAdmin {
        old_admin: ContractAddress,
        new_admin: ContractAddress
    }

    /// # Event
    /// * `NewNebula`
    #[derive(Drop, starknet::Event)]
    struct NewNebula {
        name: felt252,
        nebula_id: u32,
        nebula_address: ContractAddress,
        created_at: u64
    }

    /// # Event
    /// * `NewOracle`
    #[derive(Drop, starknet::Event)]
    struct NewOracle {
        nebula_id: u32,
        lp_token_pair: ContractAddress
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        name: felt252,
        version: felt252,
        admin: ContractAddress,
        pending_admin: ContractAddress,
        lp_nebulas: LegacyMap::<ContractAddress, ContractAddress>,
        nebulas: LegacyMap::<ContractAddress, Nebula>,
        all_nebulas: LegacyMap::<u32, Nebula>,
        total_nebulas: u32,
        all_lp_oracles: LegacyMap::<u32, ContractAddress>,
        total_lp_oracles: u32,
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        // Assign registry admin
        self.admin.write(admin);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl RegistryImpl of INebulaRegistry<ContractState> {
        /// # Implementation
        /// * INebulaRegistry
        fn admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        /// # Implementation
        /// * INebulaRegistry
        fn pending_admin(self: @ContractState) -> ContractAddress {
            self.pending_admin.read()
        }

        /// # Implementation
        /// * INebulaRegistry
        fn all_nebulas_length(self: @ContractState) -> u32 {
            self.total_nebulas.read()
        }

        /// # Implementation
        /// * INebulaRegistry
        fn all_lp_tokens_length(self: @ContractState) -> u32 {
            self.total_lp_oracles.read()
        }

        /// # Implementation
        /// * INebulaRegistry
        fn all_nebulas(self: @ContractState, nebula_id: u32) -> Nebula {
            self.all_nebulas.read(nebula_id)
        }

        /// # Implementation
        /// * INebulaRegistry
        fn get_nebula(self: @ContractState, nebula_address: ContractAddress) -> Nebula {
            // get the nebula for the nebula address
            self.nebulas.read(nebula_address)
        }

        /// # Implementation
        /// * INebulaRegistry
        fn get_lp_token_nebula(self: @ContractState, lp_token_pair: ContractAddress) -> Nebula {
            // Get the nebula address for an LP token
            let nebula_address = self.lp_nebulas.read(lp_token_pair);

            // Return nebula struct
            self.nebulas.read(nebula_address)
        }

        /// # Implementation
        /// * INebulaRegistry
        fn get_lp_token_nebula_address(self: @ContractState, lp_token_pair: ContractAddress) -> ContractAddress {
            // Get the nebula address for the lp token - This is more gas efficient to be used in factory
            self.lp_nebulas.read(lp_token_pair)
        }

        /// # Implementation
        /// * INebulaRegistry
        fn get_lp_token_price_usd(self: @ContractState, lp_token_pair: ContractAddress) -> u128 {
            // Get the nebula implementation for this LP Token
            let nebula = self.lp_nebulas.read(lp_token_pair);

            // Return price from oracle
            ICygnusNebulaDispatcher { contract_address: nebula }.lp_token_price(lp_token_pair)
        }

        /// # Implementation
        /// * INebulaRegistry
        fn get_lp_token_info(self: @ContractState, lp_token_pair: ContractAddress) -> LPInfo {
            /// Read nebula for this LP
            let nebula = self.lp_nebulas.read(lp_token_pair);

            /// Return price from oracle
            ICygnusNebulaDispatcher { contract_address: nebula }.lp_token_info(lp_token_pair)
        }

        /// ───────────────────────────── NON-CONSTANT FUNCTIONS ─────────────────────────────────

        /// # Implementation
        /// * INebulaRegistry
        fn create_nebula_oracle(
            ref self: ContractState,
            nebula_id: u32,
            lp_token_pair: ContractAddress,
            price_feed0: felt252,
            price_feed1: felt252,
            is_override: bool
        ) {
            // Check admin
            self.check_admin();

            // Get the nebula for this ID
            let mut nebula: Nebula = self.all_nebulas.read(nebula_id);

            /// Will revert if we are past grace period
            ICygnusNebulaDispatcher { contract_address: nebula.nebula_address }
                .initialize_oracle(lp_token_pair, price_feed0, price_feed1);

            // If the mapping for the lp token pair returns 0, then increase total lp oracles by 1
            // We leave this here to overwrite in case need fix
            if self.lp_nebulas.read(lp_token_pair) == Zeroable::zero() {
                // Increase total oracles by 1
                self.total_lp_oracles.write(self.total_lp_oracles.read() + 1)
            }

            // Update oracles deployed with this nebula
            if !is_override {
                nebula.total_oracles += 1;
            }

            // Write to storage (or overwrite) the mapping of: LP Token => Nebula address
            self.lp_nebulas.write(lp_token_pair, nebula.nebula_address);

            // Write to storage (or overwrite) the mapping of: Nebula address => Nebula struct
            self.nebulas.write(nebula.nebula_address, nebula);
            self.all_nebulas.write(nebula_id, nebula);

            /// # Event
            /// `NewOracle`
            self.emit(NewOracle { nebula_id, lp_token_pair });
        }

        /// # Security
        /// * `only_admin`
        ///
        /// # Implementation
        /// * INebulaRegistry
        fn create_nebula(ref self: ContractState, nebula_address: ContractAddress) {
            // Only admin
            self.check_admin();

            /// # Error
            /// * `ALREADY_CREATED` - Reverts if nebula is already created
            assert(self.nebulas.read(nebula_address).created_at == 0, RegistryErrors::ALREADY_CREATED);

            // Get unique ID
            let nebula_id: u32 = self.total_nebulas.read();

            // Get human friendly name for the nebula
            let name: felt252 = ICygnusNebulaDispatcher { contract_address: nebula_address }.name();

            // Get timestamp
            let created_at: u64 = get_block_timestamp();

            // Create nebula
            let nebula: Nebula = Nebula { name, nebula_address, nebula_id, total_oracles: 0, created_at };

            // Store in `array`
            self.all_nebulas.write(nebula_id, nebula);

            // Mapping: nebula address => nebula struct
            self.nebulas.write(nebula_address, nebula);

            // Update nebulas
            self.total_nebulas.write(nebula_id + 1);

            /// # Event
            /// * `NewNebula`
            self.emit(NewNebula { name, nebula_id, nebula_address, created_at });
        }

        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * INebulaRegistry
        fn set_pending_admin(ref self: ContractState, new_pending: ContractAddress) {
            // Only admin
            self.check_admin();

            /// Pending admin until now
            let old_pending = self.pending_admin.read();

            /// Write pending admin to storage
            self.pending_admin.write(new_pending);

            /// # Event
            /// * `NewPendingAdmin`
            self.emit(NewPendingAdmin { old_pending, new_pending });
        }

        /// # Security
        /// * Only-pending-admin
        ///
        /// # Implementation
        /// * INebulaRegistry
        fn accept_admin(ref self: ContractState) {
            // Caller
            let new_admin = get_caller_address();

            /// Error - `ONLY_PENDING_ADMIN`
            assert(new_admin == self.pending_admin.read(), RegistryErrors::ONLY_PENDING_ADMIN);

            /// Admin up until now
            let old_admin = self.admin.read();

            // Write new admin to storage
            self.admin.write(new_admin);

            /// Reset pending admin
            self.pending_admin.write(Zeroable::zero());

            /// # Event
            /// * `NewAdmin`
            self.emit(NewAdmin { old_admin, new_admin });
        }
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[generate_trait]
    impl InternalImpl of InternalImplTrait {
        /// Checks msg.sender is admin
        ///
        /// # Security
        /// * Checks that caller is admin
        fn check_admin(self: @ContractState) {
            // Get admin address
            let admin = self.admin.read();

            /// # Error
            /// * `ONLY_ADMIN` - Reverts if sender is not admin 
            assert(get_caller_address() == admin, RegistryErrors::ONLY_ADMIN)
        }
    }
}
