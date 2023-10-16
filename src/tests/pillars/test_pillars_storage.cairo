// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash};

// Foundry
use snforge_std::{declare, start_prank, stop_prank, start_warp, stop_warp};

// Cygnus
use cygnus::tests::setup::{setup_with_pillars};
use cygnus::tests::users::{admin, borrower, lender};
use cygnus::token::erc20::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::token::erc20::cyg::{ICygnusDAODispatcher, ICygnusDAODispatcherTrait};
use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::rewarder::pillars::{IPillarsOfCreationDispatcher, IPillarsOfCreationDispatcherTrait};
use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};
use integer::BoundedInt;

/// ---------------------------------------------------------------------------------------------------
///                               PILLARS OF CREATION STORAGE TEST
/// ---------------------------------------------------------------------------------------------------

/// Total CYG = 2.25M
/// DAO = 20% = 500k
/// Rewards = 70% = 1.75M
///
/// Duration = 8 years
/// Total Epochs = 100

/// ---------------------------------------------------------------------------------------------------
/// Epoch | Total Rewards	| DAO CygPerBlock	| DAO CYG Rewards | Borrow CygPerBlock | Borrow CYG Rewards
/// ---------------------------------------------------------------------------------------------------
///   0	      51,880	          0.004570	          11,529	          0.0159942	          40,351
///   1	      50,843	          0.0044784	          11,298	          0.0156743	          39,544
///   2	      49,826	          0.0043888	          11,072	          0.0153608	          38,753
///   3	      48,829	          0.0043010	          10,851	          0.0150536	          37,978
///   4	      47,853	          0.0042150	          10,634	          0.0147525	          37,219
///   5	      46,896	          0.0041307	          10,421	          0.0144575	          36,474
///   6	      45,958	          0.0040481	          10,213	          0.0141683	          35,745
///   7	      45,039	          0.0039671	          10,009	          0.0138850	          35,030
///   8	      44,138	          0.0038878	           9,808	          0.0136073	          34,329
///   9	      43,255	          0.0038100	           9,612	          0.0133351	          33,643
///   10	    42,390	          0.0037338	           9,420	          0.0130684	          32,970
///   11	    41,542	          0.0036592	           9,232	          0.0128070	          32,311
///   12	    40,711	          0.0035860	           9,047	          0.0125509	          31,664
///   13	    39,897	          0.0035143	           8,866	          0.0122999	          31,031
///   14	    39,099	          0.0034440	           8,689	          0.0120539	          30,410
///   15	    38,317	          0.0033751	           8,515	          0.0118128	          29,802
///   16	    37,551	          0.0033076	           8,345	          0.0115765	          29,206
///   17	    36,800	          0.0032414	           8,178	          0.0113450	          28,622
///   18	    36,064	          0.0031766	           8,014	          0.0111181	          28,050
///   19	    35,343	          0.0031131	           7,854	          0.0108958	          27,489
///   20	    34,636	          0.0030508	           7,697	          0.0106778	          26,939
///   21	    33,943	          0.0029898	           7,543	          0.0104643	          26,400
///   22	    33,264	          0.0029300	           7,392	          0.0102550	          25,872
///   23	    32,599	          0.0028714	           7,244	          0.0100499	          25,355
///   24	    31,947	          0.0028140	           7,099	          0.0098489	          24,848
///   25	    31,308	          0.0027577	           6,957	          0.0096519	          24,351
///   26	    30,682	          0.0027025	           6,818	          0.0094589	          23,864
///   27	    30,068	          0.0026485	           6,682	          0.0092697	          23,386
///   28	    29,467	          0.0025955	           6,548	          0.0090843	          22,919
///   29	    28,877	          0.0025436	           6,417	          0.0089026	          22,460
///   30	    28,300	          0.0024927	           6,289	          0.0087246	          22,011
///   31	    27,734	          0.0024429	           6,163	          0.0085501	          21,571
///   32	    27,179	          0.0023940	           6,040	          0.0083791	          21,139
///   33	    26,636	          0.0023461	           5,919	          0.0082115	          20,717
///   34	    26,103	          0.0022992	           5,801	          0.0080473	          20,302
///   35	    25,581	          0.0022532	           5,685	          0.0078863	          19,896
///   36	    25,069	          0.0022082	           5,571	          0.0077286	          19,498
///   37	    24,568	          0.0021640	           5,460	          0.0075740	          19,108
///   38	    24,077	          0.0021207	           5,350	          0.0074225	          18,726
///   39	    23,595	          0.0020783	           5,243	          0.0072741	          18,352
///   40	    23,123	          0.0020367	           5,138	          0.0071286	          17,985
///   41	    22,661	          0.0019960	           5,036	          0.0069860	          17,625
///   42	    22,207	          0.0019561	           4,935	          0.0068463	          17,272
///   43	    21,763	          0.0019170	           4,836	          0.0067094	          16,927
///   44	    21,328	          0.0018786	           4,740	          0.0065752	          16,588
///   45	    20,901	          0.0018411	           4,645	          0.0064437	          16,257
///   46	    20,483	          0.0018042	           4,552	          0.0063148	          15,932
///   47	    20,074	          0.0017682	           4,461	          0.0061885	          15,613
///   48	    19,672	          0.0017328	           4,372	          0.0060648	          15,301
///   49	    19,279	          0.0016981	           4,284	          0.0059435	          14,995
///   50	    18,893	          0.0016642	           4,199	          0.0058246	          14,695
///   51	    18,515	          0.0016309	           4,115	          0.0057081	          14,401
///   52	    18,145	          0.0015983	           4,032	          0.0055939	          14,113
///   53	    17,782	          0.0015663	           3,952	          0.0054821	          13,831
///   54	    17,427	          0.0015350	           3,873	          0.0053724	          13,554
///   55	    17,078	          0.0015043	           3,795	          0.0052650	          13,283
///   56	    16,736	          0.0014742	           3,719	          0.0051597	          13,017
///   57	    16,402	          0.0014447	           3,645	          0.0050565	          12,757
///   58	    16,074	          0.0014158	           3,572	          0.0049553	          12,502
///   59	    15,752	          0.0013875	           3,500	          0.0048562	          12,252
///   60	    15,437	          0.0013597	           3,430	          0.0047591	          12,007
///   61	    15,128	          0.0013326	           3,362	          0.0046639	          11,767
///   62	    14,826	          0.0013059	           3,295	          0.0045707	          11,531
///   63	    14,529	          0.0012798	           3,229	          0.0044792	          11,301
///   64	    14,239	          0.0012542	           3,164	          0.0043897	          11,075
///   65	    13,954	          0.0012291	           3,101	          0.0043019	          10,853
///   66	    13,675	          0.0012045	           3,039	          0.0042158	          10,636
///   67	    13,401	          0.0011804	           2,978	          0.0041315	          10,423
///   68	    13,133	          0.0011568	           2,919	          0.0040489	          10,215
///   69	    12,871	          0.0011337	           2,860	          0.0039679	          10,011
///   70	    12,613	          0.0011110	           2,803	          0.0038885	           9,810
///   71	    12,361	          0.0010888	           2,747	          0.0038108	           9,614
///   72	    12,114	          0.0010670	           2,692	          0.0037346	           9,422
///   73	    11,872	          0.0010457	           2,638	          0.0036599	           9,233
///   74	    11,634	          0.0010248	           2,585	          0.0035867	           9,049
///   75	    11,401	          0.0010043	           2,534	          0.0035149	           8,868
///   76	    11,173	          0.0009842	           2,483	          0.0034446	           8,690
///   77	    10,950	          0.0009645	           2,433	          0.0033757	           8,517
///   78	    10,731	          0.0009452	           2,385	          0.0033082	           8,346
///   79	    10,516	          0.0009263	           2,337	          0.0032421	           8,179
///   80	    10,306	          0.0009078	           2,290	          0.0031772	           8,016
///   81	    10,100	          0.0008896	           2,244	          0.0031137	           7,855
///   82	     9,898	          0.0008718	           2,200	          0.0030514	           7,698
///   83	     9,700	          0.0008544	           2,156	          0.0029904	           7,544
///   84	     9,506	          0.0008373	           2,112	          0.0029306	           7,393
///   85	     9,316	          0.0008206	           2,070	          0.0028720	           7,246
///   86	     9,129	          0.0008041	           2,029	          0.0028145	           7,101
///   87	     8,947	          0.0007881	           1,988	          0.0027582	           6,959
///   88	     8,768	          0.0007723	           1,948	          0.0027031	           6,820
///   89	     8,593	          0.0007569	           1,909	          0.0026490	           6,683
///   90	     8,421	          0.0007417	           1,871	          0.0025960	           6,549
///   91	     8,252	          0.0007269	           1,834	          0.0025441	           6,418
///   92	     8,087	          0.0007123	           1,797	          0.0024932	           6,290
///   93	     7,926	          0.0006981	           1,761	          0.0024434	           6,164
///   94	     7,767	          0.0006841	           1,726	          0.0023945	           6,041
///   95	     7,612	          0.0006705	           1,691	          0.0023466	           5,920
///   96	     7,459	          0.0006570	           1,658	          0.0022997	           5,802
///   97	     7,310	          0.0006439	           1,625	          0.0022537	           5,686
///   98	     7,164	          0.0006310	           1,592	          0.0022086	           5,572
///   99	     7,021	          0.0006184	           1,560	          0.0021644	           5,461
/// ---------------------------------------------------------------------------------------------------
///        2,250,000 CYG                           500,000 CYG                         1,750,000 CYG
/// ---------------------------------------------------------------------------------------------------

