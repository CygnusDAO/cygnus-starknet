//! Hangar18

// Libraries
use starknet::ContractAddress;
use cygnus::data::orbiter::{Orbiter};
use cygnus::data::shuttle::{Shuttle};
use cygnus::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
use cygnus::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};
use cygnus::registry::registry::{INebulaRegistryDispatcher, INebulaRegistryDispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};

/// # Interface - Hangar18
#[starknet::interface]
trait IHangar18<T> {
    ///--------------------------------------------------------------------------------------------------------
    ///                                        CONSTANT FUNCTIONS
    ///--------------------------------------------------------------------------------------------------------

    /// # Returns the name of the factory (`Hangar18`)
    fn name(self: @T) -> felt252;

    /// # Returns the address of the current admin, the pool/orbiter deployer
    fn admin(self: @T) -> ContractAddress;

    /// # Returns the address of the current pending admin
    fn pending_admin(self: @T) -> ContractAddress;

    /// # Returns the address of the oracle registry
    fn oracle_registry(self: @T) -> ContractAddress;

    /// # Returns the address of the borrow token for all Cygnus pools
    fn usd(self: @T) -> ContractAddress;

    /// # Returns the address of the DAO reserves
    fn dao_reserves(self: @T) -> ContractAddress;

    /// # Returns the address of the native token on starknet (ie ETH)
    fn native_token(self: @T) -> ContractAddress;

    /// # Returns the orbiter struct given an orbiter ID
    fn all_orbiters(self: @T, id: u32) -> Orbiter;

    /// # Returns the shuttle struct given a shuttle ID
    fn all_shuttles(self: @T, id: u32) -> Shuttle;

    /// # Returns the total number of orbiters deployed
    fn total_orbiters_deployed(self: @T) -> u32;

    /// # Returns the total number of shuttles deployed
    fn total_shuttles_deployed(self: @T) -> u32;

    /// Quick reporting functions on this chain to get TVLs in USD. Uses 6 decimals since our
    /// lending token is USDC.

    fn chain_id(self: @T) -> felt252;

    /// Gets a lending pool tvl (usdc deposits + lp deposits) priced in USD
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    ///
    /// # Returns
    /// * The TVL of the shuttle
    fn shuttle_tvl_usd(self: @T, shuttle_id: u32) -> u128;

    /// Gets a collateral tvl (LP deposits) priced in USD
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    ///
    /// # Returns
    /// * The TVL of the collateral
    fn collateral_tvl_usd(self: @T, shuttle_id: u32) -> u128;

    /// Gets a borrowable tvl (USDC deposits + borrows) priced in USD
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    ///
    /// # Returns
    /// * The TVL of the borrowable
    fn borrowable_tvl_usd(self: @T, shuttle_id: u32) -> u128;

    /// # Returns
    /// * Cygnus protocol current total borrows
    fn cygnus_total_borrows_usd(self: @T) -> u128;

    /// # Returns
    /// * The tvl of all collaterals 
    fn all_collaterals_tvl(self: @T) -> u128;

    /// # Returns
    /// * The tvl of all borrowbales
    fn all_borrowables_tvl(self: @T) -> u128;

    /// # Returns
    /// * The tvl of the whole protocol on Starknet
    fn cygnus_tvl_usd(self: @T) -> u128;

    ///--------------------------------------------------------------------------------------------------------
    ///                                      NON-CONSTANT FUNCTIONS
    ///--------------------------------------------------------------------------------------------------------

    /// Sets a new orbiter in the factory
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `name` - Human friendly name for the orbiter (ie. `JediSwap Orbiter`)
    /// * `albireo` - The address of the borrowable deployer
    /// * `deneb` - The address of the collateral deployer
    fn set_orbiter(ref self: T, name: felt252, albireo_orbiter: IAlbireoDispatcher, deneb_orbiter: IDenebDispatcher);

    /// Deploys a new lending pool
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `orbiter_id` - The unique id for the deployers
    /// * `lp_token_pair` - The address of the LP Token
    ///
    /// # Returns
    /// * Borrowable and collateral contracts deployed
    fn deploy_shuttle(
        ref self: T, orbiter_id: u32, lp_token_pair: ContractAddress
    ) -> (IBorrowableDispatcher, ICollateralDispatcher);

