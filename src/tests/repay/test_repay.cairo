use cygnus::data::calldata::{LeverageCalldata};

// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash};

// Foundry
use snforge_std::{declare, start_prank, stop_prank, start_warp, stop_warp};

// Cygnus
use cygnus::tests::setup::{setup_with_router};
use cygnus::tests::users::{admin, borrower, lender};
use cygnus::token::erc20::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};
use integer::BoundedInt;

/// ----------------------------------------------------------------------------------
///                               ALTAIR ROUTER TEST                                             
/// ----------------------------------------------------------------------------------
use snforge_std::io::PrintTrait;

/// Borrower deposits 1 LP
const LP_DEPOSIT_AMOUNT: u256 = 1_000000000_000000000;

/// Lender deposits 10 USDC
const USDC_DEPOSIT_AMOUNT: u256 = 10_000000000_000000000;

/// Random
const DEADLINE: u64 = 1092418421;

const ONE_YEAR: u64 = 31536000;


/// # Function 
/// * borrow -> balance_of
#[test]
fn borrower_repays_full_loan_with_router() {
    let (_, borrowable, collateral, lp_token, usdc, altair) = setup_with_router();

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    /// Grant usd allowance and borrow allowance
    grant_usd_allowance_to_router(usdc, borrower, altair);
    grant_borrow_allowance(borrowable, borrower, altair);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);

    borrow(borrowable, collateral, lp_token, borrower, liquidity, altair);

    // check that we borrowed max liquidity and borrower received usdc
    assert(usdc.balance_of(borrower) == liquidity, 'didnt_received_usdc');

    let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);

    // Transfer usdc to borrower
    start_prank(usdc.contract_address, lender);
    usdc.transfer(borrower, borrow_balance.into());
    stop_prank(usdc.contract_address);

    // Allow periphery to use lp token
    start_prank(lp_token.contract_address, borrower);
    lp_token.approve(altair.contract_address, BoundedInt::max());
    stop_prank(lp_token.contract_address);

    start_warp(borrowable.contract_address, ONE_YEAR);
    let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);
    /// repay
    repay(borrowable, borrower, altair, borrow_balance);

    let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);
    assert(borrow_balance == 0, 'borrow_balance_didnt_dec');

    stop_warp(borrowable.contract_address);
}

/// # Function 
/// * borrow -> balance_of
#[test]
fn total_borrows_and_index_update_after_repay() {
    let (_, borrowable, collateral, lp_token, usdc, altair) = setup_with_router();

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    /// Grant usd allowance and borrow allowance
    grant_usd_allowance_to_router(usdc, borrower, altair);
    grant_borrow_allowance(borrowable, borrower, altair);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);

    borrow(borrowable, collateral, lp_token, borrower, liquidity, altair);

    // check that we borrowed max liquidity and borrower received usdc
    assert(usdc.balance_of(borrower) == liquidity, 'didnt_received_usdc');

    let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);

    // Transfer usdc to borrower
    start_prank(usdc.contract_address, lender);
    usdc.transfer(borrower, borrow_balance.into());
    stop_prank(usdc.contract_address);

    // Allow periphery to use lp token
    start_prank(lp_token.contract_address, borrower);
    lp_token.approve(altair.contract_address, BoundedInt::max());
    stop_prank(lp_token.contract_address);

    start_warp(borrowable.contract_address, ONE_YEAR);
    let (principal, borrow_balance) = borrowable.get_borrow_balance(borrower);
    /// repay
    repay(borrowable, borrower, altair, borrow_balance);

    let borrows = borrowable.total_borrows();
    let balance = borrowable.total_balance();

    let borrow_rate = borrowable.borrow_rate();
    let supply_rate = borrowable.supply_rate();

    let util = borrowable.utilization_rate();

    assert(util == 0, 'util_didnt_update');
    assert(borrows == 0, 'borrows_didnt_update');
    assert(supply_rate == 0, 'supply_didnt_update');
    assert(balance == USDC_DEPOSIT_AMOUNT + (borrow_balance - principal), 'balance_didnt_update');

    let base_rate_per_second = 10000000000000000 / (24 * 60 * 60 * 365);
    assert(borrow_rate == base_rate_per_second, 'borrow_rate_incorrect');

    stop_warp(borrowable.contract_address);
}

fn repay(
    borrowable: IBorrowableDispatcher,
    borrower: ContractAddress,
    altair: IAltairDispatcher,
    repay_amount: u256
) {
    start_prank(altair.contract_address, borrower);
    altair.repay(borrowable.contract_address, repay_amount, borrower, DEADLINE);
    stop_prank(altair.contract_address);
}

fn borrow(
    borrowable: IBorrowableDispatcher,
    collateral: ICollateralDispatcher,
    lp_token: IERC20Dispatcher,
    borrower: ContractAddress,
    borrow_amount: u256,
    altair: IAltairDispatcher
) {
    start_prank(altair.contract_address, borrower);
    altair.borrow(borrowable.contract_address, borrow_amount, borrower, DEADLINE);
    stop_prank(altair.contract_address);
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

fn grant_usd_allowance_to_router(
    usd: IERC20Dispatcher, borrower: ContractAddress, altair: IAltairDispatcher
) {
    start_prank(usd.contract_address, borrower);
    usd.approve(altair.contract_address, BoundedInt::max());
    stop_prank(usd.contract_address);
}

fn grant_borrow_allowance(
    borrowable: IBorrowableDispatcher, borrower: ContractAddress, altair: IAltairDispatcher
) {
    start_prank(borrowable.contract_address, borrower);
    borrowable.approve(altair.contract_address, BoundedInt::max());
    stop_prank(borrowable.contract_address);
}

fn test_array() {
    let num_one: u64 = 10;
}

fn get_array(num_one: u64) {}
