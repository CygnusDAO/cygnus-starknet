// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash};
use integer::BoundedInt;

// Foundry
use snforge_std::{
    declare, start_prank, stop_prank, start_warp, stop_warp, CheatTarget, ContractClassTrait, ContractClass
};

// Cygnus
use tests::setup::{setup, setup_with_router};
use tests::users::{admin, borrower, lender};
use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};
use cygnus::periphery::altair_x::{IAltairXDispatcher, IAltairXDispatcherTrait};
use snforge_std::PrintTrait;

use cygnus::data::calldata::{LeverageCalldata, Aggregator};

const ONE_YEAR: u64 = 31536000;

#[test]
#[fork("MAINNET")]
fn assets_for_shares() {
    let (hangar18, borrowable, collateral, lp_token, usdc, altair) = setup_with_router();

    let shares = 1_000_000_000_000_000_000;

    let (amount0, amount1) = altair.get_assets_for_shares(lp_token.contract_address, shares);

    amount0.print();
    amount1.print();
}

#[test]
#[fork("MAINNET")]
fn borrower_borrows_max_liquidity() {
    let (hangar18, borrowable, collateral, lp_token, usdc, altair) = setup_with_router();

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(borrower, lp_token, collateral);
    deposit_usdc(lender, usdc, borrowable);

    let cyg_lp_balance = collateral.balance_of(borrower);
    let cyg_usd_balance = borrowable.balance_of(lender);

    assert(cyg_lp_balance > 0, 'wrong_cyglp_shares');
    assert(cyg_usd_balance > 0, 'wrong_cygusd_shares');

    let (liquidity, shortfall) = collateral.get_account_liquidity(borrower);

    let usd_bal_before = usdc.balanceOf(borrower);

    start_prank(CheatTarget::One(borrowable.contract_address), borrower);
    borrowable.approve(altair.contract_address, liquidity);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    start_prank(CheatTarget::One(altair.contract_address), borrower);
    altair.borrow(borrowable, liquidity, borrower, 100000000000000000);
    stop_prank(CheatTarget::One(altair.contract_address));

    let (a, b, c) = collateral.get_borrower_position(borrower);
    assert(c == 1_000_000_000_000_000_000, 'wrong debt');

    let usd_bal_after = usdc.balanceOf(borrower);

    assert(usd_bal_after - usd_bal_before == liquidity.into(), 'wrong');
}

#[test]
#[fork("MAINNET")]
fn borrower_leverage_usd_jediswap() {
    let (hangar18, borrowable, collateral, lp_token, usdc, altair) = setup_with_router();

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(borrower, lp_token, collateral);
    deposit_usdc(lender, usdc, borrowable);

    let cyg_lp_balance = collateral.balance_of(borrower);
    let cyg_usd_balance = borrowable.balance_of(lender);

    assert(cyg_lp_balance > 0, 'wrong_cyglp_shares');
    assert(cyg_usd_balance > 0, 'wrong_cygusd_shares');

    let (liquidity, shortfall) = collateral.get_account_liquidity(borrower);

    start_prank(CheatTarget::One(borrowable.contract_address), borrower);
    borrowable.approve(altair.contract_address, liquidity);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    // Set altair extension
    set_altair_xtension(hangar18, altair);

    start_prank(CheatTarget::One(altair.contract_address), borrower);

    let zero = array![];

    let balance_before = collateral.balance_of(borrower);

    altair
        .leverage(
            lp_token.contract_address,
            collateral.contract_address,
            borrowable.contract_address,
            liquidity,
            0,
            1000000000000,
            Aggregator::JEDISWAP,
            array![zero.span(), zero.span()]
        );

    stop_prank(CheatTarget::One(altair.contract_address));

    let lp_price = collateral.get_lp_token_price();
    let balance_after = collateral.balance_of(borrower);

    // We want to make sure that the amount of LP received is equivalent to the borrowed amount of USDC 
    // So if we borrowed $100 and each LP is worth $10, we make sure that we received at least 9.8 LP Tokens
    let slippage = liquidity - liquidity / 50; // 2%
    let lps_received = balance_after - balance_before;

    assert(lps_received * lp_price >= slippage, 'too much slippage');
}

