mod Events {
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
    use cygnus::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};
    use starknet::ContractAddress;

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

    /// # Event
    /// * `SwitchOrbiterStatus`
    #[derive(Drop, starknet::Event)]
    struct SwitchOrbiterStatus {
        orbiter_id: u32,
        status: bool,
    }

    /// # Event
    /// * `NewCygnusAltair`
    #[derive(Drop, starknet::Event)]
    struct NewCygnusAltair {
        old_cygnus_altair: ContractAddress,
        new_cygnus_altair: ContractAddress,
    }

    /// # Event
    /// * `NewCygnusX1Vault`
    #[derive(Drop, starknet::Event)]
    struct NewCygnusX1Vault {
        old_cygnus_x1_vault: ContractAddress,
        new_cygnus_x1_vault: ContractAddress,
    }

    /// # Event
    /// * `NewCygnusPillars`
    #[derive(Drop, starknet::Event)]
    struct NewCygnusPillars {
        old_cygnus_pillars: ContractAddress,
        new_cygnus_pillars: ContractAddress,
    }
}
