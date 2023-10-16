// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash,};

// Foundry
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait};

// Cygnus
use cygnus::tests::setup::{setup};
use cygnus::tests::users::{admin, borrower, lender, second_borrower};
use cygnus::token::erc20::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use integer::BoundedInt;
use snforge_std::io::PrintTrait;

/// TODO: Test borrowable deposits on fork with strategy (zkLend, etc.)

/// ----------------------------------------------------------------------------------
///                               DEPOSIT & REDEEM TEST
/// ----------------------------------------------------------------------------------

#[test]
#[should_panic(expected: ('u256_sub Overflow',))]
fn should_revert_when_depositing_without_approval() {
    let (hangar18, borrowable, collateral, lp_token, _) = setup();
    let borrower = borrower();

    let balance = lp_token.balance_of(borrower);
    assert(balance == 1_000_000_000_000_000_000, 'Insufficent Balance');

    let deposit_amount = 1_000_000_000_000_000_000;

    start_prank(collateral.contract_address, borrower);
    collateral.deposit(deposit_amount, borrower);
    stop_prank(collateral.contract_address);
}

#[test]
fn borrower_deposits_lp_in_collateral_and_mints_correct_shares() {
    let (_, _, collateral, lp_token, _) = setup();
    let borrower = borrower();

    start_prank(lp_token.contract_address, borrower);
    lp_token.approve(collateral.contract_address, BoundedInt::max());
    stop_prank(lp_token.contract_address);

    let lp_balance_before_deposit = lp_token.balance_of(borrower);
    assert(lp_balance_before_deposit == 1_000_000_000_000_000_000, 'Insufficent Balance');

    let deposit_amount = 1_000_000_000_000_000_000;

    start_prank(collateral.contract_address, borrower);
    collateral.deposit(deposit_amount, borrower);
    stop_prank(collateral.contract_address);

    let total_supply = collateral.total_supply();
    let total_balance = collateral.total_balance();
    let total_assets = collateral.total_assets();
    let cyg_lp_balance = collateral.balance_of(borrower);

    assert(total_balance == deposit_amount, 'total_balance_not_correct');
    assert(total_supply == total_balance, 'initial_shares_not_correct');
    assert(cyg_lp_balance == deposit_amount, 'did_not_mint_correctly');
    assert(total_assets == total_balance, 'total_assets_not_correct');
}

#[test]
fn second_borrower_deposits_lp_in_collateral_and_mints_correct_shares() {
    let (_, _, collateral, lp_token, _) = setup();
    let borrower = borrower();

    start_prank(lp_token.contract_address, borrower);
    lp_token.approve(collateral.contract_address, BoundedInt::max());
    stop_prank(lp_token.contract_address);

    let lp_balance_before_deposit = lp_token.balance_of(borrower);
    assert(lp_balance_before_deposit == 1_000_000_000_000_000_000, 'Insufficent Balance');

    let deposit_amount = 500_000_000_000_000_000;

    start_prank(collateral.contract_address, borrower);
    collateral.deposit(deposit_amount, borrower);
    stop_prank(collateral.contract_address);

    /// Give LPs to second borrower
    let second_borrower = second_borrower();
    start_prank(lp_token.contract_address, borrower);
    lp_token.transfer(second_borrower, deposit_amount.into());
    stop_prank(lp_token.contract_address);

    start_prank(lp_token.contract_address, second_borrower);
    lp_token.approve(collateral.contract_address, BoundedInt::max());
    stop_prank(lp_token.contract_address);

    start_prank(collateral.contract_address, second_borrower);
    collateral.deposit(deposit_amount, second_borrower);
    stop_prank(collateral.contract_address);

    assert(collateral.exchange_rate() == 1_000_000_000_000_000_000, 'wrong_exchange_rate');
    assert(collateral.balance_of(second_borrower) == deposit_amount, 'incorrect_cyg_lp_bal');
}

#[test]
fn borrower_redeems_correctly_no_rounding_errors() {
    let (_, _, collateral, lp_token, _) = setup();
    let borrower = borrower();

    start_prank(lp_token.contract_address, borrower);
    lp_token.approve(collateral.contract_address, BoundedInt::max());
    stop_prank(lp_token.contract_address);

    let lp_balance_before_deposit = lp_token.balance_of(borrower);
    assert(lp_balance_before_deposit == 1_000_000_000_000_000_000, 'Insufficent Balance');

    let deposit_amount = 1_000_000_000_000_000_000;

    start_prank(collateral.contract_address, borrower);
    collateral.deposit(deposit_amount, borrower);
    stop_prank(collateral.contract_address);

    let total_supply = collateral.total_supply();
    let total_balance = collateral.total_balance();
    let total_assets = collateral.total_assets();
    let cyg_lp_balance = collateral.balance_of(borrower);

    assert(total_balance == deposit_amount, 'total_balance_not_correct');
    assert(total_supply == total_balance, 'initial_shares_not_correct');
    assert(cyg_lp_balance == deposit_amount, 'did_not_mint_correctly');
    assert(total_assets == total_balance, 'total_assets_not_correct');

    start_prank(collateral.contract_address, borrower);
    collateral.redeem(cyg_lp_balance, borrower, borrower);
    stop_prank(collateral.contract_address);

    let total_supply = collateral.total_supply();
    let total_balance = collateral.total_balance();
    let total_assets = collateral.total_assets();
    let cyg_lp_balance = collateral.balance_of(borrower);

    assert(total_supply == 0, 'redeem_supply_rounding_error');
    assert(total_balance == 0, 'redeem_balance_rounding_error');
    assert(total_assets == 0, 'redeem_assets_rounding_error');
    assert(cyg_lp_balance == 0, 'did_not_redeem_all');
}

#[test]
fn get_lp_token_price_is_right() {
    let (_, _, collateral, _, _) = setup();

    let price = collateral.get_lp_token_price();
    assert(price == 3_000_000_000_000_000_000, 'wrong_price') // TODO - Check with real logic
}
