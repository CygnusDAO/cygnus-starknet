// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash};
use integer::BoundedInt;

// Foundry
use snforge_std::{declare, start_prank, stop_prank, start_warp, stop_warp};

// Cygnus
use cygnus::tests::setup::{setup};
use cygnus::tests::users::{admin, borrower, lender};
use cygnus::token::erc20::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::data::calldata::{LeverageCalldata};

/// ----------------------------------------------------------------------------------
///                            BORROW AND SNAPSHOT TEST
/// ----------------------------------------------------------------------------------

use snforge_std::io::PrintTrait;

/// Borrower deposits 1 LP
const LP_DEPOSIT_AMOUNT: u256 = 1_000000000_000000000;

/// Lender deposits 10 USDC
const USDC_DEPOSIT_AMOUNT: u256 = 10_000000000_000000000;

const ONE_YEAR: u64 = 31536000;

/// # Function 
/// * borrow -> balance_of
#[test]
fn borrower_borrows_max_liquidity() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    // check that we borrowed max liquidity and borrower received usdc
    assert(usdc.balance_of(borrower) == liquidity, 'didnt_received_usdc');
}

/// # Function 
/// * borrow -> can_redeem
#[test]
#[should_panic(expected: ('c_insufficient_liquidity',))]
fn borrower_cannot_redeem_after_max_borrow() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let can_redeem = collateral.can_redeem(borrower, 1);
    assert(can_redeem == false, 'can_redeem_after_max_borrow');

    start_prank(collateral.contract_address, borrower);
    let cyg_lp_balance = collateral.balance_of(borrower);
    collateral.redeem(cyg_lp_balance, borrower, borrower);
    stop_prank(collateral.contract_address);
}

/// # Function 
/// * borrow -> can_borrow
#[test]
fn borrower_cannot_borrow_after_max_borrow() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let can_borrow = collateral.can_borrow(borrower, liquidity + 1);
    assert(can_borrow == false, 'can_borrow_after_max_borrow');
}

/// # Function 
/// * borrow -> transfer
#[test]
#[should_panic(expected: ('c_insufficient_liquidity',))]
fn collateral_is_locked_until_repaid_transfer() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let can_redeem = collateral.can_redeem(borrower, 1);
    assert(can_redeem == false, 'can_redeem_after_max_borrow');

    // Transfer
    start_prank(collateral.contract_address, borrower);
    let cyg_lp_balance = collateral.balance_of(borrower);
    collateral.transfer(0x123456789.try_into().unwrap(), 1);
    stop_prank(collateral.contract_address);
}

/// # Function 
/// * borrow -> transfer_from
#[test]
#[should_panic(expected: ('c_insufficient_liquidity',))]
fn collateral_is_locked_until_repaid_transfer_from() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let can_redeem = collateral.can_redeem(borrower, 1);
    assert(can_redeem == false, 'can_redeem_after_max_borrow');

    let new_user = 0x123456789.try_into().unwrap();

    // Approve new user
    start_prank(collateral.contract_address, borrower);
    collateral.approve(new_user, BoundedInt::max());
    stop_prank(collateral.contract_address);

    // transfer_from 1 token with new _user, should revert
    start_prank(collateral.contract_address, new_user);
    collateral.transfer_from(borrower, new_user, 1);
    stop_prank(collateral.contract_address);
}


/// # Function 
/// * borrow -> get_borrower_position
#[test]
fn borrower_has_100_percent_debt_ratio() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let (principal, borrow_balance, position_usd, health) = collateral
        .get_borrower_position(borrower);

    // user should have 100% debt ratio after borrowing max liquidity
    assert(health == 1_000000000_000000000, 'debt_ratio_not_max');
}

/// # Function 
/// * borrow -> get_account_liquidity
#[test]
fn borrower_has_0_account_liquidity_and_0_shortfall() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    // user should have 0 liquidity and 0 shortfall after borrowing max
    let (liquidity, shortfall) = collateral.get_account_liquidity(borrower);
    assert(liquidity == 0, 'acc_liquidity_not_zero');
    assert(shortfall == 0, 'acc_shortfall_not_zero');
}

/// # Function 
/// * borrow
///
/// # Reverts
/// * `b_insufficient_liquidity`
#[test]
#[should_panic(expected: ('b_insufficient_liquidity',))]
fn cannot_borrow_more_than_max_liquidity() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    // Borrow max + 1
    borrow(borrowable, collateral, lp_token, borrower, liquidity + 1);
}

/// Accrues interest correctly
#[test]
fn borrows_and_accrues_interest_correctly() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let (principal, borrow_balance) = borrowable.get_borrow_balance(borrower);

    assert(principal == liquidity, 'principal_not_updated');
    assert(borrow_balance == liquidity, 'borrow_balance_not_updated');

    start_warp(borrowable.contract_address, ONE_YEAR);
    // Accrue interest and syncs
    borrowable.accrue_interest();

    let borrow_rate = borrowable.borrow_rate();
    let total_borrows = borrowable.total_borrows();

    let (principal, borrow_balance_after) = borrowable.get_borrow_balance(borrower);

    assert(principal == liquidity, 'principal_accrued_interest');
    assert(borrow_balance_after > borrow_balance, 'did_not_accrue_interest');

    stop_warp(borrowable.contract_address);
}

