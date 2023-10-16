// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash};

// Foundry
use snforge_std::{declare, start_prank, stop_prank, start_warp, stop_warp};

// Cygnus
use cygnus::tests::setup::{setup_with_pillars};
use cygnus::tests::users::{admin, borrower, lender, second_lender};
use cygnus::token::erc20::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};
use cygnus::token::erc20::cyg::{ICygnusDAODispatcher, ICygnusDAODispatcherTrait};
use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::rewarder::pillars::{IPillarsOfCreationDispatcher, IPillarsOfCreationDispatcherTrait};
use cygnus::data::signed_integer::{i256::{i256, i256TryIntou256}, integer_trait::{IntegerTrait}};
use integer::BoundedInt;

use snforge_std::io::PrintTrait;

/// -------------------------------------------------------------------------------------------------
///                                       CYG EMISSION REWARDS TEST
/// -------------------------------------------------------------------------------------------------

/// Borrower deposits 1 LP
const LP_DEPOSIT_AMOUNT: u256 = 1_000000000_000000000;

/// Lender deposits 10 USDC
const USDC_DEPOSIT_AMOUNT: u256 = 10_000000000_000000000;

/// Random
const DEADLINE: u64 = 1092418421;

const ONE: u256 = 1_000000000_000000000;

#[test]
#[should_panic(expected: ('only_admin',))]
fn only_admin_can_set_up_lend_rewards() {
    let (_, borrowable, collateral, _, _, _, _, pillars) = setup_with_pillars();

    /// Random address
    let lender = lender();

    let alloc_point = 1000;

    start_prank(pillars.contract_address, lender);
    pillars.set_lending_rewards(borrowable.contract_address, alloc_point);
    stop_prank(pillars.contract_address);
}

#[test]
#[should_panic(expected: ('only_admin',))]
fn only_admin_can_set_up_borrow_rewards() {
    let (_, borrowable, collateral, _, _, _, _, pillars) = setup_with_pillars();

    /// Random address
    let lender = lender();

    let alloc_point = 1000;

    start_prank(pillars.contract_address, lender);
    pillars
        .set_borrow_rewards(borrowable.contract_address, collateral.contract_address, alloc_point);
    stop_prank(pillars.contract_address);
}

#[test]
fn admin_sets_lend_rewards() {
    let (_, borrowable, collateral, _, _, _, _, pillars) = setup_with_pillars();

    /// Random address
    let admin = admin();

    let alloc_point = 1000;

    start_prank(pillars.contract_address, admin);
    pillars.set_lending_rewards(borrowable.contract_address, alloc_point);
    stop_prank(pillars.contract_address);

    assert(pillars.all_shuttles_length() == 1, 'shuttle_not_added');

    let shuttle = pillars.get_shuttle_info(borrowable.contract_address, Zeroable::zero());

    assert(shuttle.active == true, 'not_active');
}

#[test]
fn admin_sets_borrow_rewards() {
    let (_, borrowable, collateral, _, _, _, _, pillars) = setup_with_pillars();

    /// Random address
    let admin = admin();

    let p = 1000;
    start_prank(pillars.contract_address, admin);
    pillars.set_borrow_rewards(borrowable.contract_address, collateral.contract_address, p);
    stop_prank(pillars.contract_address);

    assert(pillars.all_shuttles_length() == 1, 'shuttle_not_added');

    let shuttle = pillars
        .get_shuttle_info(borrowable.contract_address, collateral.contract_address);

    assert(shuttle.active == true, 'not_active');
}

#[test]
fn shuttle_gets_stored_correctly_after_init() {
    let (_, borrowable, collateral, _, _, _, cyg_token, pillars) = setup_with_pillars();

    /// Set borrow and lend rewards
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// Borrow Rewards
    let shuttle = pillars
        .get_shuttle_info(borrowable.contract_address, collateral.contract_address);
    assert(shuttle.active == true, 'shuttle_not_active');
    assert(shuttle.shuttle_id == 0, 'id_not_correct');
    assert(shuttle.borrowable == borrowable.contract_address, 'wrong_borrowable');
    assert(shuttle.collateral == collateral.contract_address, 'wrong_collateral');
    assert(shuttle.total_shares == 0, 'wrong_shares');
    assert(shuttle.acc_reward_per_share == 0, 'wrong_acc');
    assert(shuttle.alloc_point == 10000, 'wrong_alloc_point');
    assert(shuttle.pillars_id == 0, 'wrong_pillars_id');

    /// Lend Rewards
    let shuttle = pillars.get_shuttle_info(borrowable.contract_address, Zeroable::zero());
    assert(shuttle.active == true, 'shuttle_not_active');
    assert(shuttle.shuttle_id == 0, 'id_not_correct');
    assert(shuttle.borrowable == borrowable.contract_address, 'wrong_borrowable');
    assert(shuttle.collateral == Zeroable::zero(), 'wrong_collateral');
    assert(shuttle.total_shares == 0, 'wrong_shares');
    assert(shuttle.acc_reward_per_share == 0, 'wrong_acc');
    assert(shuttle.alloc_point == 10000, 'wrong_alloc_point');
    assert(shuttle.pillars_id == 1, 'wrong_pillars_id');

    /// Total points
    assert(pillars.total_alloc_point() == 20000, 'wrong_total_alloc');
}

