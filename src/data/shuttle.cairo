/// Deployers
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};

/// Shuttle struct
#[derive(Drop, starknet::Store, Serde)]
struct Shuttle {
    deployed: bool,
    shuttle_id: u32,
    borrowable: IBorrowableDispatcher,
    collateral: ICollateralDispatcher,
    orbiter_id: u32
}

