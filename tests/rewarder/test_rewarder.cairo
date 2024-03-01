// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash};
use integer::BoundedInt;

// Foundry
use snforge_std::{declare, start_prank, stop_prank, start_warp, stop_warp, CheatTarget};

// Cygnus
use tests::setup::{setup, setup_with_pillars};
use tests::users::{admin, borrower, lender};
use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::cyg::cygnusdao::{ICygnusDAODispatcher, ICygnusDAODispatcherTrait};
use cygnus::rewarder::pillars::{IPillarsOfCreationDispatcher, IPillarsOfCreationDispatcherTrait};
use snforge_std::PrintTrait;

use cygnus::data::calldata::{LeverageCalldata, Aggregator};


const ONE_YEAR: u64 = 31536000;

// Rewards per epoch (156 epochs)
// Epoch	Rewards
//   0	   53695.00345
//   1	   53158.05342
//   2	   52626.47288
//   3	   52100.20816
//   4	   51579.20607
//   5	   51063.41401
//   6	   50552.77987
//   7	   50047.25207
//   8	   49546.77955
//   9	   49051.31176
//   10	   48560.79864
//   11	   48075.19065
//   12	   47594.43875
//   13	   47118.49436
//   14	   46647.30942
//   15	   46180.83632
//   16	   45719.02796
//   17	   45261.83768
//   18	   44809.2193
//   19	   44361.12711
//   20	   43917.51584
//   21	   43478.34068
//   22	   43043.55727
//   23	   42613.1217
//   24	   42186.99048
//   25	   41765.12058
//   26	   41347.46937
//   27	   40933.99468
//   28	   40524.65473
//   29	   40119.40818
//   30	   39718.2141
//   31	   39321.03196
//   32	   38927.82164
//   33	   38538.54343
//   34	   38153.15799
//   35	   37771.62641
//   36	   37393.91015
//   37	   37019.97105
//   38	   36649.77134
//   39	   36283.27362
//   40	   35920.44089
//   41	   35561.23648
//   42	   35205.62411
//   43	   34853.56787
//   44	   34505.03219
//   45	   34159.98187
//   46	   33818.38205
//   47	   33480.19823
//   48	   33145.39625
//   49	   32813.94229
//   50	   32485.80286
//   51	   32160.94484
//   52	   31839.33539
//   53	   31520.94203
//   54	   31205.73261
//   55	   30893.67529
//   56	   30584.73853
//   57	   30278.89115
//   58	   29976.10224
//   59	   29676.34121
//   60	   29379.5778
//   61	   29085.78202
//   62	   28794.9242
//   63	   28506.97496
//   64	   28221.90521
//   65	   27939.68616
//   66	   27660.2893
//   67	   27383.68641
//   68	   27109.84954
//   69	   26838.75105
//   70	   26570.36354
//   71	   26304.6599
//   72	   26041.6133
//   73	   25781.19717
//   74	   25523.3852
//   75	   25268.15134
//   76	   25015.46983
//   77	   24765.31513
//   78	   24517.66198
//   79	   24272.48536
//   80	   24029.76051
//   81	   23789.4629
//   82	   23551.56827
//   83	   23316.05259
//   84	   23082.89207
//   85	   22852.06314
//   86	   22623.54251
//   87	   22397.30709
//   88	   22173.33402
//   89	   21951.60068
//   90	   21732.08467
//   91	   21514.76382
//   92	   21299.61619
//   93	   21086.62002
//   94	   20875.75382
//   95	   20666.99629
//   96	   20460.32632
//   97	   20255.72306
//   98	   20053.16583
//   99	   19852.63417
//   100   	19654.10783
//   101   	19457.56675
//   102   	19262.99108
//   103   	19070.36117
//   104   	18879.65756
//   105   	18690.86098
//   106   	18503.95237
//   107   	18318.91285
//   108   	18135.72372
//   109   	17954.36649
//   110   	17774.82282
//   111   	17597.07459
//   112   	17421.10385
//   113   	17246.89281
//   114   	17074.42388
//   115   	16903.67964
//   116   	16734.64284
//   117   	16567.29642
//   118   	16401.62345
//   119   	16237.60722
//   120   	16075.23115
//   121   	15914.47883
//   122   	15755.33405
//   123   	15597.7807
//   124   	15441.8029
//   125   	15287.38487
//   126   	15134.51102
//   127   	14983.16591
//   128   	14833.33425
//   129   	14685.00091
//   130   	14538.1509
//   131   	14392.76939
//   132   	14248.8417
//   133   	14106.35328
//   134   	13965.28975
//   135   	13825.63685
//   136   	13687.38048
//   137   	13550.50668
//   138   	13415.00161
//   139   	13280.85159
//   140   	13148.04308
//   141   	13016.56265
//   142   	12886.39702
//   143   	12757.53305
//   144   	12629.95772
//   145   	12503.65814
//   146   	12378.62156
//   147   	12254.83534
//   148   	12132.28699
//   149   	12010.96412
//   150   	11890.85448
//   151   	11771.94594
//   152   	11654.22648
//   153   	11537.68421
//   154   	11422.30737
//   155   	11308.0843