const ONE: u256 = 1_000000000_000000000;

#[test]
fn pillars_deployed_correctly() {
    let (hangar18, _, _, _, _, _, cyg_token, pillars) = setup_with_pillars();
    assert(pillars.hangar18() == hangar18.contract_address, 'wrong factory');
    assert(pillars.total_cyg_rewards() == 1_750_000_000000000000000000, 'wrong_rewards');
    assert(pillars.total_cyg_dao() == 500_000_000000000000000000, 'wrong_dao_rewards');
    assert(pillars.TOTAL_EPOCHS() == 100, 'wrong_epochs');
    assert(pillars.birth() == 0, 'wrong_birth');
    assert(pillars.death() == 0, 'wrong_death');

    let one_year = 24 * 60 * 60 * 365;
    let duration = one_year * 8;
    assert(pillars.DURATION() == duration, 'wrong_duration');

    let blocks_per_epoch = duration / 100;
    assert(pillars.BLOCKS_PER_EPOCH() == blocks_per_epoch, 'wrong_blocks_per_epoch');
}

#[test]
fn cyg_token_is_rewards_token() {
    let (_, _, _, _, _, _, cyg_token, pillars) = setup_with_pillars();
    assert(cyg_token.contract_address == pillars.cyg_token(), 'wrong_rewards_token');
}

