// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash,};

// Foundry
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait};

// Cygnus
use cygnus::registry::registry::{INebulaRegistryDispatcher, INebulaRegistryDispatcherTrait};
use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::tests::setup::{setup};
use cygnus::tests::users::{admin, borrower, lender};

/// ----------------------------------------------------------------------------------
///                               ORACLE REGISTRY TESTS
/// ----------------------------------------------------------------------------------

#[test]
fn registry_nebulas_are_updated_correctly() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };

    assert(registry.all_nebulas_length() == 1, 'nebulas_length_not_updated');
}

#[test]
fn registry_lp_token_oracles_updated_correctly() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };

    assert(registry.all_lp_tokens_length() == 1, 'oracles_length_not_updated');
}

#[test]
fn registry_admin_same_as_hangar_admin() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };
    let r_admin = registry.admin();
    let h_admin = hangar18.admin();

    assert(r_admin == h_admin, 'admins_dont_match');
}


#[test]
fn nebula_keeps_track_of_oracles_deployed() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };

    let nebula = registry.all_nebulas(0);

    assert(nebula.total_oracles == 1, 'nebula_wrong_oracle_len');
}

#[test]
#[should_panic(expected: ('registry_only_admin',))]
fn only_registry_admin_can_create_nebula() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };

    let borrower = borrower();

    start_prank(registry.contract_address, borrower);
    let new_nebula = 0x12346.try_into().unwrap();
    registry.create_nebula(new_nebula);
    stop_prank(registry.contract_address);
}

#[test]
#[should_panic(expected: ('registry_only_admin',))]
fn registry_only_admin_can_create_lp_oracle() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };

    let borrower = borrower();

    start_prank(registry.contract_address, borrower);
    let new_lp_oracle = 0x12346.try_into().unwrap();
    let price_feeds = array![new_lp_oracle];
    registry.create_nebula_oracle(0, new_lp_oracle, price_feeds, false);
    stop_prank(registry.contract_address);
}

#[test]
#[should_panic(expected: ('registry_only_admin',))]
fn only_admin_can_set_pending_admin() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };

    let borrower = borrower();

    start_prank(registry.contract_address, borrower);
    registry.set_pending_admin(0x1234.try_into().unwrap());
    stop_prank(registry.contract_address);
}

#[test]
#[should_panic(expected: ('registry_only_admin',))]
fn only_pending_admin_can_accept_new_admin_unset() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };

    let borrower = borrower();

    start_prank(registry.contract_address, borrower);
    registry.set_pending_admin(0x1234.try_into().unwrap());
    stop_prank(registry.contract_address);
}

#[test]
#[should_panic(expected: ('registry_only_pending',))]
fn only_pending_admin_can_accept_new_admin_set() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };

    let admin = admin();
    let borrower = borrower();
    let lender = lender();

    start_prank(registry.contract_address, admin);
    registry.set_pending_admin(borrower);
    stop_prank(registry.contract_address);

    start_prank(registry.contract_address, lender);
    registry.accept_admin();
    stop_prank(registry.contract_address);
}

#[test]
#[should_panic(expected: ('registry_only_pending',))]
fn only_pending_admin_can_accept_new_admin_try_admin() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };

    let admin = admin();
    let borrower = borrower();
    let lender = lender();

    start_prank(registry.contract_address, admin);
    registry.set_pending_admin(borrower);
    registry.accept_admin();
    stop_prank(registry.contract_address);
}

#[test]
fn transfers_ownership_to_new_admin() {
    let (hangar18, _, _, _, _) = setup();
    let registry = INebulaRegistryDispatcher { contract_address: hangar18.oracle_registry() };

    let admin = admin();
    let borrower = borrower();

    start_prank(registry.contract_address, admin);
    registry.set_pending_admin(borrower);
    stop_prank(registry.contract_address);

    start_prank(registry.contract_address, borrower);
    registry.accept_admin();
    stop_prank(registry.contract_address);

    assert(registry.admin() == borrower, 'admin_not_updated');
    assert(registry.pending_admin() == Zeroable::zero(), 'pending_admin_not_reset');
}