#[test]
#[fork("MAINNET")]
fn deploys_cyg_token_with_proper_cap() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router, cyg, pillars) = setup_with_pillars();
    assert(cyg.CAP() == 5_000000_000000000_000000000, 'wrong_cap');
}

#[test]
#[fork("MAINNET")]
fn initializes_pillars_correctly() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router, cyg, pillars) = setup_with_pillars();
    let cyg_per_block = pillars.cyg_per_block_rewards();
    assert(cyg_per_block == 0, 'wrong_cpb');

    let admin = admin();

    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.initialize_pillars();
    stop_prank(CheatTarget::One(pillars.contract_address));

    let cyg_per_block = pillars.cyg_per_block_rewards();
    let cyg_per_block_d = pillars.cyg_per_block_dao();
    let epoch_rewards = pillars.current_epoch_rewards();
    let epoch_rewards_d = pillars.current_epoch_rewards_dao();
    assert(cyg_per_block > 0, 'wrong_cpb');
    assert(cyg_per_block_d > 0, 'wrong_cpb');
    assert(epoch_rewards > 0, 'wrong_epoch_rewards');
    assert(epoch_rewards_d > 0, 'wrong_epoch_rewards_d');
}

#[test]
#[fork("MAINNET")]
fn set_pillars_in_borrowable() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router, cyg, pillars) = setup_with_pillars();
    let admin = admin();

    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.initialize_pillars();
    stop_prank(CheatTarget::One(pillars.contract_address));

    start_prank(CheatTarget::One(borrowable.contract_address), admin);
    borrowable.set_pillars_of_creation(pillars);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    assert(borrowable.pillars_of_creation() == pillars.contract_address, 'not_set');
}

#[test]
#[fork("MAINNET")]
fn initializes_rewards_for_shuttle_in_pillars() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router, cyg, pillars) = setup_with_pillars();

    let admin = admin();

    // Initailize pillars
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.initialize_pillars();
    stop_prank(CheatTarget::One(pillars.contract_address));

    /// Initialize in borrowable
    start_prank(CheatTarget::One(borrowable.contract_address), admin);
    borrowable.set_pillars_of_creation(pillars);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    // Initailize shuttle rewards
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.set_borrow_rewards(borrowable.contract_address, collateral.contract_address, 100);
    pillars.set_lending_rewards(borrowable.contract_address, 50);
    stop_prank(CheatTarget::One(pillars.contract_address));

    assert(pillars.total_alloc_point() == 150, 'wrong_total_alloc');

    let borrow_rewards = pillars.get_shuttle_info(borrowable.contract_address, collateral.contract_address);
    let lender_rewards = pillars.get_shuttle_info(borrowable.contract_address, Zeroable::zero());
    assert(borrow_rewards.alloc_point == 100, 'wrong alloc b');
    assert(lender_rewards.alloc_point == 50, 'wrong alloc l');
}