/// Assert that CygLP depositors receive rewards only for borrowing
#[test]
fn borrowers_receives_no_rewards_if_they_dont_borrow() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// 1. Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// 2. Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    /// 3. Get user info
    let borrower = borrower();
    let user_info = pillars
        .get_user_info(borrowable.contract_address, collateral.contract_address, borrower);

    /// 4. Confirm lender has deposited USDC amount of shares
    assert(user_info.shares.is_zero(), 'wrong_shares');
    assert(user_info.reward_debt.is_zero(), 'wrong_reward_debt');

    /// 5. Mine to half the epoch length
    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    let pending = pillars
        .pending_cyg(borrowable.contract_address, collateral.contract_address, borrower);
    assert(pending == 0, 'wrong_cyg_borrower');
    let pending = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), borrower);
    assert(pending == 0, 'wrong_cyg_borrower');
    stop_warp(pillars.contract_address);
}

/// We warp to 50% of epoch 0.
/// We gave same alloc points to borrow and lend shuttle in `initialize_pillars()`
///
/// borrow/lend rewards at epoch 0 = 40,351 CYG (see `test_pillars_storage`)
///
/// borrow rewards at epoch 0      = 40,351 / 2 = 20,175.5 CYG
/// lend rewards at epoch 0        = 40,351 / 2 = 20,175.5 CYG
///
/// At 50% of the epoch, the lender should be able to claim 50% of the lend reward = 10,087.25
#[test]
fn lenders_receive_cyg_rewards_when_depositing() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// 1. Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// 2. Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    /// 3. Get user info
    let lender = lender();
    let user_info = pillars.get_user_info(borrowable.contract_address, Zeroable::zero(), lender);

    /// 4. Confirm lender has deposited USDC amount of shares
    assert(user_info.shares == USDC_DEPOSIT_AMOUNT, 'wrong_shares');
    assert(user_info.reward_debt.is_zero(), 'wrong_reward_debt');

    /// 5. Mine to half the epoch length
    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    let pending = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), lender);
    assert(pending > 10087 * ONE && pending < 10088 * ONE, 'wrong_cyg_lender');
    let pending = pillars
        .pending_cyg(borrowable.contract_address, collateral.contract_address, lender);
    assert(pending == 0, 'wrong_cyg_lender');
    stop_warp(pillars.contract_address);
}

#[test]
fn bororwers_receive_cyg_rewards_when_borrowing() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// 1. Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// 2. Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    /// 3. Borrower borrows
    let borrower = borrower();
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    let usd_bal = usdc.balance_of(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity, altair);
    assert(usdc.balance_of(borrower) == liquidity.into() + usd_bal, 'didnt_receive_usd');

    /// 4. Get user info
    let user_info = pillars
        .get_user_info(borrowable.contract_address, collateral.contract_address, borrower);

    /// 5. Confirm borrower has shares equal to their borrowed amount
    assert(user_info.shares == liquidity, 'wrong_shares');
    assert(user_info.reward_debt.is_zero(), 'wrong_reward_debt');

    /// 6. Mine to half the epoch length
    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    let pending = pillars
        .pending_cyg(borrowable.contract_address, collateral.contract_address, borrower);
    assert(pending > 10087 * ONE && pending < 10088 * ONE, 'wrong_cyg_lender');
    let pending = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), borrower);
    assert(pending == 0, 'wrong_cyg_lender');
    stop_warp(pillars.contract_address);
}

#[test]
fn lender_collects_and_receives_cyg() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// 1. Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// 2. Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    /// 3. Get user info
    let lender = lender();
    let user_info = pillars.get_user_info(borrowable.contract_address, Zeroable::zero(), lender);

    /// 4. Confirm lender has deposited USDC amount of shares
    assert(user_info.shares == USDC_DEPOSIT_AMOUNT, 'wrong_shares');
    assert(user_info.reward_debt.is_zero(), 'wrong_reward_debt');

    /// 5. Mine to half the epoch length
    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    start_prank(pillars.contract_address, lender);

    let pending = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), lender);
    pillars.collect_cyg(borrowable.contract_address, Zeroable::zero(), lender);

    let balance = cyg_token.balance_of(lender);
    assert(balance > 0 && balance == pending, 'wrong_balance');

    let pending = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), lender);
    assert(pending == 0, 'didnt_collect_all');

    stop_prank(pillars.contract_address);
    stop_warp(pillars.contract_address);
}

