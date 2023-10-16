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
use cygnus::data::calldata::{DeleverageCalldata};

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
/// * borrow -> can_redeem
#[test]
#[should_panic(expected: ('c_insufficient_liquidity',))]
fn borrower_cannot_redeem_mini_token() {
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
    collateral.redeem(1, borrower, borrower);
    stop_prank(collateral.contract_address);
}

/// # Function 
/// * borrow -> can_redeem
#[test]
#[should_panic(expected: ('c_insufficient_cyg_lp',))]
fn borrower_cannot_flash_redeem_mini_token() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Borrow max liquidity
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity);

    let can_redeem = collateral.can_redeem(borrower, 1);
    assert(can_redeem == false, 'can_redeem_after_max_borrow');

    let deleverage_calldata = DeleverageCalldata {
        lp_token_pair: Zeroable::zero(),
        collateral: Zeroable::zero(),
        borrowable: Zeroable::zero(),
        recipient: Zeroable::zero(),
        redeem_tokens: 0,
        usd_amount_min: 0,
    };

    start_prank(collateral.contract_address, borrower);
    collateral.flash_redeem(borrower, 1, deleverage_calldata);
    stop_prank(collateral.contract_address);
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