#[test]
#[fork("MAINNET")]
fn lend_rewards_are_tracked_correctly() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router, cyg, pillars) = setup_with_pillars();

    let admin = admin();

    // Initailize pillars
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.initialize_pillars();
    stop_prank(CheatTarget::One(pillars.contract_address));

    /// Initialize in borrowable
    start_prank(CheatTarget::One(borrowable.contract_address), admin);
    borrowable.set_pillars_of_creation(pillars);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    // Initailize shuttle rewards
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.set_borrow_rewards(borrowable.contract_address, collateral.contract_address, 100);
    pillars.set_lending_rewards(borrowable.contract_address, 50);
    stop_prank(CheatTarget::One(pillars.contract_address));

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(borrower, lp_token, collateral);
    deposit_usdc(lender, usdc, borrowable);

    let cyg_lp_balance = collateral.balance_of(borrower);
    let cyg_usd_balance = borrowable.balance_of(lender);

    assert(cyg_lp_balance > 0, 'wrong_cyglp_shares');
    assert(cyg_usd_balance > 0, 'wrong_cygusd_shares');

    let lender_info = pillars.get_user_info(borrowable.contract_address, Zeroable::zero(), lender);
    let shuttle_info = pillars.get_shuttle_info(borrowable.contract_address, Zeroable::zero());
    assert(lender_info.shares == cyg_usd_balance, 'wrong_pillars_lender');
    assert(shuttle_info.total_shares == cyg_usd_balance, 'wrong_shuttle_lender');
}

#[test]
#[fork("MAINNET")]
fn lend_rewards_are_accrued_correctly() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router, cyg, pillars) = setup_with_pillars();

    let admin = admin();

    /// Initialize pillars in cyg token
    start_prank(CheatTarget::One(cyg.contract_address), admin);
    cyg.set_pillars_of_creation(pillars.contract_address);
    stop_prank(CheatTarget::One(cyg.contract_address));

    // Initailize pillars
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.initialize_pillars();
    stop_prank(CheatTarget::One(pillars.contract_address));

    /// Initialize pillars in borrowable
    start_prank(CheatTarget::One(borrowable.contract_address), admin);
    borrowable.set_pillars_of_creation(pillars);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    // Initailize shuttle rewards
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.set_borrow_rewards(borrowable.contract_address, collateral.contract_address, 100);
    pillars.set_lending_rewards(borrowable.contract_address, 50);
    stop_prank(CheatTarget::One(pillars.contract_address));

    let borrower = borrower();
    let lender = lender();

    deposit_lp_token(borrower, lp_token, collateral);
    deposit_usdc(lender, usdc, borrowable);

    let cyg_lp_balance = collateral.balance_of(borrower);
    let cyg_usd_balance = borrowable.balance_of(lender);

    assert(cyg_lp_balance > 0, 'wrong_cyglp_shares');
    assert(cyg_usd_balance > 0, 'wrong_cygusd_shares');

    pillars.accelerate_the_universe();

    let timestamp = pillars.current_timestamp();
    let blocks_per_epoch = pillars.BLOCKS_PER_EPOCH();

    // advance 50% of the epoch
    start_warp(CheatTarget::One(pillars.contract_address), timestamp + blocks_per_epoch / 2);
    pillars.accelerate_the_universe();

    let pending_rewards = pillars.pending_cyg(borrowable.contract_address, Zeroable::zero(), lender);
    let pending_rewards_all = pillars.pending_cyg_all(lender);

    assert(pending_rewards > 0, 'wrong pending');
    assert(pending_rewards_all > 0, 'wrong pending');

    let progression = pillars.epoch_progression();
    let current_epoch_rewards = pillars.current_epoch_rewards();

    stop_warp(CheatTarget::One(pillars.contract_address));
}

