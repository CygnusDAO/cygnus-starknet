use cygnus::data::calldata::{LeverageCalldata};

// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash};

// Foundry
use snforge_std::{declare, start_prank, stop_prank};

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

/// Borrower deposits 1 LP
const LP_DEPOSIT_AMOUNT: u256 = 1_000000000_000000000;

/// Lender deposits 10 USDC
const USDC_DEPOSIT_AMOUNT: u256 = 10_000000000_000000000;

/// Random
const DEADLINE: u64 = 1092418421;

/// # Function 
/// * borrow -> balance_of
#[test]
#[should_panic(expected: ('u256_sub Overflow',))]
fn reverts_if_borrower_has_no_borrow_allowance() {
    let (_, borrowable, collateral, lp_token, usdc, altair) = setup_with_router();

    let borrower = borrower();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    /// Grant usd allowance but don't grant borrow allowance
    grant_usd_allowance_to_router(usdc, borrower, altair);

    let (liquidity, _) = collateral.get_account_liquidity(borrower);

    borrow(borrowable, collateral, lp_token, borrower, liquidity, altair);

    // check that we borrowed max liquidity and borrower received usdc
    assert(usdc.balance_of(borrower) == liquidity, 'didnt_received_usdc');
}

/// # Function 
/// * borrow -> balance_of
#[test]
fn borrower_borrows_max_liquidity() {
    let (_, borrowable, collateral, lp_token, usdc, altair) = setup_with_router();

    let borrower = borrower();

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
