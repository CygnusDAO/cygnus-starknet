// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash,};
use integer::BoundedInt;

// Foundry
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait};

// Cygnus
use cygnus::tests::setup::{setup};
use cygnus::tests::users::{admin, borrower, lender};
use cygnus::token::erc20::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};

/// ----------------------------------------------------------------------------------
///                               COLLATERAL MODEL
/// ----------------------------------------------------------------------------------

/// +----------------------------+----------------------------------------------------+
/// | exchange_rate              | total_balance / total_supply                       |
/// +----------------------------+----------------------------------------------------+
/// | position_usd               | cyg_lp_balance * exchange_rate * lp_price          |
/// +----------------------------+----------------------------------------------------+
/// | liquidation_penalty        | liquidation_fee + liquidation_incentive            |
/// +----------------------------+----------------------------------------------------+
/// | max_liquidity              | (position_usd * debt_ratio) / liq. penalty         |
/// +----------------------------+----------------------------------------------------+
/// | liquidity                  | max_liquidity - borrow_balance                     |
/// +----------------------------+----------------------------------------------------+
/// | shortfall                  | borrow_balance - max_liquidity                     |
/// +----------------------------+----------------------------------------------------+
/// | principal                  | borrow_balance - interest_accrued                  |
/// +----------------------------+----------------------------------------------------+
/// | health                     | borrow_balance / max_liquidity                     |
/// +----------------------------+----------------------------------------------------+

/// 1 LP
const lp_deposit_amount: u256 = 1_000000000_000000000;
/// 1000 USDC
const usdc_deposit_amount: u256 = 1000_000000000_000000000;
/// 3 USDC (TODO: Implement oracle - atm this is fixed to 3 usdc in the `oracle.cairo` contract)
const lp_price: u256 = 3_000000000_000000000;
/// 1e18
const ONE: u256 = 1_000000000_000000000;

#[test]
fn has_correct_exchange_rate() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);
    assert(collateral.exchange_rate() == 1_000_000_000_000_000_000, 'wrong_exchange_rate');
}

// Test: get_borrower_position
#[test]
fn has_correct_borrower_position_without_borrows() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();
    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // position_usd = cyg_lp_balance * exchange_rate * lp_price
    // max_liquidity = (position_usdc * debt_ratio) / liq_penalty
    // health = borrow_balance / max_liquidity

    let debt_ratio = collateral.debt_ratio();
    let liq_penalty = collateral.liquidation_incentive() + collateral.liquidation_fee();
    let lp_token_price = collateral.get_lp_token_price();
    let cyg_lp_balance = collateral.balance_of(borrower);
    let exchange_rate = collateral.exchange_rate();

    let calc_position_usd = ((cyg_lp_balance * exchange_rate) / ONE * lp_token_price) / ONE;
    let calc_max_liquidity = (calc_position_usd * debt_ratio) / liq_penalty;

    let (principal, borrow_balance, position_usd, health) = collateral
        .get_borrower_position(borrower);

    assert(principal == 0, 'principal_not_zero');
    assert(borrow_balance == 0, 'borrow_balance_not_zero');
    assert(position_usd == calc_position_usd, 'incorrect_position_usd');
    assert(health == 0, 'health_not_zero_no_borrows');
}

// Test: get_account_liquidity
#[test]
fn has_correct_account_liquidity_without_borrows() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // max_liquidity = (position_usd * debt_ratio) / liquidation_penalty
    // liquidity = max_liquidity - borrow_balance 
    // shortfall = borrow_balance - max_liquidity
    let debt_ratio = collateral.debt_ratio();
    let liq_penalty = collateral.liquidation_incentive() + collateral.liquidation_fee();
    let lp_token_price = collateral.get_lp_token_price();
    let cyg_lp_balance = collateral.balance_of(borrower);
    let exchange_rate = collateral.exchange_rate();

    // Calculate
    // calc_liquidity = calc_max_liquidity - borrow_balance (0)
    let calc_position_usd = ((cyg_lp_balance * exchange_rate) / ONE * lp_token_price) / ONE;
    let calc_max_liquidity = (calc_position_usd * debt_ratio) / liq_penalty;

    // Get contract vars
    let (liquidity, shortfall) = collateral.get_account_liquidity(borrower);

    assert(liquidity == calc_max_liquidity, 'liquidity_not_correct');
    assert(shortfall == 0, 'shortfall_not_zero');
}

