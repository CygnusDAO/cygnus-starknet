// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash};
// Foundry
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait};
// Cygnus
use cygnus::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
use cygnus::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};

/// ----------------------------------------------------------------------------------
///                               COLLATERAL MODEL
/// ----------------------------------------------------------------------------------

#[test]
fn deploy_albireo_can_launch_pools() {
    let contract = declare('Albireo');
    let borrowable_class_hash = declare('Borrowable');
    let constructor_calldata = array![borrowable_class_hash.class_hash.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    let albireo = IAlbireoDispatcher { contract_address };
    // Mock random collateral
    let collateral = ICollateralDispatcher { contract_address };
    albireo.deploy_borrowable(contract_address, collateral, contract_address, 10);
}

#[test]
fn deploy_deneb_can_launch_pools() {
    let contract = declare('Deneb');
    let collateral_class_hash = declare('Collateral');
    let constructor_calldata = array![collateral_class_hash.class_hash.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    let deneb = IDenebDispatcher { contract_address };
    // Mock random borrowable
    let borrowable = IBorrowableDispatcher { contract_address };
    deneb.deploy_collateral(contract_address, borrowable, contract_address, 10);
}
