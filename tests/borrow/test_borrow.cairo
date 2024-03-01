// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash, get_tx_info};
use integer::BoundedInt;

// Foundry
use snforge_std::{declare, start_prank, stop_prank, start_warp, stop_warp, CheatTarget};

// Cygnus
use tests::setup::{setup_with_router, setup};
use tests::users::{admin, borrower, lender};
use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};
use snforge_std::PrintTrait;

use cygnus::data::calldata::{LeverageCalldata, Aggregator};

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

/// BLOCK_TIMESTAMP: 1699658109;

const ONE_YEAR: u64 = 31536000;

#[test]
#[fork("MAINNET")]
fn borrower_borrows_max_liquidity() {
    let (hangar18, borrowable, collateral, lp_token, usdc) = setup();

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
    borrowable.borrow(borrower, borrower, liquidity, Default::default());
    stop_prank(CheatTarget::One(borrowable.contract_address));

    let (a, b, c) = collateral.get_borrower_position(borrower);
    assert(c == 1_000_000_000_000_000_000, 'wrong debt');
}

#[test]
#[fork("MAINNET")]
fn borrower_borrows_max_liquidity_with_router() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router) = setup_with_router();

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(borrower, lp_token, collateral);
    deposit_usdc(lender, usdc, borrowable);

    let cyg_lp_balance = collateral.balance_of(borrower);
    let cyg_usd_balance = borrowable.balance_of(lender);

    assert(cyg_lp_balance > 0, 'wrong_cyglp_shares');
    assert(cyg_usd_balance > 0, 'wrong_cygusd_shares');

    let (liquidity, shortfall) = collateral.get_account_liquidity(borrower);

    let usdc_before = usdc.balanceOf(borrower);
    start_prank(CheatTarget::One(borrowable.contract_address), borrower);
    borrowable.approve(router.contract_address, 1_000_000_000000); // 1M USDC
    stop_prank(CheatTarget::One(borrowable.contract_address));

    start_prank(CheatTarget::One(router.contract_address), borrower);
    router.borrow(borrowable, liquidity, borrower, 100000000000000);
    stop_prank(CheatTarget::One(router.contract_address));
    let usdc_after = usdc.balanceOf(borrower);

    let (a, b, c) = collateral.get_borrower_position(borrower);
    assert(c == 1_000_000_000_000_000_000, 'wrong debt');
    assert(usdc_after - usdc_before == liquidity.into(), 'wrong usdc amount');
}

#[test]
#[fork("MAINNET")]
#[should_panic(expected: ('u128_sub Overflow',))]
fn fails_if_receiver_is_not_approved() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router) = setup_with_router();

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(borrower, lp_token, collateral);
    deposit_usdc(lender, usdc, borrowable);

    let cyg_lp_balance = collateral.balance_of(borrower);
    let cyg_usd_balance = borrowable.balance_of(lender);

    assert(cyg_lp_balance > 0, 'wrong_cyglp_shares');
    assert(cyg_usd_balance > 0, 'wrong_cygusd_shares');

    let (liquidity, shortfall) = collateral.get_account_liquidity(borrower);

    let usdc_before = usdc.balanceOf(borrower);

    start_prank(CheatTarget::One(router.contract_address), borrower);
    router.borrow(borrowable, liquidity, borrower, 100000000000000);
    stop_prank(CheatTarget::One(router.contract_address));
}