#[test]
fn lenders_cyg_usd_accrues_correctly_without_payable_fn() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let (principal, borrow_balance) = borrowable.get_borrow_balance(borrower);

    assert(principal == liquidity, 'principal_not_updated');
    assert(borrow_balance == liquidity, 'borrow_balance_not_updated');

    let (cyg_usd_bal_before, rate_before, position_before) = borrowable.get_lender_position(lender);
    let borrow_rate_before = borrowable.borrow_rate();
    let supply_rate_before = borrowable.supply_rate();

    start_warp(borrowable.contract_address, ONE_YEAR);

    let (cyg_usd_bal, rate, position_usd) = borrowable.get_lender_position(lender);
    let er = borrowable.exchange_rate();
    let borrow_rate = borrowable.borrow_rate();
    let supply_rate = borrowable.supply_rate();

    assert(cyg_usd_bal == cyg_usd_bal_before, 'cyg_usd_increased');
    assert(rate > rate_before, 'rate_didnt_increase');
    assert(position_usd > position_before, 'position_usd_didnt_inc');
    assert(supply_rate > supply_rate_before, 'supply_rate_didnt_inc');
    assert(er == rate, 'rates_dont_match');

    stop_warp(borrowable.contract_address);
}

#[test]
fn lenders_cyg_usd_accrues_correctly() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let (principal, borrow_balance) = borrowable.get_borrow_balance(borrower);

    assert(principal == liquidity, 'principal_not_updated');
    assert(borrow_balance == liquidity, 'borrow_balance_not_updated');

    let (_, rate_before, position_before) = borrowable.get_lender_position(lender);

    start_warp(borrowable.contract_address, ONE_YEAR);

    borrowable.accrue_interest();

    let borrow_rate = borrowable.borrow_rate();
    let total_borrows = borrowable.total_borrows();

    let (principal, borrow_balance_after) = borrowable.get_borrow_balance(borrower);

    assert(principal == liquidity, 'principal_accrued_interest');
    assert(borrow_balance_after > borrow_balance, 'did_not_accrue_interest');

    let (_, rate_after, position_after) = borrowable.get_lender_position(lender);

    assert(position_after > position_before, 'did_not_increase');

    stop_warp(borrowable.contract_address);
}

/// Accrues interest correctly
#[test]
fn borrow_indices_are_correct() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let (principal, borrow_balance) = borrowable.get_borrow_balance(borrower);

    start_warp(borrowable.contract_address, ONE_YEAR);

    let borrow_rate_before = borrowable.borrow_rate();
    let (_, borrows_i, borrow_index_i, _,) = borrowable.borrow_indices();

    borrowable.accrue_interest();

    let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);
    let borrow_rate_after = borrowable.borrow_rate();

    /// Check total borrows increase
    assert(borrowable.total_borrows() == borrow_balance, 'total_borrows_dont_increase');
    assert(borrow_rate_before == borrow_rate_after, 'borrow_rates_dont_match');
    assert(borrows_i == borrowable.total_borrows(), 'borrow_i_is_correct');
    assert(borrow_index_i == borrowable.borrow_index(), 'borrow_index_i_is_correct');

    stop_warp(borrowable.contract_address);
}

#[test]
fn borrower_shortfalls_and_can_be_liquidated() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let (principal, borrow_balance) = borrowable.get_borrow_balance(borrower);

    start_warp(borrowable.contract_address, ONE_YEAR);

    let (liquidity, shortfall) = collateral.get_account_liquidity(borrower);
    assert(liquidity == 0, 'borrower_doesnt_shortfall');
    let can_redeem = collateral.can_redeem(borrower, 1);
    assert(can_redeem == false, 'borrower_can_redeem');

    stop_warp(borrowable.contract_address);
}

#[test]
fn borrower_borrows_half_liquidity() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity / 2);
    assert(collateral.can_borrow(borrower, liquidity + 1) == false, 'can_borrow_more');

    let (principal, borrow_balance) = borrowable.get_borrow_balance(borrower);

    let (liquidity_two, _) = collateral.get_account_liquidity(borrower);

    borrow(borrowable, collateral, lp_token, borrower, liquidity_two);
}


/// ----------------------------------------------------------------------------------
///                               INTERNAL LOGIC
/// ----------------------------------------------------------------------------------

fn borrow(
    borrowable: IBorrowableDispatcher,
    collateral: ICollateralDispatcher,
    lp_token: IERC20Dispatcher,
    borrower: ContractAddress,
    borrow_amount: u256
) {
    let leverage_calldata: LeverageCalldata = LeverageCalldata {
        lp_token_pair: lp_token.contract_address,
        collateral: collateral.contract_address,
        borrowable: borrowable.contract_address,
        recipient: borrower,
        lp_amount_min: 0
    };

    start_prank(borrowable.contract_address, borrower);
    borrowable.borrow(borrower, borrower, borrow_amount, leverage_calldata);
    stop_prank(borrowable.contract_address);
}


/// deposit 1 LP worth 3 USDC
fn deposit_lp_token(collateral: ICollateralDispatcher, lp_token: IERC20Dispatcher) {
    let borrower = borrower();
    start_prank(lp_token.contract_address, borrower);
    lp_token.approve(collateral.contract_address, BoundedInt::max());
    stop_prank(lp_token.contract_address);
    start_prank(collateral.contract_address, borrower);
    collateral.deposit(LP_DEPOSIT_AMOUNT, borrower);
    stop_prank(collateral.contract_address);
}

/// Deposit 1000 USDC
fn deposit_stablecoin(borrowable: IBorrowableDispatcher, usdc: IERC20Dispatcher) {
    let lender = lender();
    start_prank(usdc.contract_address, lender);
    usdc.approve(borrowable.contract_address, BoundedInt::max());
    stop_prank(usdc.contract_address);
    start_prank(borrowable.contract_address, lender);
    borrowable.deposit(USDC_DEPOSIT_AMOUNT, lender);
    stop_prank(borrowable.contract_address);
}