#[test]
#[fork("MAINNET")]
fn borrower_deleverages_jediswap() {
    let (hangar18, borrowable, collateral, lp_token, usdc, altair) = setup_with_router();

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(borrower, lp_token, collateral);
    deposit_usdc(lender, usdc, borrowable);

    let cyg_lp_balance = collateral.balance_of(borrower);
    let cyg_usd_balance = borrowable.balance_of(lender);

    assert(cyg_lp_balance > 0, 'wrong_cyglp_shares');
    assert(cyg_usd_balance > 0, 'wrong_cygusd_shares');

    let (liquidity, shortfall) = collateral.get_account_liquidity(borrower);

    start_prank(CheatTarget::One(borrowable.contract_address), borrower);
    borrowable.approve(altair.contract_address, liquidity);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    // Set altair extension
    set_altair_xtension(hangar18, altair);

    start_prank(CheatTarget::One(altair.contract_address), borrower);

    let zero = array![];

    let balance_before = collateral.balance_of(borrower);

    altair
        .leverage(
            lp_token.contract_address,
            collateral.contract_address,
            borrowable.contract_address,
            liquidity,
            0,
            1000000000000,
            Aggregator::JEDISWAP,
            array![zero.span(), zero.span()]
        );

    stop_prank(CheatTarget::One(altair.contract_address));

    let lp_price = collateral.get_lp_token_price();
    let balance_after = collateral.balance_of(borrower);

    // We want to make sure that the amount of LP received is equivalent to the borrowed amount of USDC 
    // So if we borrowed $100 and each LP is worth $10, we make sure that we received at least 9.8 LP Tokens
    let slippage = liquidity - liquidity / 50; // 2%
    let lps_received = balance_after - balance_before;

    assert(lps_received * lp_price >= slippage, 'too much slippage');

    start_prank(CheatTarget::One(collateral.contract_address), borrower);
    collateral.approve(altair.contract_address, lps_received);
    stop_prank(CheatTarget::One(collateral.contract_address));

    start_prank(CheatTarget::One(altair.contract_address), borrower);

    let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);

    altair
        .deleverage(
            lp_token.contract_address,
            collateral.contract_address,
            borrowable.contract_address,
            lps_received,
            0,
            1000000000000,
            Aggregator::JEDISWAP,
            array![zero.span(), zero.span()]
        );

    stop_prank(CheatTarget::One(altair.contract_address));

    let (_, borrow_balance_after) = borrowable.get_borrow_balance(borrower);

    assert(borrow_balance_after < borrow_balance, 'didnt_repay');
}

// ------------------------------------------------------------------------------------------------------------------

fn set_altair_xtension(hangar18: IHangar18Dispatcher, altair: IAltairDispatcher) {
    let contract = declare('AltairX');
    let constructor_calldata: Array<felt252> = array![
        hangar18.contract_address.into(), altair.contract_address.into(), contract.class_hash.into()
    ];
    let contract_address: ContractAddress = contract.deploy(@constructor_calldata).unwrap();

    let altair_x = IAltairXDispatcher { contract_address };

    let admin = admin();

    start_prank(CheatTarget::One(altair.contract_address), admin);
    altair.set_altair_extension(array![0], altair_x);
    stop_prank(CheatTarget::One(altair.contract_address));
}

fn deposit_lp_token(borrower: ContractAddress, lp_token: IERC20Dispatcher, collateral: ICollateralDispatcher) {
    // Approve LP
    start_prank(CheatTarget::One(lp_token.contract_address), borrower);
    lp_token.approve(collateral.contract_address.into(), BoundedInt::max());
    stop_prank(CheatTarget::One(lp_token.contract_address));

    let deposit_amount = lp_token.balanceOf(borrower);
    // Deposit in collateral
    start_prank(CheatTarget::One(collateral.contract_address), borrower);
    collateral.deposit(deposit_amount.try_into().unwrap(), borrower);
    stop_prank(CheatTarget::One(collateral.contract_address));
}

fn deposit_usdc(lender: ContractAddress, usdc: IERC20Dispatcher, borrowable: IBorrowableDispatcher) {
    // Approve LP
    start_prank(CheatTarget::One(usdc.contract_address), lender);
    usdc.approve(borrowable.contract_address.into(), BoundedInt::max());
    stop_prank(CheatTarget::One(usdc.contract_address));

    let deposit_amount = usdc.balanceOf(lender);

    // Deposit in collateral
    start_prank(CheatTarget::One(borrowable.contract_address), lender);
    borrowable.deposit(deposit_amount.try_into().unwrap(), lender);
    stop_prank(CheatTarget::One(borrowable.contract_address));
}