#[test]
#[fork("MAINNET")]
fn leverages_usdc_using_avnu() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router) = setup_with_router();

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(borrower, lp_token, collateral);
    deposit_usdc(lender, usdc, borrowable);

    let cyg_lp_balance = collateral.balance_of(borrower);
    let cyg_usd_balance = borrowable.balance_of(lender);

    assert(cyg_lp_balance > 0, 'wrong_cyglp_shares');
    assert(cyg_usd_balance > 0, 'wrong_cygusd_shares');

    let (liquidity, shortfall) = collateral.get_account_liquidity(borrower);

    let usdc_before = usdc.balanceOf(borrower);
    start_prank(CheatTarget::One(borrowable.contract_address), borrower);
    borrowable.approve(router.contract_address, 1_000_000_000000); // 1M USDC
    stop_prank(CheatTarget::One(borrowable.contract_address));

    let cyg_lp_bal_before = collateral.balanceOf(borrower);
    start_prank(CheatTarget::One(router.contract_address), borrower);

    // This is just copied calldata from avnu, check the scripts folder
    let calls0 = array![
        0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8,
        0x1312d00,
        0x0,
        0xda114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3,
        0x11650fd3254d532ad,
        0x0,
        0x8b287e992a6a9956,
        0x0,
        0x7e53b99d04295f3cc14d891892bf0dba19d656e84f9d14ad8e21d50c159769f,
        0x0,
        0x0,
        0x1,
        0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8,
        0xda114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3,
        0x5dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b,
        0x64,
        0x6,
        0xda114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3,
        0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8,
        0x68db8bac710cb4000000000000000,
        0xc8,
        0x0,
        0x337d07c3547801dd8c024f1cd
    ];

    let calls1 = array![
        0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8,
        0x1312d00,
        0x0,
        0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7,
        0x1ee835305397e0,
        0x0,
        0xf741a9829cbf0,
        0x0,
        0x7e53b99d04295f3cc14d891892bf0dba19d656e84f9d14ad8e21d50c159769f,
        0x0,
        0x0,
        0x1,
        0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8,
        0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7,
        0x10884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28,
        0x64,
        0x1,
        0x1
    ];

    let res = router
        .leverage(
            lp_token.contract_address,
            collateral.contract_address,
            borrowable.contract_address,
            40_000000,
            0,
            1000000000000,
            Aggregator::AVNU,
            array![calls0.span(), calls1.span()]
        );
    stop_prank(CheatTarget::One(router.contract_address));
    let usdc_after = usdc.balanceOf(borrower);

    let (a, b, c) = collateral.get_borrower_position(borrower);
    assert(c != 1_000_000_000_000_000_000, 'wrong debt');

    let lp_token_price = collateral.get_lp_token_price();

    let cyg_lp_bal_after = collateral.balanceOf(borrower);
}

#[test]
#[fork("MAINNET")]
fn reserves_accumulate_correctly() {
    let (hangar18, borrowable, collateral, lp_token, usdc) = setup();

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
    borrowable.borrow(borrower, borrower, liquidity, Default::default());
    stop_prank(CheatTarget::One(borrowable.contract_address));

    let timestamp = hangar18.block_timestamp();

    let dao_reserves_before = borrowable.balance_of(hangar18.dao_reserves());
    assert(dao_reserves_before == 0, 'reserves not zero');

    start_warp(CheatTarget::One(borrowable.contract_address), timestamp + 31536000);
    borrowable.accrue_interest();
    let dao_reserves_after = borrowable.balance_of(hangar18.dao_reserves());
    assert(dao_reserves_after > dao_reserves_before, 'reserves didnt increase');
    stop_warp(CheatTarget::One(borrowable.contract_address));
}

#[test]
#[fork("MAINNET")]
#[should_panic(expected: ('insufficient_liquidity',))]
fn borrower_exceeds_and_fails() {
    let (hangar18, borrowable, collateral, lp_token, usdc) = setup();

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(borrower, lp_token, collateral);
    deposit_usdc(lender, usdc, borrowable);

    let cyg_lp_balance = collateral.balance_of(borrower);
    let cyg_usd_balance = borrowable.balance_of(lender);

    assert(cyg_lp_balance > 0, 'wrong_cyglp_shares');
    assert(cyg_usd_balance > 0, 'wrong_cygusd_shares');

    let (liquidity, shortfall) = collateral.get_account_liquidity(borrower);

    let arr: Array<Span<felt252>> = array![];

    start_prank(CheatTarget::One(borrowable.contract_address), borrower);
    borrowable.borrow(borrower, borrower, liquidity + 1, Default::default());
    stop_prank(CheatTarget::One(borrowable.contract_address));

    let (a, b, c) = collateral.get_borrower_position(borrower);
    assert(c == 1_000_000_000_000_000_000, 'wrong debt');
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
