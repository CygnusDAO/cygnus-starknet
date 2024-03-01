/// Deployers
use cygnus::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
use cygnus::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};

/// Struct of borrowable & collateral deployers stored in factory
///
/// # Arguments
/// * `status` - Whether the deployers are usable or not (admin can switch off)
/// * `orbiter_id` - Unique ID for the orbiters
/// * `albireo_orbiter` - Address of the borrowable deployer
/// * `deneb_orbiter` - Address of the collateral deployer
/// * `name` - Human friendly name to identify deployers (ie. "Jediswap Pools", "Ekubo Pools", etc.)
#[derive(Drop, starknet::Store, Serde, Copy)]
struct Orbiter {
    status: bool,
    orbiter_id: u32,
    albireo_orbiter: IAlbireoDispatcher,
    deneb_orbiter: IDenebDispatcher,
    name: felt252
}