#[test]
#[should_panic(expected: ('only_admin',))]
fn only_hangar_admin_can_initialize() {
    let (_, _, _, _, _, _, _, pillars) = setup_with_pillars();

    /// Random
    let lender = lender();

    start_prank(pillars.contract_address, lender);
    pillars.initialize_pillars();
    stop_prank(pillars.contract_address);
}

#[test]
fn admin_can_initialize_pillars() {
    let (_, _, _, _, _, _, _, pillars) = setup_with_pillars();

    /// Random
    let admin = admin();

    assert(pillars.cyg_per_block_rewards() == 0, 'wrong');
    assert(pillars.cyg_per_block_dao() == 0, 'wrong');

    start_prank(pillars.contract_address, admin);
    pillars.initialize_pillars();
    stop_prank(pillars.contract_address);

    assert(pillars.cyg_per_block_rewards() > 0, 'wrong');
    assert(pillars.cyg_per_block_dao() > 0, 'wrong');
}

#[test]
#[should_panic(expected: ('already_initialized',))]
fn reverts_if_initializing_twice() {
    let (_, _, _, _, _, _, _, pillars) = setup_with_pillars();

    /// Random
    let admin = admin();

    start_prank(pillars.contract_address, admin);
    pillars.initialize_pillars();
    stop_prank(pillars.contract_address);

    start_prank(pillars.contract_address, admin);
    pillars.initialize_pillars();
    stop_prank(pillars.contract_address);
}