    /// Sets a new pending admin for the factory. This admin controls the most important
    /// variables across the whole protcol on this chain.
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_pending_admin` - The address of the new pending admin
    fn set_pending_admin(ref self: T, new_pending_admin: ContractAddress);

    /// Pending admin accepts the admin role
    ///
    /// # Security
    /// * Only-pending-admin
    fn accept_admin(ref self: T);

    /// Admin sets a new DAO Reserves contract which all pools mint reserves to
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_dao_reserves` - The address of the new DAO reserves
    fn set_dao_reserves(ref self: T, new_dao_reserves: ContractAddress);
}

/// # Module - Hangar18
#[starknet::contract]
mod Hangar18 {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::IHangar18;
    use cygnus::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};
    use cygnus::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
    use cygnus::registry::registry::{INebulaRegistryDispatcher, INebulaRegistryDispatcherTrait};
    use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};

    /// # Libraries
    use starknet::{ContractAddress, get_caller_address, contract_address_const, get_contract_address, get_tx_info};
    use cygnus::libraries::full_math_lib::FullMathLib::FixedPointMathLibTrait;

    /// # Errors
    use cygnus::factory::errors::Hangar18Errors as Errors;

    /// # Data
    use cygnus::data::orbiter::{Orbiter};
    use cygnus::data::shuttle::{Shuttle};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Events
    /// * `NewAdmin` - Logs when the pending admin accepts the admin role
    /// * `NewPendingAdmin` - Logs when a new pending admin is set
    /// * `NewOrbiter` - Logs when a new orbiter is added to the hangar
    /// * `NewShuttle` - Logs when a new shuttle is deployed
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewAdmin: NewAdmin,
        NewPendingAdmin: NewPendingAdmin,
        NewOrbiter: NewOrbiter,
        NewShuttle: NewShuttle,
        NewDAOReserves: NewDAOReserves
    }

    /// # Event
    /// * `NewAdmin`
    #[derive(Drop, starknet::Event)]
    struct NewAdmin {
        old_admin: ContractAddress,
        new_admin: ContractAddress
    }

    /// # Event
    /// * `NewPendingAdmin`
    #[derive(Drop, starknet::Event)]
    struct NewPendingAdmin {
        old_pending_admin: ContractAddress,
        new_pending_admin: ContractAddress
    }

    /// # Event
    /// * `NewOrbiter`
    #[derive(Drop, starknet::Event)]
    struct NewOrbiter {
        orbiter_id: u32,
        albireo_orbiter: IAlbireoDispatcher,
        deneb_orbiter: IDenebDispatcher
    }

    /// # Event
    /// * `NewShuttle`
    #[derive(Drop, starknet::Event)]
    struct NewShuttle {
        shuttle_id: u32,
        borrowable: IBorrowableDispatcher,
        collateral: ICollateralDispatcher
    }

    /// # Event
    /// * `NewDAOReserves`
    #[derive(Drop, starknet::Event)]
    struct NewDAOReserves {
        old_dao_reserves: ContractAddress,
        new_dao_reserves: ContractAddress,
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Name of the factory contract
        name: felt252,
        /// Current admin, the only one capable of deploying pools
        admin: ContractAddress,
        /// Pending Admin, the address of the new pending admin
        pending_admin: ContractAddress,
        /// The address of the oracle registry on Starknet
        oracle_registry: INebulaRegistryDispatcher,
        /// DAO Reserves
        dao_reserves: ContractAddress,
        /// The total number of orbiters initialized
        total_orbiters: u32,
        /// Total shuttles deployed
        total_shuttles: u32,
        /// Mapping of all orbiters
        all_orbiters: LegacyMap::<u32, Orbiter>,
        /// Mapping of all shuttles
        all_shuttles: LegacyMap::<u32, Shuttle>,
        /// The lending token
        usd: ContractAddress,
        /// Native token (ie WETH)
        native_token: ContractAddress
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress, oracle_registry: INebulaRegistryDispatcher) {
        // Admin and registry
        self.admin.write(admin);
        self.oracle_registry.write(oracle_registry);

        /// Address of native (ie ETH)
        let native_token: ContractAddress = contract_address_const::<
            0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
        >();

        /// Address of USDC
        let usd: ContractAddress = contract_address_const::<
            0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
        >();

        self.usd.write(usd);
        self.native_token.write(native_token);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl Hangar18Impl of IHangar18<ContractState> {
        ///----------------------------------------------------------------------------------------------------
        ///                                        CONSTANT FUNCTIONS
        ///----------------------------------------------------------------------------------------------------
        /// # Implementation
        /// * IHangar18
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        /// # Implementation
        /// * IHangar18
        fn admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        /// # Implementation
        /// * IHangar18
        fn pending_admin(self: @ContractState) -> ContractAddress {
            self.pending_admin.read()
        }

        /// # Implementation
        /// * IHangar18
        fn oracle_registry(self: @ContractState) -> ContractAddress {
            self.oracle_registry.read().contract_address
        }

        /// # Implementation
        /// * IHangar18
        fn dao_reserves(self: @ContractState) -> ContractAddress {
            self.dao_reserves.read()
        }

        /// # Implementation
        /// * IHangar18
        fn usd(self: @ContractState) -> ContractAddress {
            self.usd.read()
        }

        /// # Implementation
        /// * IHangar18
        fn native_token(self: @ContractState) -> ContractAddress {
            self.native_token.read()
        }

        /// # Implementation
        /// * IHangar18
        fn chain_id(self: @ContractState) -> felt252 {
            get_tx_info().unbox().chain_id
        }

        /// # Implementation
        /// * IHangar18
        fn all_orbiters(self: @ContractState, id: u32) -> Orbiter {
            let orbiter: Orbiter = self.all_orbiters.read(id);
            orbiter
        }

        /// # Implementation
        /// * IHangar18
        fn all_shuttles(self: @ContractState, id: u32) -> Shuttle {
            let shuttle: Shuttle = self.all_shuttles.read(id);
            shuttle
        }

        /// # Implementation
        /// * IHangar18
        fn total_orbiters_deployed(self: @ContractState) -> u32 {
            self.total_orbiters.read()
        }

        /// # Implementation
        /// * IHangar18
        fn total_shuttles_deployed(self: @ContractState) -> u32 {
            self.total_shuttles.read()
        }

        /// # Implementation
        /// * IHangar18
        fn collateral_tvl_usd(self: @ContractState, shuttle_id: u32) -> u128 {
            /// Collateral contract of this shuttle
            let collateral = self.all_shuttles.read(shuttle_id).collateral;

            /// Tvl = Total LP assets * LP Token Price
            let total_assets = collateral.total_assets();
            let lp_token_price = collateral.get_lp_token_price();

            total_assets.mul_wad(lp_token_price)
        }

        /// # Implementation
        /// * IHangar18
        fn borrowable_tvl_usd(self: @ContractState, shuttle_id: u32) -> u128 {
            /// Borrowable contract of this shuttle
            let borrowable = self.all_shuttles.read(shuttle_id).borrowable;

            /// total_balance = Current amount deposited in the strategy not being borrowed
            /// total_borrows = Current amount of borrowed USDC
            /// total_assets = total_balance + total_borrows
            ///
            /// Tvl = Total USDC assets * USDC Price
            let total_assets = borrowable.total_assets();
            let usd_price = borrowable.get_usd_price();

            total_assets.mul_wad(usd_price)
        }

        /// # Implementation
        /// * IHangar18
        fn shuttle_tvl_usd(self: @ContractState, shuttle_id: u32) -> u128 {
            /// Borrowable TVL + Collateral TVL
            self.borrowable_tvl_usd(shuttle_id) + self.collateral_tvl_usd(shuttle_id)
        }

        /// # Implementation
        /// * IHangar18
        fn all_collaterals_tvl(self: @ContractState) -> u128 {
            /// Get total shuttles and initialize length and tvl accumulator
            let total_shuttles = self.total_shuttles.read();
            let mut length = 0;
            let mut tvl = 0;

            /// Loop through all collaterals and accumulate TVL
            loop {
                if length == total_shuttles {
                    break;
                }
                tvl += self.collateral_tvl_usd(length);
                length += 1;
            };

            tvl
        }

        /// # Implementation
        /// * IHangar18
        fn all_borrowables_tvl(self: @ContractState) -> u128 {
            /// Get total shuttles and initialize length and tvl accumulator
            let total_shuttles = self.total_shuttles.read();
            let mut length = 0;
            let mut tvl = 0;

            /// Loop through all borrowables and accumulate TVL
            loop {
                if length == total_shuttles {
                    break;
                }
                tvl += self.borrowable_tvl_usd(length);
                length += 1;
            };

            tvl
        }

        /// # Implementation
        /// * IHangar18
        fn cygnus_total_borrows_usd(self: @ContractState) -> u128 {
            /// Get total shuttles and initialize length and borrows accumulator
            let total_shuttles = self.total_shuttles.read();
            let mut borrows = 0;
            let mut length = 0;

            /// Loop through all shuttles and accumulate borrows
            loop {
                if length == total_shuttles {
                    break;
                }
                let shuttle: Shuttle = self.all_shuttles.read(length);
                let total_borrows = shuttle.borrowable.total_borrows();
                borrows += total_borrows;
                length += 1;
            };

            borrows
        }

        fn cygnus_tvl_usd(self: @ContractState) -> u128 {
            /// Get total shuttles and initialize length and tvl accumulator
            let total_shuttles = self.total_shuttles.read();
            let mut length = 0;
            let mut tvl = 0;

            /// Loop through all shuttles and accumulate tvl
            loop {
                if length == total_shuttles {
                    break;
                }
                tvl += self.shuttle_tvl_usd(length);
                length += 1;
            };

            tvl
        }

        ///----------------------------------------------------------------------------------------------------
        ///                                     NON-CONSTANT FUNCTIONS
        ///----------------------------------------------------------------------------------------------------

        /// Initializes a new orbiter in the factory and assigns it a unique ID
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation - IHangar18
        fn set_orbiter(
            ref self: ContractState, name: felt252, albireo_orbiter: IAlbireoDispatcher, deneb_orbiter: IDenebDispatcher
        ) {
            // Check for admin
            self.check_admin();

            // Total orbiters deployed
            let orbiter_id = self.total_orbiters.read();

            // Build orbiter and assign unique ID
            let orbiter: Orbiter = Orbiter { status: true, orbiter_id, albireo_orbiter, deneb_orbiter, name };

            // Store orbiter struct
            self.all_orbiters.write(orbiter_id, orbiter);

            // Increase ID
            self.total_orbiters.write(orbiter_id + 1);

            /// # Event
            /// * `NewOrbiter`
            self.emit(NewOrbiter { orbiter_id, albireo_orbiter, deneb_orbiter });
        }

        /// Deploys a lending pool, given an LP Token Pair and the ID for the deployers
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IHangar18
        fn deploy_shuttle(
            ref self: ContractState, orbiter_id: u32, lp_token_pair: ContractAddress
        ) -> (IBorrowableDispatcher, ICollateralDispatcher) {
            /// Check sender is admin
            self.check_admin();

            // 1. Load orbiter
            let orbiter: Orbiter = self.all_orbiters.read(orbiter_id);

            /// # Error
            /// * `ORBITER_INACTIVE` - Revert if orbiter is switched off
            assert(orbiter.status, Errors::ORBITER_INACTIVE);

            // 2: Assign unique shuttle id
            let shuttle_id: u32 = self.total_shuttles.read();

            // 3. Get Oracle
            // Check the registry for the oracle for this LP
            let oracle: ContractAddress = self.oracle_registry.read().get_lp_token_nebula_address(lp_token_pair);

            /// # Error
            /// * `ORACLE_NOT_INITIALIZED` - Revert if we have no oracle for this LP
            assert(!oracle.is_zero(), Errors::ORACLE_NOT_INITIALIZED);

            /// 4. Deploy lending pool
            /// Use collateral orbiter to deploy lp token pool, deploy with borrowable as zero address
            let collateral: ICollateralDispatcher = orbiter
                .deneb_orbiter
                .deploy_collateral(
                    lp_token_pair, IBorrowableDispatcher { contract_address: Zeroable::zero() }, oracle, shuttle_id
                );

            /// Use borrowable orbiter to deploy stablecoin pool with deployed collateral address
            let borrowable: IBorrowableDispatcher = orbiter
                .albireo_orbiter
                .deploy_borrowable(self.usd.read(), collateral, oracle, shuttle_id);

            // Set the borrowable in collateral
            collateral.set_borrowable(borrowable);

            // 5. Write to storage
            let shuttle: Shuttle = Shuttle {
                deployed: true,
                shuttle_id: shuttle_id,
                borrowable: borrowable,
                collateral: collateral,
                orbiter_id: orbiter_id
            };

            // Write shuttle to array
            self.all_shuttles.write(shuttle_id, shuttle);

            // Increase unique id's
            self.total_shuttles.write(shuttle_id + 1);

            /// # Event
            /// * `NewShuttle`
            self.emit(NewShuttle { shuttle_id, borrowable, collateral });

            // Return borrowable and collateral deployed
            (borrowable, collateral)
        }


        /// Sets a new pending admin which they must then accept ownership
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IHangar18
        fn set_pending_admin(ref self: ContractState, new_pending_admin: ContractAddress) {
            // Check sender is admin
            self.check_admin();

            // Pending admin up until now
            let old_pending_admin: ContractAddress = self.pending_admin.read();

            // Store new pending admin
            self.pending_admin.write(new_pending_admin);

            /// # Event
            /// * `NewPendingAdmin`
            self.emit(NewPendingAdmin { old_pending_admin, new_pending_admin });
        }

        /// Pending admin must accept the role to finalize admin transfership
        ///
        /// # Security
        /// * Only-pending-admin
        ///
        /// # Implementation
        /// * IHangar18
        fn accept_admin(ref self: ContractState) {
            /// Get pending admin
            let pending_admin = self.pending_admin.read();
            assert(!pending_admin.is_zero(), Errors::PENDING_CANT_BE_ZERO);

            // Get caller
            let caller = get_caller_address();

            /// # Error
            /// * `ONLY_PENDING_ADMIN` - Avoid if caller is not pending admin
            assert(caller == pending_admin, Errors::ONLY_PENDING_ADMIN);

            // Admin up until now
            let old_admin = self.admin.read();

            /// Store new admin
            self.admin.write(caller);

            /// # Event
            /// * `NewAdmin`
            self.emit(NewAdmin { old_admin, new_admin: caller });
        }

        /// Set a new DAO Reserves contract which all pools mint reserves to
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IHangar18
        fn set_dao_reserves(ref self: ContractState, new_dao_reserves: ContractAddress) {
            // Check sender is admin
            self.check_admin();

            /// # Error
            /// * `DAO_RESERVES_CANT_BE_ZERO` - Avoid setting the reserves as the zero address
            assert(!new_dao_reserves.is_zero(), Errors::DAO_RESERVES_CANT_BE_ZERO);

            /// DAO reserves until now
            let old_dao_reserves = self.dao_reserves.read();

            /// Store new dao reserves contract
            self.dao_reserves.write(new_dao_reserves);

            /// # Event
            ///  `NewDAOReserves`
            self.emit(NewDAOReserves { old_dao_reserves, new_dao_reserves });
        }
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Hangar18 - Internal
    #[generate_trait]
    impl InternalImpl of InternalImplTrait {
        /// Checks msg.sender is admin
        ///
        /// # Security
        /// * Checks that caller is admin
        fn check_admin(self: @ContractState) {
            // Get admin address from the hangar18
            let admin = self.admin.read();

            /// # Error
            /// * `ONLY_ADMIN` - Reverts if sender is not hangar18 admin 
            assert(get_caller_address() == admin, Errors::ONLY_ADMIN)
        }
    }
}