#[test]
#[fork("MAINNET")]
fn borrow_rewards_are_accrued_correctly() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router, cyg, pillars) = setup_with_pillars();

    let admin = admin();

    /// Initialize pillars in cyg token
    start_prank(CheatTarget::One(cyg.contract_address), admin);
    cyg.set_pillars_of_creation(pillars.contract_address);
    stop_prank(CheatTarget::One(cyg.contract_address));

    // Initailize pillars
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.initialize_pillars();
    stop_prank(CheatTarget::One(pillars.contract_address));

    /// Initialize pillars in borrowable
    start_prank(CheatTarget::One(borrowable.contract_address), admin);
    borrowable.set_pillars_of_creation(pillars);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    // Initailize shuttle rewards
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.set_borrow_rewards(borrowable.contract_address, collateral.contract_address, 100);
    pillars.set_lending_rewards(borrowable.contract_address, 50);
    stop_prank(CheatTarget::One(pillars.contract_address));

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

    let blocks_epoch = pillars.BLOCKS_PER_EPOCH();
    let timestamp = hangar18.block_timestamp();

    // advance 99% of the epoch
    start_warp(CheatTarget::One(pillars.contract_address), timestamp + blocks_epoch);

    let pending_rewards = pillars.pending_cyg(borrowable.contract_address, collateral.contract_address, borrower);
    let pending_rewards_all = pillars.pending_cyg_all(borrower);

    assert(pending_rewards > 0, 'wrong pending');
    assert(pending_rewards_all > 0, 'wrong pending');

    start_prank(CheatTarget::One(pillars.contract_address), borrower);
    pillars.collect_cyg_all(borrower);
    stop_prank(CheatTarget::One(pillars.contract_address));
    stop_warp(CheatTarget::One(pillars.contract_address));

    let balance_borrower = cyg.balance_of(borrower);
    assert(balance_borrower > 0, 'wrong_cyg_bal');
}

#[test]
#[fork("MAINNET")]
fn advancing_updates_all_vars_correctly() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router, cyg, pillars) = setup_with_pillars();

    let admin = admin();

    /// Initialize pillars in cyg token
    start_prank(CheatTarget::One(cyg.contract_address), admin);
    cyg.set_pillars_of_creation(pillars.contract_address);
    stop_prank(CheatTarget::One(cyg.contract_address));

    // Initailize pillars
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.initialize_pillars();
    stop_prank(CheatTarget::One(pillars.contract_address));

    let cyg_per_block_epoch = pillars.calculate_cyg_per_block(0, 4_250_000_000000000000000000);
    let cyg_rewards_epoch = pillars.calculate_epoch_rewards(0, 4_250_000_000000000000000000);
    assert(cyg_rewards_epoch == 53695003452712558725959, 'wrong_epoch_0_rewards');

    let cyg_per_block_epoch = pillars.calculate_cyg_per_block(1, 4_250_000_000000000000000000);
    let cyg_rewards_epoch = pillars.calculate_epoch_rewards(1, 4_250_000_000000000000000000);
    assert(cyg_rewards_epoch == 53158053418185433538964, 'wrong_epoch_1_rewards');

    let cyg_per_block_epoch = pillars.calculate_cyg_per_block(5, 4_250_000_000000000000000000);
    let cyg_rewards_epoch = pillars.calculate_epoch_rewards(5, 4_250_000_000000000000000000);
    assert(cyg_rewards_epoch == 51063414012875788794426, 'wrong_epoch_5_rewards');
}