/// Calculated off chain/
/// init rewrads wtih 100 epochs 2% reduction 1750000 rewards = 40,351
#[test]
fn initial_epoch_gets_stored_correctly() {
    let (_, _, _, _, _, _, _, pillars) = setup_with_pillars();

    /// Random
    let admin = admin();

    assert(pillars.cyg_per_block_rewards() == 0, 'wrong');
    assert(pillars.cyg_per_block_dao() == 0, 'wrong');

    start_prank(pillars.contract_address, admin);
    pillars.initialize_pillars();
    stop_prank(pillars.contract_address);

    assert(pillars.get_current_epoch() == 0, 'wrong_epoch');

    ///  struct EpochInfo {
    ///      epoch: u8,
    ///      cyg_per_block: u128,
    ///      total_rewards: u128,
    ///      total_claimed: u128,
    ///      start: u64,
    ///      end: u64
    ///  }
    let epoch = pillars.get_epoch_info(0);

    /// Calculated off-chain, see tof
    assert(epoch.epoch == 0, 'wrong_epoch');
    assert(epoch.cyg_per_block == 15994174283244124, 'wrong_cyg_per_block');
    assert(epoch.total_rewards == 40351382415710935557120, 'wrong_rewards');
    assert(epoch.start == 0, 'wrong_start');
    assert(epoch.end == pillars.BLOCKS_PER_EPOCH(), 'wrong_end');
}

#[test]
fn initial_vars_are_correct_after_init() {
    let (_, _, _, _, _, _, cyg_token, pillars) = setup_with_pillars();

    /// Random
    let admin = admin();

    assert(pillars.cyg_per_block_rewards() == 0, 'wrong');
    assert(pillars.cyg_per_block_dao() == 0, 'wrong');

    start_prank(pillars.contract_address, admin);
    pillars.initialize_pillars();
    stop_prank(pillars.contract_address);

    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(pillars.contract_address);
    stop_prank(cyg_token.contract_address);

    assert(pillars.death() == pillars.until_supernova(), 'wrong death');

    assert(pillars.cyg_per_block_rewards() == 15994174283244124, 'wrong epoch cpb');
    assert(pillars.current_epoch_rewards() == 40351382415710935557120, 'wrong epoch rewards');

    assert(pillars.cyg_per_block_dao() == 4569764080926892, 'wrong epoch cpb dao');
    assert(
        pillars.current_epoch_rewards_dao() == 11528966404488837288960, 'wrong epoch dao rewards'
    );

    assert(pillars.death() == pillars.DURATION(), 'wrong_duration');
    assert(pillars.birth() == 0, 'wrong_birth');
    assert(pillars.TOTAL_EPOCHS() == 100, 'wrong total epochs');
}

