// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash,};

// Foundry
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait};

// Cygnus
use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::tests::setup::{setup};
use cygnus::tests::users::{admin, borrower, lender};

/// ----------------------------------------------------------------------------------
///                               FACTORY TESTS
/// ----------------------------------------------------------------------------------

#[test]
fn shuttle_gets_deployed_successfully() {
    // Deploy Shuttle
    let (hangar18, borrowable, collateral, _, _) = setup();
    let shuttle_id_b = borrowable.shuttle_id();
    let shuttle_id_c = collateral.shuttle_id();
    let total_shuttles = hangar18.all_shuttles_length();
    assert(shuttle_id_b == shuttle_id_c, 'shuttle_id_dont_match');
    assert(total_shuttles == 1, 'total_shuttles_not_unique');
}

#[test]
fn borrowable_underlying_is_usd() {
    // Deploy Shuttle
    let (hangar18, borrowable, collateral, _, _) = setup();
    // Get usd from factory
    let usd = hangar18.usd();
    // Get underlying  of borrowable
    let underlying = borrowable.underlying();
    // ASSERT
    assert(underlying == usd, 'underlyings_dont_match');
}

#[test]
fn collateral_underlying_is_lp_token() {
    let (hangar18, borrowable, collateral, lp_token, _) = setup();
    // Get underlying  of borrowable
    let underlying = collateral.underlying();
    // ASSERT
    assert(underlying == lp_token.contract_address, 'underlyings_dont_match');
}

#[test]
#[should_panic(expected: ('already_set',))]
fn borrowable_cannot_be_set_again() {
    let (_, borrowable, collateral, _, _) = setup();
    collateral.set_borrowable(borrowable)
}

#[test]
fn sets_default_collateral_params_at_deployment() {
    let (_, _, collateral, _, _) = setup();
    let debt_ratio = collateral.debt_ratio();
    let liq_incentive = collateral.liquidation_incentive();
    let liq_fee = collateral.liquidation_fee();
    assert(debt_ratio == 900000000000000000, 'Wrong'); // 90%
    assert(liq_incentive == 1030000000000000000, 'Wrong'); // 3% (base 18)
    assert(liq_fee == 10000000000000000, 'Wrong'); // 1%
}

#[test]
#[should_panic(expected: ('c_only_admin',))]
fn only_admin_can_adjust_params() {
    let (_, _, collateral, _, _) = setup();
    collateral.set_debt_ratio(850000000000000000);
    let new_user: ContractAddress = 0x666.try_into().unwrap();
    start_prank(collateral.contract_address, new_user);
    collateral.set_debt_ratio(900000000000000000);
    stop_prank(collateral.contract_address);
}

#[test]
#[should_panic(expected: ('c_invalid_range',))]
fn only_admin_invalid_range_debt_ratio() {
    let (_, _, collateral, _, _) = setup();
    let admin = admin();
    start_prank(collateral.contract_address, admin);
    collateral.set_debt_ratio(1050000000000000000);
    stop_prank(collateral.contract_address);
}

#[test]
#[should_panic(expected: ('c_invalid_range',))]
fn only_admin_invalid_range_incentive() {
    let (_, _, collateral, _, _) = setup();
    let admin = admin();
    start_prank(collateral.contract_address, admin);
    collateral.set_liquidation_incentive(1300000000000000000);
    stop_prank(collateral.contract_address);
}

#[test]
#[should_panic(expected: ('c_invalid_range',))]
fn only_admin_invalid_range_fee() {
    let (_, _, collateral, _, _) = setup();
    let admin = admin();
    start_prank(collateral.contract_address, admin);
    collateral.set_liquidation_fee(300000000000000000);
    stop_prank(collateral.contract_address);
}