#[test]
#[fork("MAINNET")]
fn borrower_advances_epoch_and_collects_all() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router, cyg, pillars) = setup_with_pillars();

    let admin = admin();

    ///
    /// Initialize pillars in cyg token
    ///
    start_prank(CheatTarget::One(cyg.contract_address), admin);
    cyg.set_pillars_of_creation(pillars.contract_address);
    stop_prank(CheatTarget::One(cyg.contract_address));

    ///
    /// Initailize pillars
    ///
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.initialize_pillars();
    stop_prank(CheatTarget::One(pillars.contract_address));

    ///
    /// Initialize pillars in borrowable
    ///
    start_prank(CheatTarget::One(borrowable.contract_address), admin);
    borrowable.set_pillars_of_creation(pillars);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    ///
    /// Initailize shuttle rewards
    ///
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.set_borrow_rewards(borrowable.contract_address, collateral.contract_address, 100);
    pillars.set_lending_rewards(borrowable.contract_address, 50);
    stop_prank(CheatTarget::One(pillars.contract_address));

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

    ///
    /// EPOCH 0
    ///
    let blocks_epoch = pillars.BLOCKS_PER_EPOCH();
    let timestamp = hangar18.block_timestamp();

    // advance 99% of the epoch
    start_warp(CheatTarget::One(pillars.contract_address), timestamp + blocks_epoch);
    pillars.accelerate_the_universe();
    let epoch = pillars.get_current_epoch();
    assert(epoch == 1, 'wrong_first_epoch');

    let pending_rewards = pillars.pending_cyg(borrowable.contract_address, collateral.contract_address, borrower);
    let pending_rewards_all = pillars.pending_cyg_all(borrower);

    assert(pending_rewards > 0, 'wrong pending');
    assert(pending_rewards_all > 0, 'wrong pending');

    start_prank(CheatTarget::One(pillars.contract_address), borrower);
    pillars.collect_cyg_all(borrower);
    stop_prank(CheatTarget::One(pillars.contract_address));

    let balance_borrower = cyg.balance_of(borrower);
    assert(balance_borrower > 0, 'wrong_cyg_bal');
    stop_warp(CheatTarget::One(pillars.contract_address));

    ///
    /// EPOCH 1
    ///
    start_warp(CheatTarget::One(pillars.contract_address), timestamp + blocks_epoch * 2);

    pillars.accelerate_the_universe();
    let epoch = pillars.get_current_epoch();
    assert(epoch == 2, 'wrong_second_epoch');

    let pending_rewards = pillars.pending_cyg(borrowable.contract_address, collateral.contract_address, borrower);
    let pending_rewards_all = pillars.pending_cyg_all(borrower);

    assert(pending_rewards == pending_rewards_all, 'wrong pending');
    assert(pending_rewards_all > 0, 'wrong pending');

    start_prank(CheatTarget::One(pillars.contract_address), borrower);
    pillars.collect_cyg_all(borrower);
    stop_prank(CheatTarget::One(pillars.contract_address));

    stop_warp(CheatTarget::One(pillars.contract_address));

    let balance_borrower = cyg.balance_of(borrower);
    assert(balance_borrower > 0, 'wrong_cyg_bal');
    stop_warp(CheatTarget::One(pillars.contract_address));
}

