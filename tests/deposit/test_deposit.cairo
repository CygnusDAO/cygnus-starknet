// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash, contract_address_const};

// Foundry
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait, start_warp, stop_warp, CheatTarget};

// Cygnus
use tests::setup::{setup};
use tests::users::{admin, borrower, lender};
use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use integer::BoundedInt;
use snforge_std::PrintTrait;

// TIMESTAMP FORK: 1699559919

/// ----------------------------------------------------------------------------------
///                               DEPOSIT & REDEEM TEST
/// ----------------------------------------------------------------------------------

#[test]
#[fork("MAINNET")]
fn deployed_correctly() {
    let (_, _, _, lp_token, usdc) = setup();
    let borrower = borrower();
    let balance = lp_token.balanceOf(borrower.into());

    assert(balance > 0, 'borrower_no_lp_balance');

    let lender = lender();
    let balance = usdc.balanceOf(lender.into());

    assert(balance > 0, 'lender_no_usd_balance');
}

#[test]
#[fork("MAINNET")]
fn borrower_deposits_lp_in_collateral_and_mints_correct_shares() {
    let (_, _, collateral, lp_token, _) = setup();

    let borrower = borrower();

    // Approve LP
    start_prank(CheatTarget::One(lp_token.contract_address), borrower);
    lp_token.approve(collateral.contract_address.into(), BoundedInt::max());
    stop_prank(CheatTarget::One(lp_token.contract_address));

    // Deposit in collateral
    let lp_balance = lp_token.balanceOf(borrower.into());
    start_prank(CheatTarget::One(collateral.contract_address), borrower);
    collateral.deposit(lp_balance.try_into().unwrap(), borrower);
    stop_prank(CheatTarget::One(collateral.contract_address));

    let cyg_lp_balance = collateral.balance_of(borrower);

    assert(cyg_lp_balance.into() == lp_balance - 1000, 'wrong_cyglp_shares');
}

#[test]
#[fork("MAINNET")]
fn lender_deposits_usd_in_borrowable_and_mints_correct_shares() {
    let (_, borrowable, _, _, usdc) = setup();

    let lender = lender();

    // Approve LP
    start_prank(CheatTarget::One(usdc.contract_address), lender);
    usdc.approve(borrowable.contract_address.into(), BoundedInt::max());
    stop_prank(CheatTarget::One(usdc.contract_address));

    // Deposit in collateral
    let usdc_balance = usdc.balanceOf(lender.into());
    start_prank(CheatTarget::One(borrowable.contract_address), lender);
    borrowable.deposit(usdc_balance.try_into().unwrap(), lender);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    let cyg_usd_balance = borrowable.balance_of(lender);

    assert(cyg_usd_balance.into() == usdc_balance - 1000, 'wrong_cyg_usd_shares');
}

#[test]
#[fork("MAINNET")]
fn collateral_values_update_correctly() {
    let (_, _, collateral, lp_token, _) = setup();

    let borrower = borrower();

    // Approve LP
    start_prank(CheatTarget::One(lp_token.contract_address), borrower);
    lp_token.approve(collateral.contract_address.into(), BoundedInt::max());
    stop_prank(CheatTarget::One(lp_token.contract_address));

    // Deposit in collateral
    let lp_balance: u128 = lp_token.balanceOf(borrower.into()).try_into().unwrap();
    start_prank(CheatTarget::One(collateral.contract_address), borrower);
    collateral.deposit(lp_balance, borrower);
    stop_prank(CheatTarget::One(collateral.contract_address));

    assert(collateral.total_balance() == lp_balance, 'wrong_total_balance');
    assert(collateral.total_assets() == lp_balance, 'wrong_total_assets');
    assert(collateral.total_supply() == lp_balance, 'wrong_total_supply');
}

#[test]
#[fork("MAINNET")]
fn borrowable_values_update_correctly() {
    let (_, borrowable, _, _, usdc) = setup();

    let lender = lender();

    // Approve LP
    start_prank(CheatTarget::One(usdc.contract_address), lender);
    usdc.approve(borrowable.contract_address.into(), BoundedInt::max());
    stop_prank(CheatTarget::One(usdc.contract_address));

    // Deposit in collateral
    let usdc_balance = usdc.balanceOf(lender.into()).try_into().unwrap();

    start_prank(CheatTarget::One(borrowable.contract_address), lender);
    borrowable.deposit(usdc_balance, lender);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    // zkUSDC rounds down deposits
    assert(borrowable.total_balance() >= usdc_balance - 10, 'wrong_total_balance');
    assert(borrowable.total_assets() >= usdc_balance - 10, 'wrong_total_assets');
    assert(borrowable.total_supply() >= usdc_balance - 10, 'wrong_total_supply');
    assert(borrowable.total_borrows() == 0, 'wrong_total_borrows');
}