// Test: can_borrow
#[test]
fn can_borrow_max_liquidity() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();

    let borrower = borrower();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // max_liquidity = (position_usd * debt_ratio) / liquidation_penalty
    // liquidity = max_liquidity - borrow_balance 
    // shortfall = borrow_balance - max_liquidity
    let debt_ratio = collateral.debt_ratio();
    let liq_penalty = collateral.liquidation_incentive() + collateral.liquidation_fee();
    let lp_token_price = collateral.get_lp_token_price();
    let cyg_lp_balance = collateral.balance_of(borrower);
    let exchange_rate = collateral.exchange_rate();

    // Calculate
    // calc_liquidity = calc_max_liquidity - borrow_balance (0)
    let calc_position_usd = ((cyg_lp_balance * exchange_rate) / ONE * lp_token_price) / ONE;
    let calc_max_liquidity = (calc_position_usd * debt_ratio) / liq_penalty;

    // Get contract vars
    let can_borrow_max: bool = collateral.can_borrow(borrower, calc_max_liquidity);

    assert(can_borrow_max == true, 'cannot_borrow_max_liq')
}

// Test: can_redeem
#[test]
fn can_redeem_whole_balance() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();
    let borrower = borrower();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Get cygLP balance 
    let cyg_lp_balance = collateral.balance_of(borrower);

    // Should be able to redeem whole balance since no borrows
    let can_redeem_max: bool = collateral.can_redeem(borrower, cyg_lp_balance);

    assert(can_redeem_max == true, 'cannot_redeem_max');
}

// Test: can_redeem
#[test]
fn cannot_redeem_more_than_whole_balance() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();

    let borrower = borrower();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Get cygLP balance 
    let cyg_lp_balance = collateral.balance_of(borrower) + 1;

    // Should be able to redeem whole balance since no borrows
    let can_redeem_max: bool = collateral.can_redeem(borrower, cyg_lp_balance);

    assert(can_redeem_max == false, 'cannot_redeem_more');
}

// Test: redeem
#[test]
#[should_panic(expected: ('c_insufficient_liquidity',))]
fn redeem_false_returns_insufficient_liquidity() {
    let (_, borrowable, collateral, lp_token, usdc) = setup();

    let borrower = borrower();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);

    // Get cygLP balance 
    let cyg_lp_balance = collateral.balance_of(borrower) + 1;

    start_prank(collateral.contract_address, borrower);
    collateral.redeem(cyg_lp_balance, borrower, borrower);
    stop_prank(collateral.contract_address);
}

/// deposit 1 LP worth 3 USDC
fn deposit_lp_token(collateral: ICollateralDispatcher, lp_token: IERC20Dispatcher) {
    let borrower = borrower();

    start_prank(lp_token.contract_address, borrower);
    lp_token.approve(collateral.contract_address, BoundedInt::max());
    stop_prank(lp_token.contract_address);

    start_prank(collateral.contract_address, borrower);
    collateral.deposit(lp_deposit_amount, borrower);
    stop_prank(collateral.contract_address);
}

/// Deposit 1000 USDC
fn deposit_stablecoin(borrowable: IBorrowableDispatcher, usdc: IERC20Dispatcher) {
    let lender = lender();

    start_prank(usdc.contract_address, lender);
    usdc.approve(borrowable.contract_address, BoundedInt::max());
    stop_prank(usdc.contract_address);

    start_prank(borrowable.contract_address, lender);
    borrowable.deposit(usdc_deposit_amount, lender);
    stop_prank(borrowable.contract_address);
}