#[test]
fn borrower_collects_and_receives_cyg() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    /// 3. Borrower borrows
    let borrower = borrower();
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    let usd_bal = usdc.balance_of(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity, altair);
    assert(usdc.balance_of(borrower) == liquidity.into() + usd_bal, 'didnt_receive_usd');

    /// 6. Mine to half the epoch length
    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    start_prank(pillars.contract_address, borrower);

    let pending = pillars
        .pending_cyg(borrowable.contract_address, collateral.contract_address, borrower);
    pillars.collect_cyg(borrowable.contract_address, collateral.contract_address, borrower);

    let balance = cyg_token.balance_of(borrower);
    assert(balance > 0 && balance == pending, 'wrong_balance');

    let pending = pillars
        .pending_cyg(borrowable.contract_address, collateral.contract_address, borrower);
    assert(pending == 0, 'didnt_collect_all');

    stop_prank(pillars.contract_address);
    stop_warp(pillars.contract_address);
}

#[test]
fn lender_collects_all_cyg() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    let lender = lender();

    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    start_prank(pillars.contract_address, lender);

    let pending = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), lender);
    pillars.collect_cyg_all(lender);

    let balance = cyg_token.balance_of(lender);
    assert(balance > 0 && balance == pending, 'wrong_balance');

    let pending = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), lender);
    assert(pending == 0, 'didnt_collect_all');

    stop_prank(pillars.contract_address);
    stop_warp(pillars.contract_address);
}

#[test]
fn borrower_collects_all_cyg() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    /// 3. Borrower borrows
    let borrower = borrower();
    let (liquidity, _) = collateral.get_account_liquidity(borrower);
    let usd_bal = usdc.balance_of(borrower);
    borrow(borrowable, collateral, lp_token, borrower, liquidity, altair);
    assert(usdc.balance_of(borrower) == liquidity.into() + usd_bal, 'didnt_receive_usd');

    /// 6. Mine to half the epoch length
    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    start_prank(pillars.contract_address, borrower);

    let pending = pillars
        .pending_cyg(borrowable.contract_address, collateral.contract_address, borrower);
    pillars.collect_cyg_all(borrower);

    let balance = cyg_token.balance_of(borrower);
    assert(balance > 0 && balance == pending, 'wrong_balance');

    let pending = pillars
        .pending_cyg(borrowable.contract_address, collateral.contract_address, borrower);
    assert(pending == 0, 'didnt_collect_all');

    stop_prank(pillars.contract_address);
    stop_warp(pillars.contract_address);
}

/// Logic is the same for borrowers and lenders
/// Make sure that rewards are being given out in the correct %
#[test]
fn rewards_are_distributed_correctly_for_lenders() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    let lender = lender();
    let second_lender = second_lender();

    /// For lenders we just transfer CygUSD to another user as CygUSD accrues CYG automatically
    start_prank(borrowable.contract_address, lender);
    borrowable.transfer(second_lender, USDC_DEPOSIT_AMOUNT / 4);
    stop_prank(borrowable.contract_address);

    /// lender        = 7.5 CygUSD
    /// second_lender = 2.5 CygUSD
    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    let pending = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), lender);
    let pending_second = pillars
        .pending_cyg(borrowable.contract_address, Zeroable::zero(), second_lender);

    assert(pending == pending_second * 3, 'lender_receives_less');
    stop_warp(pillars.contract_address);
}

/// Logic is the same for borrowers and lenders
/// Make sure that rewards are being given out in the correct %
#[test]
fn rewards_are_distributed_correctly_for_lenders_after_update_shuttle() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    let lender = lender();
    let second_lender = second_lender();

    /// For lenders we just transfer CygUSD to another user as CygUSD accrues CYG automatically
    start_prank(borrowable.contract_address, lender);
    borrowable.transfer(second_lender, USDC_DEPOSIT_AMOUNT / 4);
    stop_prank(borrowable.contract_address);

    /// lender        = 7.5 CygUSD
    /// second_lender = 2.5 CygUSD
    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    pillars.accelerate_the_universe();
    let pending = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), lender);
    let pending_second = pillars
        .pending_cyg(borrowable.contract_address, Zeroable::zero(), second_lender);

    assert(pending == pending_second * 3, 'lender_receives_less');
    stop_warp(pillars.contract_address);
}

