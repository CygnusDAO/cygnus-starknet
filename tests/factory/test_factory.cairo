// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash, get_tx_info};
use integer::BoundedInt;

// Foundry
use snforge_std::{declare, start_prank, stop_prank, start_warp, stop_warp, CheatTarget};

use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::registry::registry::{INebulaRegistryDispatcher, INebulaRegistryDispatcherTrait};

use tests::setup::{deploy_hangar};
use tests::users::{admin, dao_reserves_contract};
use tests::setup::{setup_with_router, setup};

#[test]
#[fork("MAINNET")]
fn switches_orbiter_status() {
    let (hangar18, _, _, _, _) = setup();
    let status = hangar18.all_orbiters(0).status;
    assert(status, 'not switched on');
    let admin = admin();
    start_prank(CheatTarget::One(hangar18.contract_address), admin);
    hangar18.switch_orbiter_status(0);
    stop_prank(CheatTarget::One(hangar18.contract_address));
    let status = hangar18.all_orbiters(0).status;
    assert(!status, 'didnt turn off');
}


#[test]
#[fork("MAINNET")]
#[should_panic(expected: ('hangar_orbiter_inactive',))]
fn cannot_deploy_with_switched_off_orbiters() {
    let (hangar18, _, _, lp_token, _) = setup();
    start_prank(CheatTarget::One(hangar18.contract_address), admin());
    hangar18.switch_orbiter_status(0);
    hangar18.deploy_shuttle(0, lp_token.contract_address);
    stop_prank(CheatTarget::One(hangar18.contract_address));
}