#[test]
fn advances_epoch_correctly() {
    let (_, _, _, _, _, _, cyg_token, pillars) = setup_with_pillars();

    /// Random
    let admin = admin();

    start_prank(pillars.contract_address, admin);
    pillars.initialize_pillars();
    stop_prank(pillars.contract_address);

    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(pillars.contract_address);
    stop_prank(cyg_token.contract_address);

    let epoch_duration = pillars.BLOCKS_PER_EPOCH();

    start_warp(pillars.contract_address, epoch_duration);
    pillars.accelerate_the_universe();

    /// Should increase epoch
    assert(pillars.get_current_epoch() == 1, 'didnt increase');

    /// Should decrease by 2% each, see above, calc offchain
    assert(pillars.cyg_per_block_rewards() == 15674290797579241, 'didnt decrease');
    assert(pillars.current_epoch_rewards() == 39544354767396715534080, 'didnt decrease');
    assert(pillars.cyg_per_block_dao() == 4478368799308354, 'dao cpb didnt decrease');
    assert(pillars.current_epoch_rewards_dao() == 11298387076399060139520, 'dao rw didnt decrease');

    /// 34329464069343748588800 / 40351382415710935557120
    /// Calculated off-chain, see tof
    let epoch = pillars.get_epoch_info(0);
    assert(epoch.epoch == 0, 'wrong_epoch');
    assert(epoch.cyg_per_block == 15994174283244124, 'wrong_cyg_per_block');
    assert(epoch.total_rewards == 40351382415710935557120, 'wrong_rewards');
    assert(epoch.total_claimed == 0, 'wrong_claimed');
    assert(epoch.start == 0, 'wrong_start');
    assert(epoch.end == pillars.BLOCKS_PER_EPOCH(), 'wrong_end');

    /// Calculated off-chain, see tof
    let epoch = pillars.get_epoch_info(1);
    assert(epoch.epoch == 1, 'wrong_epoch');
    assert(epoch.cyg_per_block == 15674290797579241, 'wrong_cyg_per_block');
    assert(epoch.total_rewards == 39544354767396715534080, 'wrong_rewards');
    assert(epoch.total_claimed == 0, 'wrong_claimed');
    assert(epoch.start == pillars.BLOCKS_PER_EPOCH(), 'wrong_start');
    assert(epoch.end == pillars.BLOCKS_PER_EPOCH() * 2, 'wrong_end');

    stop_warp(pillars.contract_address);
}

#[test]
fn advances_8_epochs_correctly() {
    let (_, _, _, _, _, _, cyg_token, pillars) = setup_with_pillars();

    /// Random
    let admin = admin();

    start_prank(pillars.contract_address, admin);
    pillars.initialize_pillars();
    stop_prank(pillars.contract_address);

    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(pillars.contract_address);
    stop_prank(cyg_token.contract_address);

    let epoch_duration = pillars.BLOCKS_PER_EPOCH();

    start_warp(pillars.contract_address, epoch_duration * 8);
    pillars.accelerate_the_universe();

    /// Should increase epoch
    assert(pillars.get_current_epoch() == 8, 'didnt increase');

    /// Should decrease by (98%**8)% each, see above, calc offchain
    assert(pillars.cyg_per_block_rewards() == 13607252056912635, 'wrong_cpb_rewards');
    assert(pillars.current_epoch_rewards() == 34329464069343748588800, 'wrong_rewards');
    assert(pillars.cyg_per_block_dao() == 3887786301975038, 'wrong_cpb_dao');
    assert(pillars.current_epoch_rewards_dao() == 9808418305526783869440, 'wrong dao rw');

    assert(pillars.until_next_epoch() == pillars.BLOCKS_PER_EPOCH(), 'wrong time until');

    stop_warp(pillars.contract_address);
}

#[test]
fn advances_total_epochs_and_reaches_end() {
    let (_, _, _, _, _, _, cyg_token, pillars) = setup_with_pillars();

    /// Random
    let admin = admin();

    start_prank(pillars.contract_address, admin);
    pillars.initialize_pillars();
    stop_prank(pillars.contract_address);

    start_prank(cyg_token.contract_address, admin);
    cyg_token.set_pillars(pillars.contract_address);
    stop_prank(cyg_token.contract_address);

    let epoch_duration = pillars.BLOCKS_PER_EPOCH();

    start_warp(pillars.contract_address, epoch_duration * 99);
    pillars.accelerate_the_universe();

    /// Should increase epoch
    assert(pillars.get_current_epoch() == 99, 'didnt increase');
    // Round down see tof
    assert(pillars.current_epoch_rewards() / ONE == 5460, 'wrong_final_epoch');
    assert(pillars.current_epoch_rewards_dao() / ONE == 1560, 'wrong_final_epoch_dao');

    assert(pillars.until_next_epoch() == pillars.BLOCKS_PER_EPOCH(), 'wrong time until');
    assert(pillars.until_supernova() == pillars.BLOCKS_PER_EPOCH(), 'wrong supernova');

    stop_warp(pillars.contract_address);
}