#[test]
fn reward_debt_is_being_accrued_correctly_with_multiple_claims() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    /// For lenders we just transfer CygUSD to another user as CygUSD accrues CYG automatically
    let lender = lender();
    let second_lender = second_lender();

    start_prank(borrowable.contract_address, lender);
    borrowable.transfer(second_lender, USDC_DEPOSIT_AMOUNT / 4);
    stop_prank(borrowable.contract_address);

    /// lender        = 7.5 CygUSD
    /// second_lender = 2.5 CygUSD
    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    pillars.accelerate_the_universe();
    /// Lender collects
    start_prank(pillars.contract_address, lender);
    pillars.collect_cyg_all(lender);
    stop_prank(pillars.contract_address);
    /// Second lender collects
    start_prank(pillars.contract_address, second_lender);
    pillars.collect_cyg_all(second_lender);
    stop_prank(pillars.contract_address);
    stop_warp(pillars.contract_address);

    let shuttle = pillars.get_shuttle_info(borrowable.contract_address, Zeroable::zero());
    let user = pillars.get_user_info(borrowable.contract_address, Zeroable::zero(), lender);
    let user_two = pillars
        .get_user_info(borrowable.contract_address, Zeroable::zero(), second_lender);

    let cyg_balance_lender = cyg_token.balance_of(lender);
    assert(cyg_balance_lender == user.reward_debt.try_into().unwrap(), 'wrong_reward_debt');

    let cyg_balance_second_lender = cyg_token.balance_of(second_lender);
    assert(
        cyg_balance_second_lender == user_two.reward_debt.try_into().unwrap(), 'wrong_reward_debt'
    );
}

#[test]
fn rewards_stop_accruing_after_redeem() {
    let (_, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars) =
        setup_with_pillars();

    /// Initialize shuttle rewards and set the rewarder in the borrowable contract
    initialize_pillars(pillars, borrowable, collateral, cyg_token);

    /// Deposit funds in shuttle
    deposit_funds_in_shuttle(borrowable, collateral, usdc, lp_token, altair);

    /// For lenders we just transfer CygUSD to another user as CygUSD accrues CYG automatically
    let lender = lender();

    // Accelerate and collect CYG
    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH() / 2);
    start_prank(pillars.contract_address, lender);
    pillars.accelerate_the_universe();
    pillars.collect_cyg_all(lender);
    stop_prank(pillars.contract_address);
    stop_warp(pillars.contract_address);

    /// Redeem
    start_prank(borrowable.contract_address, lender);
    let balance = borrowable.balance_of(lender);
    borrowable.redeem(balance, lender, lender);
    stop_prank(borrowable.contract_address);

    start_warp(pillars.contract_address, pillars.BLOCKS_PER_EPOCH());
    start_prank(pillars.contract_address, lender);
    pillars.accelerate_the_universe();
    let pending = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), lender);
    assert(pending == 0, 'can_still_claim');
    let user = pillars.get_user_info(borrowable.contract_address, Zeroable::zero(), lender);
    assert(user.reward_debt.mag == 0, 'reward debt not 0');
    stop_prank(pillars.contract_address);
    stop_warp(pillars.contract_address);

    let user = pillars.get_user_info(borrowable.contract_address, Zeroable::zero(), lender);
}


/// -------------------------------------------------------------------------------------------------
///                                       INTERNAL LOGIC
/// -------------------------------------------------------------------------------------------------

/// Initialize the pillars contract and add borrow and lend rewards with deployed shuttle
fn initialize_pillars(
    pillars: IPillarsOfCreationDispatcher,
    borrowable: IBorrowableDispatcher,
    collateral: ICollateralDispatcher,
    cyg_token: ICygnusDAODispatcher
) {
    let admin = admin();

    /// Points
    let p = 10000;

    /// Initialize shuttle rewards in rewarder for borrowers and lenders
    start_prank(pillars.contract_address, admin);
    pillars.initialize_pillars();
    pillars.set_borrow_rewards(borrowable.contract_address, collateral.contract_address, p);
    pillars.set_lending_rewards(borrowable.contract_address, p);
    stop_prank(pillars.contract_address);

    /// set pillars in borrowable
    start_prank(borrowable.contract_address, admin);
    borrowable.set_pillars_of_creation(pillars.contract_address);
    stop_prank(borrowable.contract_address);

    /// Set pillars in the CYG token
    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(pillars.contract_address);
    stop_prank(cyg_token.contract_address);
}

/// Deposit LP and USDC in lending pool
fn deposit_funds_in_shuttle(
    borrowable: IBorrowableDispatcher,
    collateral: ICollateralDispatcher,
    usdc: IERC20Dispatcher,
    lp_token: IERC20Dispatcher,
    altair: IAltairDispatcher
) {
    let borrower = borrower();

    deposit_lp_token(collateral, lp_token);
    deposit_stablecoin(borrowable, usdc);
    grant_usd_allowance_to_router(usdc, borrower, altair);
    grant_borrow_allowance(borrowable, borrower, altair);
}

/// Borrower borrows USDC
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