// If lender works, we assume borrower works as the functions are identical, we just track different 
// balances
#[test]
#[fork("MAINNET")]
fn lender_rewards_are_correct_across_multiple_users() {
    let (hangar18, borrowable, collateral, lp_token, usdc, router, cyg, pillars) = setup_with_pillars();

    let admin = admin();

    /// Initialize pillars in cyg token
    start_prank(CheatTarget::One(cyg.contract_address), admin);
    cyg.set_pillars_of_creation(pillars.contract_address);
    stop_prank(CheatTarget::One(cyg.contract_address));

    // Initailize pillars
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.initialize_pillars();
    stop_prank(CheatTarget::One(pillars.contract_address));

    /// Initialize pillars in borrowable
    start_prank(CheatTarget::One(borrowable.contract_address), admin);
    borrowable.set_pillars_of_creation(pillars);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    // Initailize shuttle rewards
    start_prank(CheatTarget::One(pillars.contract_address), admin);
    pillars.set_borrow_rewards(borrowable.contract_address, collateral.contract_address, 100);
    pillars.set_lending_rewards(borrowable.contract_address, 50);
    stop_prank(CheatTarget::One(pillars.contract_address));

    let lender = lender();
    let lender_two: ContractAddress = 0x987.try_into().unwrap();
    let lender_three: ContractAddress = 0x654.try_into().unwrap();
    split_usdc_lenders(lender, usdc, lender_two, lender_three);

    deposit_usdc(lender, usdc, borrowable);
    deposit_usdc(lender_two, usdc, borrowable);
    deposit_usdc(lender_three, usdc, borrowable);

    let timestamp = pillars.current_timestamp();
    let blocks_per_epoch = pillars.BLOCKS_PER_EPOCH();

    // ------- Collect all 
    start_warp(CheatTarget::One(pillars.contract_address), timestamp + blocks_per_epoch / 2);

    let cyg_bal_0 = pillars.pending_cyg_all(lender);

    let cyg_bal_1 = pillars.pending_cyg_all(lender_two);
    let cyg_bal_2 = pillars.pending_cyg_all(lender_three);

    start_prank(CheatTarget::One(pillars.contract_address), lender_two);
    pillars.collect_cyg_all(lender_two);
    stop_prank(CheatTarget::One(pillars.contract_address));

    start_prank(CheatTarget::One(pillars.contract_address), lender);
    pillars.collect_cyg_all(lender);
    stop_prank(CheatTarget::One(pillars.contract_address));

    let bal = cyg.balance_of(lender);

    start_prank(CheatTarget::One(pillars.contract_address), lender_three);
    pillars.collect_cyg_all(lender_three);
    stop_prank(CheatTarget::One(pillars.contract_address));

    stop_warp(CheatTarget::One(pillars.contract_address));

    start_warp(CheatTarget::One(pillars.contract_address), timestamp + blocks_per_epoch);

    pillars.accelerate_the_universe();

    let cyg_bal_0_v = pillars.pending_cyg_all(lender);

    let cyg_bal_1_v = pillars.pending_cyg_all(lender_two);
    let cyg_bal_2_v = pillars.pending_cyg_all(lender_three);

    // ------- Collect all 
    start_prank(CheatTarget::One(pillars.contract_address), lender_two);
    pillars.collect_cyg_all(lender_two);
    stop_prank(CheatTarget::One(pillars.contract_address));

    start_prank(CheatTarget::One(pillars.contract_address), lender);
    pillars.collect_cyg_all(lender);
    stop_prank(CheatTarget::One(pillars.contract_address));

    start_prank(CheatTarget::One(pillars.contract_address), lender_three);
    pillars.collect_cyg_all(lender_three);
    stop_prank(CheatTarget::One(pillars.contract_address));

    stop_warp(CheatTarget::One(pillars.contract_address));

    assert(cyg.balance_of(lender) == cyg_bal_0 + cyg_bal_0_v, 'wrong lender #1 bal');
    assert(cyg.balance_of(lender_two) == cyg_bal_1 + cyg_bal_1_v, 'wrong lender #2 bal');
    assert(cyg.balance_of(lender_three) == cyg_bal_2 + cyg_bal_2_v, 'wrong lender #3 bal');
}

fn deposit_lp_token(borrower: ContractAddress, lp_token: IERC20Dispatcher, collateral: ICollateralDispatcher) {
    // Approve LP
    start_prank(CheatTarget::One(lp_token.contract_address), borrower);
    lp_token.approve(collateral.contract_address.into(), BoundedInt::max());
    stop_prank(CheatTarget::One(lp_token.contract_address));

    let deposit_amount = lp_token.balanceOf(borrower) / 10;
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

fn split_usdc_lenders(
    lender: ContractAddress, usdc: IERC20Dispatcher, lender_two: ContractAddress, lender_three: ContractAddress
) {
    let total_amount = usdc.balanceOf(lender);
    let lender_two_amount = total_amount / 3;
    let lender_three_amount = total_amount / 5;
    start_prank(CheatTarget::One(usdc.contract_address), lender);
    usdc.transfer(lender_two, lender_two_amount);
    usdc.transfer(lender_three, lender_three_amount);
    stop_prank(CheatTarget::One(usdc.contract_address));
}

