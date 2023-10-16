// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash};

// Foundry
use snforge_std::{declare, start_prank, stop_prank};

// Cygnus
use cygnus::tests::setup::{setup_with_pillars};
use cygnus::tests::users::{admin, borrower, lender};
use cygnus::token::erc20::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::token::erc20::cyg::{ICygnusDAODispatcher, ICygnusDAODispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};
use integer::BoundedInt;

/// ----------------------------------------------------------------------------------
///                               CYG TOKEN TEST
/// ----------------------------------------------------------------------------------

#[test]
fn cyg_token_deployed_correctly() {
    let (_, _, _, _, _, _, cyg_token, _) = setup_with_pillars();
    assert(cyg_token.total_supply() == 0, 'wrong_supply');
}

#[test]
fn cyg_token_sets_initial_admin() {
    let (_, _, _, _, _, _, cyg_token, _) = setup_with_pillars();
    let admin = admin();
    assert(cyg_token.owner() == admin, 'admin_not_set');
}

/// Non-owner sets pillars
#[test]
#[should_panic(expected: ('only_owner',))]
fn panics_if_non_owner_sets_pillars() {
    let (_, _, _, _, _, _, cyg_token, _) = setup_with_pillars();
    let admin = admin();
    /// Random
    let borrower = borrower();

    assert(cyg_token.owner() == admin, 'admin_not_set');

    start_prank(cyg_token.contract_address, borrower);
    cyg_token.set_pillars(borrower);
    stop_prank(cyg_token.contract_address);
}

#[test]
fn owner_can_set_pillars() {
    let (_, _, _, _, _, _, cyg_token, _) = setup_with_pillars();
    let admin = admin();
    let borrower = borrower();

    assert(cyg_token.owner() == admin, 'admin_not_set');

    /// Give pillars role to borrower
    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(borrower);
    stop_prank(cyg_token.contract_address);

    assert(cyg_token.pillars_of_creation() == borrower, 'pillars_not_updated');
}

#[test]
#[should_panic(expected: ('pillars_already_set',))]
fn owner_cannot_set_pillars_again() {
    let (_, _, _, _, _, _, cyg_token, _) = setup_with_pillars();
    let admin = admin();
    let borrower = borrower();

    assert(cyg_token.owner() == admin, 'admin_not_set');

    /// Give pillars role to borrower
    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(borrower);
    stop_prank(cyg_token.contract_address);

    assert(cyg_token.pillars_of_creation() == borrower, 'pillars_not_updated');

    let lender = lender();

    /// Give pillars role to borrower
    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(lender);
    stop_prank(cyg_token.contract_address);
}

#[test]
#[should_panic(expected: ('only_pillars',))]
fn reverts_if_anyone_but_pillars_mints() {
    let (_, _, _, _, _, _, cyg_token, _) = setup_with_pillars();
    let borrower = borrower();

    start_prank(cyg_token.contract_address, borrower);
    cyg_token.mint(borrower, 10000000000);
    stop_prank(cyg_token.contract_address);
}

#[test]
fn pillars_can_mint_tokens() {
    let (_, _, _, _, _, _, cyg_token, _) = setup_with_pillars();
    let admin = admin();
    let borrower = borrower();

    assert(cyg_token.owner() == admin, 'admin_not_set');

    /// Give pillars role to borrower
    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(borrower);
    stop_prank(cyg_token.contract_address);

    assert(cyg_token.pillars_of_creation() == borrower, 'pillars_not_updated');

    let mint_amount = 1_000000000_000000000;
    start_prank(cyg_token.contract_address, borrower);
    cyg_token.mint(borrower, mint_amount);
    stop_prank(cyg_token.contract_address);

    assert(cyg_token.total_supply() == mint_amount, 'wrong_supply');
}

#[test]
#[should_panic(expected: ('only_pillars',))]
fn reverts_if_anyone_but_pillars_mints_after_transfer() {
    let (_, _, _, _, _, _, cyg_token, _) = setup_with_pillars();
    let admin = admin();
    let borrower = borrower();

    assert(cyg_token.owner() == admin, 'admin_not_set');

    /// Give pillars role to borrower
    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(borrower);
    stop_prank(cyg_token.contract_address);

    assert(cyg_token.pillars_of_creation() == borrower, 'pillars_not_updated');

    let mint_amount = 1_000000000_000000000;
    start_prank(cyg_token.contract_address, admin);
    cyg_token.mint(borrower, mint_amount);
    stop_prank(cyg_token.contract_address);
}


#[test]
fn pillars_can_mint_tokens_up_to_cap() {
    let (_, _, _, _, _, _, cyg_token, _) = setup_with_pillars();
    let admin = admin();
    let borrower = borrower();

    assert(cyg_token.owner() == admin, 'admin_not_set');

    /// Give pillars role to borrower
    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(borrower);
    stop_prank(cyg_token.contract_address);

    assert(cyg_token.pillars_of_creation() == borrower, 'pillars_not_updated');

    let mint_amount = cyg_token.CAP();
    start_prank(cyg_token.contract_address, borrower);
    cyg_token.mint(borrower, mint_amount);
    stop_prank(cyg_token.contract_address);

    assert(cyg_token.total_supply() == mint_amount, 'wrong_supply');
}

#[test]
#[should_panic(expected: ('above_cap',))]
fn reverts_if_minting_above_cap() {
    let (_, _, _, _, _, _, cyg_token, _) = setup_with_pillars();
    let admin = admin();
    let borrower = borrower();

    assert(cyg_token.owner() == admin, 'admin_not_set');

    /// Give pillars role to borrower
    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(borrower);
    stop_prank(cyg_token.contract_address);

    assert(cyg_token.pillars_of_creation() == borrower, 'pillars_not_updated');

    let mint_amount = cyg_token.CAP() + 1;
    start_prank(cyg_token.contract_address, borrower);
    cyg_token.mint(borrower, mint_amount);
    stop_prank(cyg_token.contract_address);
}
