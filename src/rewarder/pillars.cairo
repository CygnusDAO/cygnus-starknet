use starknet::ContractAddress;
use cygnus::data::registry::{Nebula};
use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
use array::ArrayTrait;
use cygnus::data::pillars::{EpochInfo, UserInfo, ShuttleInfo};

//  The only contract capable of minting the CYG token. The CYG token is divided between the DAO and lenders
//  or borrowers of the Cygnus protocol.
//  It is similar to a masterchef contract but the rewards are based on epochs. Each epoch the rewards get
//  reduced by the `REDUCTION_FACTOR_PER_EPOCH` which is set at 2.5%. When deploying, the contract calculates
//  the initial rewards per block based on:
//    - the total amount of rewards
//    - the total number of epochs
//    - reduction factor.
//
//  cygPerBlockAtEpochN = (totalRewards - accumulatedRewards) * reductionFactor / emissionsCurve(epochN)
//
//           700k |
//                |                        Example with 1.75M totalRewards, 2.5% reduction and 42 epochs
//           600k |_______.
//                |       |                                Epochs    |    Rewards
//           500M |       |                             -------------|---------------
//                |       |_______.                       00 - 10    |   597,864.47
//  rewards  400k |       |       |                       11 - 20    |   461,139.90
//                |       |       |_______.               21 - 30    |   360,325.55
//           300k |       |       |       |_______.       31 - 42    |   327,670.07
//                |       |       |       |       |                  | 1,750,000.00
//           200k |       |       |       |       |
//                |       |       |       |       |
//           100k |       |       |       |       |
//                |       |       |       |       |
//                |_______|_______|_______|_______|__
//                  00-10   11-20   21-30   31-42
//                             epochs
//

/// Interface - Pillars Of Creation
#[starknet::interface]
trait IPillarsOfCreation<T> {
    ///--------------------------------------------------------------------------------------------------------
    ///                                        CONSTANT FUNCTIONS
    ///--------------------------------------------------------------------------------------------------------

    /// # Returns
    /// * The name of the contract `Pillars of Creation`
    fn name(self: @T) -> felt252;

    /// # Returns
    /// * The version of the rewarder deployed (to compare with other chains)
    fn version(self: @T) -> felt252;

    /// # Returns
    /// * The address of the hangar18 contract on Starknet
    fn hangar18(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of CYG on Starknet
    fn cyg_token(self: @T) -> ContractAddress;

    /// # Returns
    /// * The precision used for shares
    fn ACC_PRECISION(self: @T) -> u128;

    /// # Returns
    /// * The max possible cyg per block settable by admin, to control during initialization
    fn MAX_CYG_PER_BLOCK(self: @T) -> u128;

    /// # Returns
    /// * The duration of this contract in seconds until it dies and stops minting CYG
    fn DURATION(self: @T) -> u64;

    /// # Returns
    /// * The blocks per epoch assumed by this contract (duration / total_epochs)
    fn BLOCKS_PER_EPOCH(self: @T) -> u64;

    /// # Returns
    /// * The total CYG epochs, each epoch emissions get reduced by `REDUCTION_FACTOR_PER_EPOCH`
    fn TOTAL_EPOCHS(self: @T) -> u128;

    /// # Returns
    /// * The reduction factor per epoch
    fn REDUCTION_FACTOR_PER_EPOCH(self: @T) -> u128;

    /// Mapping to get the info for the epoch which shows cygperblock, CYG rewards, etc.
    ///
    /// # Arguments
    /// * `epoch` - The epoch number
    ///
    /// # Returns
    /// * The epoch info struct
    fn get_epoch_info(self: @T, epoch: u128) -> EpochInfo;

    /// Mapping to get the shuttle info which shows shuttle alloc points, shares, etc.
    /// borrowable -> collateral = Shuttle struct
    ///
    /// # Arguments
    /// * `borrowable` - The address of the borrowable (CygUSD)
    /// * `collateral` - The address of the collateral (CygLP)
    ///
    /// # Returns
    /// * The shuttle struct for this borrowable -> collateral shuttle
    fn get_shuttle_info(self: @T, borrowable: ContractAddress, collateral: ContractAddress) -> ShuttleInfo;

    /// Mapping to get the stored info for each user that is receiving CYG rewards.
    /// borrowable -> collateral -> user = UserInfo struct
    /// 
    /// # Arguments
    /// * `borrowable` - The address of the borrowable
    /// * `collateral` - The address of the collateral
    /// * `user` - The address of the user
    ///
    /// # Returns
    /// * The user info struct
    fn get_user_info(
        self: @T, borrowable: ContractAddress, collateral: ContractAddress, user: ContractAddress
    ) -> UserInfo;

    /// # Returns
    /// * The total CYG rewards for the DAO to be claimed by the end of `DURATION`
    fn total_cyg_dao(self: @T) -> u128;

    /// # Returns
    /// * The total CYG rewards for borrowers/lenders to be claimed by the end of `DURATION`
    fn total_cyg_rewards(self: @T) -> u128;

    /// # Returns
    /// * The unix timestamp when the rewarder starts minting CYG
    fn birth(self: @T) -> u64;

    /// # Returns
    /// * The unix timestamp when the rewarder stops minting CYG
    fn death(self: @T) -> u64;

    /// # Returns
    /// * The current cyg per block for the DAO rewards
    fn cyg_per_block_dao(self: @T) -> u128;

    /// # Returns
    /// * The current cyg per block for the borrowers/lenders
    fn cyg_per_block_rewards(self: @T) -> u128;

    /// # Returns
    /// * The current total alloc points, the sum of each shuttle alloc's points 
    fn total_alloc_point(self: @T) -> u128;

    /// # Returns
    /// * The timestamp of the last time we advanced epoch
    fn last_epoch_time(self: @T) -> u64;

    /// # Returns
    /// * The timestamp of the last DAO drip
    fn last_drip_dao(self: @T) -> u64;

    /// # Returns
    /// * The total length of the shuttles initialized
    fn all_shuttles_length(self: @T) -> u32;

    /// # Returns
    /// * The current epoch
    fn get_current_epoch(self: @T) -> u128;

    /// The emissions curve that uses TOTAL_EPOCHS and REDUCTION_FACTOR
    ///
    /// # Arguements
    /// * `epoch` - The epoch number
    ///
    /// # Returns
    /// * The emissions curve for the `epoch`
    fn emissions_curve(self: @T, epoch: u128) -> u128;

    /// Calculates the rewards at `epoch` given `total_rewards`
    ///
    /// # Arguments
    /// * `epoch` - The number of the epoch
    /// * `total_rewards` - The total CYG rewards that should be minted by the end of the 100th epoch
    fn calculate_epoch_rewards(self: @T, epoch: u128, total_rewards: u128) -> u128;

    /// Returns the rewards for lenders and borrowers given a certain `shuttle_id` 
    /// Queries the factory for shuttle ID and returns 2 structs
    ///
    /// # Returns
    /// * The rewards struct for lenders in this shuttle
    /// * The rewards struct for borrowers in this shuttle
    fn get_shuttle_by_id(self: @T, shuttle_id: u32) -> (ShuttleInfo, ShuttleInfo);

    /// cyg_per_block_at_epoch_n = (total - accumulated) * reduction_factor / emissions_curve
    ///
    /// Calculates the CYG per block at a given `epoch` given a total amount of CYG rewards.
    ///
    /// # Arguments
    /// * `epoch` - The epoch number (must be less than TOTAL_EPOCHS)
    /// * `total_rewards` - The total CYG rewards minted by the end of TOTAL_EPOCHS
    ///
    /// # Returns
    /// * The CYG minted per block needed at `epoch` to reach `total_rewards` by the end of TOTAL_EPOCHS
    fn calculate_cyg_per_block(self: @T, epoch: u128, total_rewards: u128) -> u128;

    /// # Retunrs
    /// * The total CYG claimed by borrowers/lenders
    fn total_cyg_claimed(self: @T) -> u128;

    /// # Returns
    /// * The pending cyg to be claimed by the DAO
    fn pending_cyg_dao(self: @T) -> u128;

    /// # Arguments
    /// * `borrowable` - The address of a borrowable contract (CygUSD)
    /// * `collateral` - The address of a collateral contract (CygLP) - This is zero for lenders
    /// * `astronaut` - The address of the borrower or lender
    fn pending_cyg(
        self: @T, borrowable: ContractAddress, collateral: ContractAddress, astronaut: ContractAddress
    ) -> u128;

    /// # Arguments
    /// * `astronaut` - The address of the borrower or lender
    fn pending_cyg_all(self: @T, astronaut: ContractAddress) -> u128;

    /// ------------- Used for quick reporting purposes, not used by the pillars itself -------------

    /// # Returns
    /// * `get_block_timestamp`
    fn current_timestamp(self: @T) -> u64;

    /// # Returns
    /// * The current epoch rewards pacing in percentage. Ie. If are 50% inside the current epoch and 
    ///   users have claimed 50% of the rewards for this epoch, we are at 100% pacing (1e18)
    fn epoch_rewards_pacing(self: @T) -> u128;

    /// # Returns
    /// * The total CYG rewards in this epoch for borrowers/lenders
    fn current_epoch_rewards(self: @T) -> u128;

    /// # Returns
    /// * The total CYG rewards in this epoch for the DAO
    fn current_epoch_rewards_dao(self: @T) -> u128;

    /// # Returns
    /// * The total CYG rewards in the last epoch for borrowers and lenders
    fn previous_epoch_rewards(self: @T) -> u128;

    /// # Returns
    /// * The total CYG rewards in the next epoch for borrowers and lenders
    fn next_epoch_rewards(self: @T) -> u128;

    /// # Returns
    /// * How many blocks have passed in this epoch
    fn blocks_this_epoch(self: @T) -> u64;

    /// # Returns
    /// * How many blocks until we reach the next epoch
    fn until_next_epoch(self: @T) -> u64;

    /// # Returns
    /// * How far along we are in this epoch in %, ie blocks_this_epoch / blocks_per_epoch
    fn epoch_progression(self: @T) -> u128;

    /// # Returns
    /// * How many blocks left until the Pillars of Creation dies and stops minting CYG
    fn until_supernova(self: @T) -> u64;

    /// # Returns
    /// * How far along we are until supernova in %, ie blocks_since_birth / total_duration
    fn total_progression(self: @T) -> u128;

    /// # Returns
    /// * Whether we are doomed or not
    fn doom_switch(self: @T) -> bool;

    /// # Returns
    /// * The (year, month, day) given unix timestamp
    fn timestamp_to_date(self: @T, timestamp: u64) -> (u64, u64, u64);

    /// # Returns
    /// * The timestamp given (year, month, day)
    fn date_to_timestamp(self: @T, year: u64, month: u64, day: u64) -> u64;

    /// # Returns
    /// * The number of days passed this epoch
    fn days_passed_this_epoch(self: @T) -> u64;

    /// # Returns
    /// * The number of days until the next epoch starts
    fn days_until_next_epoch(self: @T) -> u64;

    /// # Returns
    /// * The number of days until we die
    fn days_until_supernova(self: @T) -> u64;

    /// # Returns
    /// * The year, month, day of birth
    fn star_formation_date(self: @T) -> (u64, u64, u64);

    /// # Returns
    /// * The year, month, day of death
    fn supernova_date(self: @T) -> (u64, u64, u64);

    ///--------------------------------------------------------------------------------------------------------
    ///                                      NON-CONSTANT FUNCTIONS
    ///--------------------------------------------------------------------------------------------------------

    /// Try self-destruct contract
    fn supernova(ref self: T);

    /// Adjusts an already initialized shuttle alloc points
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `borrowable` - The address of a borrowable contract (CygUSD)
    /// * `collateral` - The address of a collateral contract (CygLP) - This is zero for lenders
    /// * `alloc_point` - The new shuttle alloc points
    fn adjust_shuttle_rewards(ref self: T, borrowable: ContractAddress, collateral: ContractAddress, alloc_point: u128);

    /// Updates a shuttle rewards var with the latest timestamp
    ///
    /// # Arguments
    /// * `borrowable` - The address of a borrowable contract (CygUSD)
    /// * `collateral` - The address of a collateral contract (CygLP) - This is zero for lenders
    fn update_shuttle(ref self: T, borrowable: ContractAddress, collateral: ContractAddress);

    /// Tries to advance an epoch. If successful it updates:
    /// `cyg_per_block_rewards` - CygPerBlock for borrowers/lenders
    /// `cyg_per_block_dao` - CygPerBlock for the DAO
    /// `last_epoch_time` - The current timestamp
    /// `epoch_info` - Creates a new Epoch struct in the internal mapping, gettable via `get_epoch_info`
    ///
    /// Whether we advance or not all shuttles get updated.
    fn accelerate_the_universe(ref self: T);

    /// Initializes lending rewards for a shuttle 
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `borrowable` - The address of a borrowable contract (CygUSD)
    /// * `alloc_point` - The new shuttle alloc points
    fn set_lending_rewards(ref self: T, borrowable: ContractAddress, alloc_point: u128);

    /// Initializes borrow rewards for a shuttle 
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `borrowable` - The address of a borrowable contract (CygUSD)
    /// * `collateral` - The address of a collateral contract (CygLP) - This is zero for lenders
    /// * `alloc_point` - The new shuttle alloc points
    fn set_borrow_rewards(ref self: T, borrowable: ContractAddress, collateral: ContractAddress, alloc_point: u128);

    /// Tracks rewards for lenders and borrowers. Caller is always borrowable
    ///
    /// # Arguments
    /// * `account` - The address of the borrower/lender
    /// * `balance` - The borrow balance for borrowers, the deposited USD balance for lenders
    /// * `collateral` - The address of the collateral (zero address for lenders)
    fn track_rewards(ref self: T, account: ContractAddress, balance: u128, collateral: ContractAddress);

    /// Drip CYG to the hangar18's latest `dao_reserves` contract
    fn drip_cyg_dao(ref self: T);

    /// The caller collects their earned CYG across all shuttles and mints it to `to`
    ///
    /// # Arguments
    /// * `to` - The address of the receiver of the CYG
    ///
    /// # Returns
    /// * The collected CYG amount
    fn collect_cyg_all(ref self: T, to: ContractAddress) -> u128;

    /// The caller collects their earned CYG in this (borrowable, collateral) shuttle and 
    /// mints it to `to`.
    ///
    /// # Arguments
    /// * `borrowable` - The address of a borrowable contract (CygUSD)
    /// * `collateral` - The address of a collateral contract (CygLP) - This is zero for lenders
    /// * `to` - The address of the receiver of the CYG
    ///
    /// # Returns
    /// * The collected CYG amount
    fn collect_cyg(ref self: T, borrowable: ContractAddress, collateral: ContractAddress, to: ContractAddress) -> u128;

    /// Initializes the pillars of creation contract and starts minting CYG. It stores the new epoch
    /// and stores the birth and death of the contract
    ///
    /// # Security
    /// * Only-factory-admin
    fn initialize_pillars(ref self: T);

    /// Turns on the doom switch. Cannot be turned off
    ///
    /// # Security
    /// * Only-factory-admin
    fn set_doom_switch(ref self: T);
}

#[starknet::contract]
mod PillarsOfCreation {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::IPillarsOfCreation;
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::token::cyg::{ICygnusDAODispatcher, ICygnusDAODispatcherTrait};
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};

    /// # Libraries
    use cygnus::libraries::full_math_lib::FullMathLib::FixedPointMathLibTrait;
    use starknet::{get_contract_address, ContractAddress, get_caller_address, get_block_timestamp};

    /// # Data
    use cygnus::data::pillars::{EpochInfo, UserInfo, ShuttleInfo};
    use cygnus::data::signed_integer::{i128::{i128, u128Intoi128}, integer_trait::{IntegerTrait}};

    use cygnus::libraries::date_time_lib::{timestamp_to_date, date_to_timestamp, diff_days};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewEpoch: NewEpoch,
        DAODrip: DAODrip,
        AccelerateTheUniverse: AccelerateTheUniverse,
        Collect: Collect,
        CollectAll: CollectAll,
        UpdateShuttle: UpdateShuttle,
        TrackRewards: TrackRewards,
        Supernova: Supernova,
        NewBorrowRewards: NewBorrowRewards,
        NewLendRewards: NewLendRewards,
        DoomSwitch: DoomSwitch
    }

    #[derive(Drop, starknet::Event)]
    struct DoomSwitch {
        timestamp: u64,
        caller: ContractAddress
    }


    #[derive(Drop, starknet::Event)]
    struct Supernova {
        timestamp: u64
    }

    /// NewEpoch
    #[derive(Drop, starknet::Event)]
    struct NewEpoch {
        old_epoch: u128,
        new_epoch: u128,
        old_cyg_per_block: u128,
        new_cyg_per_block: u128
    }

    /// DAODrip
    #[derive(Drop, starknet::Event)]
    struct DAODrip {
        dao_reserves: ContractAddress,
        amount: u128
    }

    /// AccelerateTheUniverse
    #[derive(Drop, starknet::Event)]
    struct AccelerateTheUniverse {
        shuttles_length: u32
    }

    /// UpdateShuttle
    #[derive(Drop, starknet::Event)]
    struct UpdateShuttle {
        borrowable: ContractAddress,
        collateral: ContractAddress,
        caller: ContractAddress,
        current_epoch: u128,
        timestamp: u64
    }

    /// Collect
    #[derive(Drop, starknet::Event)]
    struct Collect {
        borrowable: ContractAddress,
        collateral: ContractAddress,
        caller: ContractAddress,
        to: ContractAddress,
        amount: u128
    }

    /// CollectAll
    #[derive(Drop, starknet::Event)]
    struct CollectAll {
        shuttles_length: u32,
        caller: ContractAddress,
        amount: u128
    }

    #[derive(Drop, starknet::Event)]
    struct TrackRewards {
        borrowable: ContractAddress,
        account: ContractAddress,
        balance: u128,
        collateral: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct NewLendRewards {
        shuttle_id: u32,
        borrowable: ContractAddress,
        collateral: ContractAddress,
        total_alloc_point: u128,
        alloc_point: u128
    }

    #[derive(Drop, starknet::Event)]
    struct NewBorrowRewards {
        shuttle_id: u32,
        borrowable: ContractAddress,
        collateral: ContractAddress,
        total_alloc_point: u128,
        alloc_point: u128
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Address of the factory for admin only functions
        hangar18: IHangar18Dispatcher,
        /// Address of the CYG token
        cyg_token: ICygnusDAODispatcher,
        /// Array of all initialized shuttles (this is not the same as factory shuttles)
        /// Helpful to loop through all shuttles
        all_shuttles_length: u32,
        /// 'array' of shuttle structs
        all_shuttles: LegacyMap<u32, ShuttleInfo>,
        /// Mapping to get an epoch info
        epoch_info: LegacyMap<u128, EpochInfo>,
        /// Mapping of ((borrowable -> collateral) -> user address) = User Info. Lenders collateral is always 0
        user_info: LegacyMap<(ContractAddress, ContractAddress, ContractAddress), UserInfo>,
        /// Mapping to get a shuttle info (borrowable -> collateral = Shuttle)
        shuttle_info: LegacyMap<(ContractAddress, ContractAddress), ShuttleInfo>,
        /// Total CYG rewards for lenders and borrowers
        total_cyg_rewards: u128,
        /// Total CYG rewards for the DAO
        total_cyg_dao: u128,
        /// Unix Timestamp when the rewarder starts minting rewards
        birth: u64,
        /// Unix Timestamp when the rewarder stops minting rewards
        death: u64,
        /// The current epoch's per block mint rate for lenders/borrowers
        cyg_per_block_rewards: u128,
        /// The current epoch's per block mint rate for the dao
        cyg_per_block_dao: u128,
        /// The total alloc point for all shuttles
        total_alloc_point: u128,
        /// The timestamp of the last DAO drip
        last_drip_dao: u64,
        /// The timestamp of when we advanced an epoch}
        last_epoch_time: u64,
        /// Doomswitch
        doom_switch: bool
    }

    /// Scale
    const ONE: u128 = 1_000000000_000000000;

    /// The accounting precision
    const ACC_PRECISION: u128 = 1_000000000_000000000; // 1e18
    /// Maximum cyg per block possible
    const MAX_CYG_PER_BLOCK: u128 = 470000000_000000000; // 0.47e18
    /// The percentage that rewards get reduced by each epoch
    const REDUCTION_FACTOR_PER_EPOCH: u128 = 10000000_000000000; // 1%, 0.01e18

    const SECONDS_PER_YEAR: u64 = 31_536_000;
    const DURATION: u64 = 189_216_000; // SECONDS_PER_YEAR * 6 years
    const TOTAL_EPOCHS: u128 = 156;
    const BLOCKS_PER_EPOCH: u64 = 1_212_923; // Duration / TOTAL EPOCHS

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, hangar18: IHangar18Dispatcher, cyg_token: ICygnusDAODispatcher) {
        self.hangar18.write(hangar18);
        self.cyg_token.write(cyg_token);
        self.total_cyg_rewards.write(4_250_000_000000000000000000);
        self.total_cyg_dao.write(500_000_000000000000000000);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl PillarsOfCreationImpl of IPillarsOfCreation<ContractState> {
        /// # Implementation
        /// * IPillarsOfCreation
        fn name(self: @ContractState) -> felt252 {
            'Pillars Of Creation'
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn version(self: @ContractState) -> felt252 {
            '1.0.0'
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn cyg_token(self: @ContractState) -> ContractAddress {
            self.cyg_token.read().contract_address
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn current_timestamp(self: @ContractState) -> u64 {
            get_block_timestamp()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn ACC_PRECISION(self: @ContractState) -> u128 {
            ACC_PRECISION
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn MAX_CYG_PER_BLOCK(self: @ContractState) -> u128 {
            MAX_CYG_PER_BLOCK
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn BLOCKS_PER_EPOCH(self: @ContractState) -> u64 {
            BLOCKS_PER_EPOCH
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn TOTAL_EPOCHS(self: @ContractState) -> u128 {
            TOTAL_EPOCHS
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn DURATION(self: @ContractState) -> u64 {
            DURATION
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn REDUCTION_FACTOR_PER_EPOCH(self: @ContractState) -> u128 {
            REDUCTION_FACTOR_PER_EPOCH
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn get_epoch_info(self: @ContractState, epoch: u128) -> EpochInfo {
            self.epoch_info.read(epoch)
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn get_shuttle_info(
            self: @ContractState, borrowable: ContractAddress, collateral: ContractAddress
        ) -> ShuttleInfo {
            self.shuttle_info.read((borrowable, collateral))
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn get_user_info(
            self: @ContractState, borrowable: ContractAddress, collateral: ContractAddress, user: ContractAddress
        ) -> UserInfo {
            self.user_info.read((borrowable, collateral, user))
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn total_cyg_rewards(self: @ContractState) -> u128 {
            self.total_cyg_rewards.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn total_cyg_dao(self: @ContractState) -> u128 {
            self.total_cyg_dao.read()
        }

        /// current settings

        /// # Implementation
        /// * IPillarsOfCreation
        fn birth(self: @ContractState) -> u64 {
            self.birth.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn death(self: @ContractState) -> u64 {
            self.death.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn calculate_epoch_rewards(self: @ContractState, epoch: u128, total_rewards: u128) -> u128 {
            /// Calculates the rewards at `epoch` given `total_rewards`
            let cyg_per_block = self.calculate_cyg_per_block(epoch, total_rewards);
            cyg_per_block * BLOCKS_PER_EPOCH.into()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn cyg_per_block_rewards(self: @ContractState) -> u128 {
            self.cyg_per_block_rewards.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn cyg_per_block_dao(self: @ContractState) -> u128 {
            self.cyg_per_block_dao.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn total_alloc_point(self: @ContractState) -> u128 {
            self.total_alloc_point.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn last_drip_dao(self: @ContractState) -> u64 {
            self.last_drip_dao.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn last_epoch_time(self: @ContractState) -> u64 {
            self.last_epoch_time.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn all_shuttles_length(self: @ContractState) -> u32 {
            self.all_shuttles_length.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn get_current_epoch(self: @ContractState) -> u128 {
            // Get the current timestamp
            let timestamp = get_block_timestamp();

            /// Contract has expired
            if timestamp >= self.death.read() {
                return TOTAL_EPOCHS;
            }

            ((timestamp - self.birth.read()) / BLOCKS_PER_EPOCH).into()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn emissions_curve(self: @ContractState, epoch: u128) -> u128 {
            /// Create the emissions curve based on the reduction factor and epoch
            let one_minus_reduction_factor = ONE - REDUCTION_FACTOR_PER_EPOCH;
            let total_epochs = TOTAL_EPOCHS - epoch;
            let mut result: u128 = ONE;

            let mut len = 0;
            loop {
                if len == total_epochs {
                    break;
                }

                result = result.mul_wad(one_minus_reduction_factor);

                len += 1;
            };

            ONE - result
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn calculate_cyg_per_block(self: @ContractState, epoch: u128, total_rewards: u128) -> u128 {
            let emissions = self.emissions_curve(0);
            let mut rewards = total_rewards.full_mul_div(REDUCTION_FACTOR_PER_EPOCH, emissions);

            /// Reduce each epoch rewards by `REDUCTION_FACTOR_PER_EPOCH`
            let mut len = 0;
            loop {
                if len >= epoch {
                    break;
                }

                rewards = rewards.mul_wad(ONE - REDUCTION_FACTOR_PER_EPOCH);
                len += 1;
            };

            /// Return the cyg_per_block at `epoch` given `total_rewards`
            rewards / BLOCKS_PER_EPOCH.into()
        }

        /// Uses the shuttle_id from the factory - This is not the same as pillars_id
        ///
        /// # Implementation
        /// * IPillarsOfCreation
        fn get_shuttle_by_id(self: @ContractState, shuttle_id: u32) -> (ShuttleInfo, ShuttleInfo) {
            /// Get shuttle from the factory with `shuttle_id`
            let shuttle = self.hangar18.read().all_shuttles(shuttle_id);

            /// Borrowable and collateral for this `shuttle_id`
            let borrowable = shuttle.borrowable.contract_address;
            let collateral = shuttle.collateral.contract_address;

            /// Lender rewards always use address zero as collateral, borrower rewards use the actual collateral
            let lender_rewards = self.shuttle_info.read((borrowable, Zeroable::zero()));
            let borrow_rewards = self.shuttle_info.read((borrowable, collateral));

            (lender_rewards, borrow_rewards)
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn pending_cyg_dao(self: @ContractState) -> u128 {
            /// Calculate rewards for DAO since last dao drip
            let timestamp = get_block_timestamp();
            let last_drip_dao = self.last_drip_dao.read();
            let cyg_per_block_dao = self.cyg_per_block_dao.read();

            (timestamp.into() - last_drip_dao.into()) * cyg_per_block_dao
        }

        /// View function to see user's pending CYG for a shuttle
        ///
        /// # Implementation
        /// * IPillarsOfCreation
        fn pending_cyg(
            self: @ContractState, borrowable: ContractAddress, collateral: ContractAddress, astronaut: ContractAddress
        ) -> u128 {
            /// Get the shuttle and user info given `borrowable` and `collateral`
            let shuttle: ShuttleInfo = self.shuttle_info.read((borrowable, collateral));
            let user: UserInfo = self.user_info.read((borrowable, collateral, astronaut));

            /// Get this shuttle's total shares and rewards_per_share stored
            let total_shares = shuttle.total_shares;
            let mut acc_reward_per_share = shuttle.acc_reward_per_share;

            let timestamp = get_block_timestamp();

            /// Calculate the latest reward per share if we need
            if (timestamp > shuttle.last_reward_time && total_shares != 0) {
                /// Calculate:
                /// time_elapsed * cyg_per_block * pool_alloc
                let time_elapsed = timestamp - shuttle.last_reward_time;
                let cyg_per_block = self.cyg_per_block_rewards.read();
                let total_alloc_point = self.total_alloc_point.read();
                let shuttle_alloc = shuttle.alloc_point;

                let shuttle_rewards = (time_elapsed.into() * cyg_per_block * shuttle_alloc) / total_alloc_point;

                /// Calculate the new reward_per_share
                acc_reward_per_share += shuttle_rewards.full_mul_div(ACC_PRECISION, total_shares);
            }

            /// Calculate user shares given the latest reward per share and reward debt
            let reward = user.shares.full_mul_div(acc_reward_per_share, ACC_PRECISION);

            /// The pending CYG reward for the user in this pool
            (reward.into() - user.reward_debt).try_into().unwrap()
        }

        /// View function to see user's total pending CYG across all shuttles
        ///
        /// # Implementation
        /// * IPillarsOfCreation
        fn pending_cyg_all(self: @ContractState, astronaut: ContractAddress) -> u128 {
            /// Get total shuttles length to loop 
            let shuttles_length = self.all_shuttles_length.read();

            let mut amount = 0;
            let mut shuttle_id = 0;

            /// Loop through each shuttle and check for pending CYG and collect
            /// We only pass `to` as `collect_interal` uses `get_caller_address()`
            loop {
                /// Escape 
                if shuttle_id == shuttles_length {
                    break;
                }
                let shuttle = self.all_shuttles.read(shuttle_id);
                amount += self.pending_cyg(shuttle.borrowable, shuttle.collateral, astronaut);
                shuttle_id += 1;
            };

            amount
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn total_cyg_claimed(self: @ContractState) -> u128 {
            /// Get current epoch and loop through each stored epoch and accumulate
            /// the total cyg claimed / in each epoch
            let current_epoch = self.get_current_epoch();
            let mut claimed = 0;
            let mut i = 0;

            loop {
                claimed += self.epoch_info.read(i).total_claimed;
                if i == current_epoch {
                    break;
                }
                i += 1;
            };

            claimed
        }

        /// Returns the percentage (in 18 decimals) to quickly see if rewards are being paid
        /// in correct time (should always be close to 1e18 ie 100%)
        ///
        /// # Implementation
        /// * IPillarsOfCreation
        fn epoch_rewards_pacing(self: @ContractState) -> u128 {
            /// Calculate how far into this epoch we are in %
            let blocks_this_epoch = self.blocks_this_epoch();
            let epoch_progress = blocks_this_epoch.into().div_wad(BLOCKS_PER_EPOCH.into());

            /// Get total rewards for this epoch and the total claimed
            let current_epoch = self.get_current_epoch();
            let rewards = self.epoch_info.read(current_epoch).total_rewards;
            let claimed = self.epoch_info.read(current_epoch).total_claimed;

            /// The rewards pacing is:
            /// Claimed / (rewards * epoch_progress)
            claimed.div_wad(rewards.mul_wad(epoch_progress))
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn current_epoch_rewards(self: @ContractState) -> u128 {
            let current_epoch = self.get_current_epoch();
            self.calculate_epoch_rewards(current_epoch, self.total_cyg_rewards.read())
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn current_epoch_rewards_dao(self: @ContractState) -> u128 {
            let current_epoch = self.get_current_epoch();
            self.calculate_epoch_rewards(current_epoch, self.total_cyg_dao.read())
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn previous_epoch_rewards(self: @ContractState) -> u128 {
            let current_epoch = self.get_current_epoch();
            if current_epoch == 0 {
                0
            } else {
                self.calculate_epoch_rewards(current_epoch - 1, self.total_cyg_rewards.read())
            }
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn next_epoch_rewards(self: @ContractState) -> u128 {
            let current_epoch = self.get_current_epoch();
            self.calculate_epoch_rewards(current_epoch + 1, self.total_cyg_rewards.read())
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn blocks_this_epoch(self: @ContractState) -> u64 {
            get_block_timestamp() - self.last_epoch_time.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn epoch_progression(self: @ContractState) -> u128 {
            let time_elapsed = get_block_timestamp() - self.last_epoch_time.read();
            time_elapsed.into().div_wad(BLOCKS_PER_EPOCH.into())
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn until_next_epoch(self: @ContractState) -> u64 {
            BLOCKS_PER_EPOCH - (get_block_timestamp() - self.last_epoch_time.read())
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn until_supernova(self: @ContractState) -> u64 {
            self.death.read() - get_block_timestamp()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn total_progression(self: @ContractState) -> u128 {
            let time_elapsed = get_block_timestamp() - self.birth.read();
            time_elapsed.into().div_wad(DURATION.into())
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn doom_switch(self: @ContractState) -> bool {
            self.doom_switch.read()
        }

        /// ------------------------------------------------
        /// date time functions
        /// ------------------------------------------------

        /// # Implementation
        /// * IPillarsOfCreation
        fn timestamp_to_date(self: @ContractState, timestamp: u64) -> (u64, u64, u64) {
            timestamp_to_date(timestamp)
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn date_to_timestamp(self: @ContractState, year: u64, month: u64, day: u64) -> u64 {
            date_to_timestamp(year, month, day)
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn days_until_next_epoch(self: @ContractState) -> u64 {
            let epoch = self.get_current_epoch();
            if epoch == TOTAL_EPOCHS - 1 {
                return 0;
            }
            diff_days(get_block_timestamp(), self.epoch_info.read(epoch).end)
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn days_until_supernova(self: @ContractState) -> u64 {
            diff_days(get_block_timestamp(), self.death.read())
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn days_passed_this_epoch(self: @ContractState) -> u64 {
            let epoch = self.get_current_epoch();
            diff_days(self.epoch_info.read(epoch).start, get_block_timestamp())
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn star_formation_date(self: @ContractState) -> (u64, u64, u64) {
            timestamp_to_date(self.birth.read())
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn supernova_date(self: @ContractState) -> (u64, u64, u64) {
            timestamp_to_date(self.death.read())
        }

        ///----------------------------------------------------------------------------------------------------
        ///                                     NON-CONSTANT FUNCTIONS
        ///----------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IPillarsOfCreation
        fn update_shuttle(ref self: ContractState, borrowable: ContractAddress, collateral: ContractAddress) {
            /// Try and advance epoch
            self._advance_epoch();

            /// Update shuttle internally
            self._update_shuttle(borrowable, collateral);

            /// # Event
            /// * `UpdateShuttle`
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            let current_epoch = self.get_current_epoch();
            self.emit(UpdateShuttle { borrowable, collateral, caller, current_epoch, timestamp });
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn collect_cyg_all(ref self: ContractState, to: ContractAddress) -> u128 {
            /// Try and advance epoch
            self._advance_epoch();

            /// Get total shuttles length to loop 
            let shuttles_length = self.all_shuttles_length.read();
            let mut amount = 0;
            let mut shuttle_id = 0;

            /// Loop through each shuttle and check for pending CYG and collect
            /// We only pass `to` as `collect_interal` uses `get_caller_address()`
            loop {
                /// Escape 
                if shuttle_id == shuttles_length {
                    break;
                }

                /// Get shuttle struct for `shuttle_id`
                let shuttle = self.all_shuttles.read(shuttle_id);

                /// Updates shuttle and collects
                amount += self._collect_cyg(shuttle.borrowable, shuttle.collateral, to);

                /// Increase loop
                shuttle_id += 1;
            };

            /// # Event
            /// * `CollectAll`
            let caller = get_caller_address();
            self.emit(CollectAll { shuttles_length, caller, amount });

            amount
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn collect_cyg(
            ref self: ContractState, borrowable: ContractAddress, collateral: ContractAddress, to: ContractAddress
        ) -> u128 {
            /// Try and advance epoch
            self._advance_epoch();

            /// Collect CYG internally
            let amount = self._collect_cyg(borrowable, collateral, to);

            /// # Event
            /// * `Collect`
            let caller = get_caller_address();
            self.emit(Collect { borrowable, collateral, caller, to, amount });

            amount
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn accelerate_the_universe(ref self: ContractState) {
            /// Tries to advance epoch and updates all shuttles
            self._accelerate_the_universe();
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn drip_cyg_dao(ref self: ContractState) {
            /// Tries to advance epoch and updates all shuttles
            self._accelerate_the_universe();
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn adjust_shuttle_rewards(
            ref self: ContractState, borrowable: ContractAddress, collateral: ContractAddress, alloc_point: u128
        ) {
            // Check admin
            self._check_admin();
            /// Tries to advance epoch and updates all shuttles
            self._accelerate_the_universe();

            /// Load shuttle
            let mut shuttle = self.shuttle_info.read((borrowable, collateral));

            /// # Error
            /// * `not_init`
            assert(shuttle.active, 'not_init');

            /// Adjust total alloc points in the contract
            let old_alloc = shuttle.alloc_point;
            let total_alloc_point = (self.total_alloc_point.read() - old_alloc) + alloc_point;
            self.total_alloc_point.write(total_alloc_point);

            /// Adjust shuttle alloc point and store in mapping and array
            shuttle.alloc_point = alloc_point;
            self.all_shuttles.write(shuttle.pillars_id, shuttle);
            self.shuttle_info.write((borrowable, collateral), shuttle);
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn set_borrow_rewards(
            ref self: ContractState, borrowable: ContractAddress, collateral: ContractAddress, alloc_point: u128
        ) {
            // Check admin
            self._check_admin();
            /// Tries to advance epoch and updates all shuttles
            self._accelerate_the_universe();

            let mut borrow_rewards = self.shuttle_info.read((borrowable, collateral));

            /// # Error
            /// * `already_init`
            assert(!borrow_rewards.active, 'already_init');

            /// Increase alloc point. Dont sub alloc as is not init.
            let total_alloc = self.total_alloc_point.read() + alloc_point;
            self.total_alloc_point.write(total_alloc);

            /// Initialize borrow rewards
            borrow_rewards.active = true;
            borrow_rewards.alloc_point = alloc_point;
            borrow_rewards.borrowable = borrowable;
            borrow_rewards.collateral = collateral;

            // Assign Shuttle ID from factory
            let shuttle_id = IBorrowableDispatcher { contract_address: borrowable }.shuttle_id();
            borrow_rewards.shuttle_id = shuttle_id;

            /// Assign pillars id and increase shuttles - Do this to loop through all shuttles
            let shuttles_length = self.all_shuttles_length.read();
            borrow_rewards.pillars_id = shuttles_length;

            /// Increase shuttles length
            self.all_shuttles_length.write(shuttles_length + 1);
            /// Add lender rewards to internal array
            self.all_shuttles.write(shuttles_length, borrow_rewards);

            /// Store borrow rewards in mapping
            self.shuttle_info.write((borrowable, collateral), borrow_rewards);
        }


        /// # Implementation
        /// * IPillarsOfCreation
        fn set_lending_rewards(ref self: ContractState, borrowable: ContractAddress, alloc_point: u128) {
            // Check admin
            self._check_admin();
            /// Tries to advance epoch and updates all shuttles
            self._accelerate_the_universe();

            let mut lender_rewards = self.shuttle_info.read((borrowable, Zeroable::zero()));

            /// # Error
            /// * `already_init`
            assert(!lender_rewards.active, 'already_init');

            /// Increase alloc point. Dont sub alloc as is not init.
            let total_alloc = self.total_alloc_point.read() + alloc_point;
            self.total_alloc_point.write(total_alloc);

            /// Initialize lender rewards
            lender_rewards.active = true;
            lender_rewards.alloc_point = alloc_point;
            lender_rewards.borrowable = borrowable;
            lender_rewards.collateral = Zeroable::zero();

            // Assign Shuttle ID from factory
            let shuttle_id = IBorrowableDispatcher { contract_address: borrowable }.shuttle_id();
            lender_rewards.shuttle_id = shuttle_id;

            /// Assign pillars id and increase shuttles - Do this to loop through all shuttles
            let shuttles_length = self.all_shuttles_length.read();
            lender_rewards.pillars_id = shuttles_length;

            /// Increase shuttles length
            self.all_shuttles_length.write(shuttles_length + 1);
            /// Add lender rewards to internal array
            self.all_shuttles.write(shuttles_length, lender_rewards);

            /// Store borrow rewards in mapping
            self.shuttle_info.write((borrowable, Zeroable::zero()), lender_rewards);
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn track_rewards(
            ref self: ContractState, account: ContractAddress, balance: u128, collateral: ContractAddress
        ) {
            /// Don't allow dao reserves to receive any rewards
            let dao_reserves = self.hangar18.read().dao_reserves();
            if account == dao_reserves || account == Zeroable::zero() {
                return;
            }

            /// Caller is always borrowable as we track rewards from there
            let borrowable = get_caller_address();

            /// Load shuttle and user structs
            let mut shuttle = self._update_shuttle(borrowable, collateral);
            let mut user = self.user_info.read((borrowable, collateral, account));

            /// For borrowers the new_shares is their principal (ie. originally borrow amount)
            /// For lenders the new_shares is their deposited USDC amount
            let new_shares = balance;

            /// Calculate difference in reward debt for `account`
            let diff_shares: i128 = new_shares.into() - user.shares.into();

            let reward_per_share: i128 = shuttle.acc_reward_per_share.into();

            let diff_reward_debt: i128 = (diff_shares * reward_per_share) / ACC_PRECISION.into();

            /// Update user struct
            user.shares = new_shares;
            user.reward_debt = user.reward_debt + diff_reward_debt;
            self.user_info.write((borrowable, collateral, account), user);

            /// Update shuttle struct
            shuttle.total_shares = (shuttle.total_shares.into() + diff_shares).try_into().unwrap();

            self.shuttle_info.write((borrowable, collateral), shuttle);

            /// TODO - Bonus rewards

            /// # Event
            /// * `TrackRewards`
            self.emit(TrackRewards { borrowable, account, balance, collateral });
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn supernova(ref self: ContractState) {
            /// Tries to advance epoch and updates all shuttles
            self._accelerate_the_universe();
            /// Try to self-destruct
            self._supernova();
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn initialize_pillars(ref self: ContractState) {
            // Check admin
            self._check_admin();

            /// # Errors
            /// * `ALREADY_INITIALIZED` - Pillars can only be initialized once
            assert(self.epoch_info.read(0).total_rewards == 0, 'already_initialized');

            /// Calcualte the cyg per block for borrowers/lenders and the DAO at epoch `0`
            let cyg_per_block = self.calculate_cyg_per_block(0, self.total_cyg_rewards.read());
            let cyg_per_block_dao = self.calculate_cyg_per_block(0, self.total_cyg_dao.read());

            /// # Error
            /// * `cyg_per_block_too_high`
            assert(cyg_per_block < MAX_CYG_PER_BLOCK, 'cyg_per_block_too_high');
            assert(cyg_per_block_dao < MAX_CYG_PER_BLOCK, 'cyg_per_block_too_high');

            /// Store per block rates
            self.cyg_per_block_rewards.write(cyg_per_block);
            self.cyg_per_block_dao.write(cyg_per_block_dao);

            /// Store birth (now) and death (now + 8 years)
            let timestamp = get_block_timestamp();
            self.birth.write(timestamp);
            self.death.write(timestamp + DURATION);
            self.last_epoch_time.write(timestamp);
            self.last_drip_dao.write(timestamp);

            /// Store the epoch to mapping: epoch number => EpochInfo
            let epoch_zero = EpochInfo {
                epoch: 0,
                start: timestamp,
                end: timestamp + BLOCKS_PER_EPOCH,
                cyg_per_block: cyg_per_block,
                total_rewards: cyg_per_block * BLOCKS_PER_EPOCH.into(),
                total_claimed: 0
            };
            self.epoch_info.write(0, epoch_zero);

            /// # Event
            /// * `NewEpoch`
            let (old_epoch, new_epoch, old_cyg_per_block) = (0, 0, 0);
            let new_cyg_per_block = cyg_per_block;
            self.emit(NewEpoch { old_epoch, new_epoch, old_cyg_per_block, new_cyg_per_block });
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn set_doom_switch(ref self: ContractState) {
            /// Check admin
            self._check_admin();
            self._accelerate_the_universe();

            /// Set the doom switch, cannot be turned off!
            if self.doom_switch.read() {
                return;
            }

            self.doom_switch.write(true);

            /// # Event
            /// * `DoomSwitchSet`
            let timestamp = get_block_timestamp();
            let caller = get_caller_address();
            self.emit(DoomSwitch { timestamp, caller });
        }
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Modifier which is called before `collect`, `collect_all` and some admin functions
        fn _accelerate_the_universe(ref self: ContractState) {
            /// Try advance an epoch, does not revert
            self._advance_epoch();

            /// Loop through each shuttle and update it internally in `shuttle_info`
            /// Shuttles length here is different to hangar18 shuttles_length, this is 
            /// in reality pillars length
            let shuttles_length = self.all_shuttles_length.read();

            let mut shuttle_id = 0;
            loop {
                /// Escape 
                if shuttle_id == shuttles_length {
                    break;
                }

                /// Get shuttle for this `shuttle_id` and update shuttle
                let shuttle = self.all_shuttles.read(shuttle_id);
                self._update_shuttle(shuttle.borrowable, shuttle.collateral);

                /// Update id
                shuttle_id += 1;
            };

            /// Try and drip CYG to the DAO
            self._drip_cyg_dao();

            /// # Event
            /// * `AccelerateTheUniverse`
            self.emit(AccelerateTheUniverse { shuttles_length });
        }

        /// The caller collects their earned CYG and sends it to `to`.
        ///
        /// # Arguments
        /// * `borrowable` - The address of a borrowable contract (CygUSD)
        /// * `collateral` - The address of a collateral contract (CygLP) - This is zero for lenders
        /// * `to` - The address of the receiver of the CYG
        ///
        /// # Returns
        /// * The collected CYG amount
        fn _collect_cyg(
            ref self: ContractState, borrowable: ContractAddress, collateral: ContractAddress, to: ContractAddress
        ) -> u128 {
            let caller = get_caller_address();

            /// 1. Get shuttle and user. user is mutable as we update their reward debt
            let shuttle = self._update_shuttle(borrowable, collateral);
            let mut user = self.user_info.read((borrowable, collateral, caller));

            /// 2. Calculate caller's pending cyg amount
            let reward = user.shares.full_mul_div(shuttle.acc_reward_per_share, ACC_PRECISION);
            let accumulated_reward: i128 = reward.into();
            let cyg_amount = (accumulated_reward - user.reward_debt).try_into().unwrap();
            if cyg_amount == 0 {
                return 0;
            }

            /// 3. Update user struct for this shuttle
            user.reward_debt = accumulated_reward;
            self.user_info.write((borrowable, collateral, caller), user);

            /// TODO Bonus rewards

            /// 4. Make sure we have not passed this epochs total claimable and 
            ///    update the epoch's total claimed variable
            let current_epoch = self.get_current_epoch();
            let mut epoch = self.epoch_info.read(current_epoch);
            epoch.total_claimed += cyg_amount;
            self.epoch_info.write(current_epoch, epoch);

            /// 5. Mint CYG to `to`
            self.cyg_token.read().mint(to, cyg_amount);

            cyg_amount
        }

        /// Drips CYG to the hangar18's DAO reserves contract
        /// Called by accelerating the pillars of creation. If successful emits an event.
        fn _drip_cyg_dao(ref self: ContractState) {
            /// Calculate the pending cyg amount for the dao since last drip
            let timestamp = get_block_timestamp();
            let last_drip = self.last_drip_dao.read();
            let cyg_per_block = self.cyg_per_block_dao.read();
            let amount = (timestamp.into() - last_drip.into()) * cyg_per_block;

            if amount > 0 {
                /// Store timestamp as last DAO drip
                self.last_drip_dao.write(timestamp);
                /// Mint to the hangar18's DAO Reserves
                let dao_reserves = self.hangar18.read().dao_reserves();
                self.cyg_token.read().mint(dao_reserves, amount);

                /// # Event
                /// * `DAODrip`
                self.emit(DAODrip { dao_reserves, amount });
            }
        }

        /// Update the shuttle with the new reward per share and the latest update time to correctly
        /// calculate the latest rewards for users in this shuttle
        /// 
        /// # Arguments
        /// * `borrowable` - The address of a borrowable contract (CygUSD)
        /// * `collateral` - The address of a collateral contract (CygLP) - This is zero for lenders
        ///
        /// # Returns
        /// * The shuttle with the latest reward vars
        fn _update_shuttle(
            ref self: ContractState, borrowable: ContractAddress, collateral: ContractAddress
        ) -> ShuttleInfo {
            /// Load shuttle with `borrowable` and `collateral` (collateral here can be zero address)
            let mut shuttle = self.shuttle_info.read((borrowable, collateral));

            let timestamp = get_block_timestamp();

            /// Update shuttle
            if timestamp > shuttle.last_reward_time {
                /// Gas Savings
                let total_shares = shuttle.total_shares;

                /// The new reward per share is equal to:
                /// new_reward_per_share = (time_elapsed * cyg_per_block * shuttle points) / total points * total shares
                /// reward_per_share = old_reward_per_share + new_reward_per_share
                if total_shares > 0 {
                    let time_elapsed = timestamp - shuttle.last_reward_time;
                    let cyg_per_block = self.cyg_per_block_rewards.read();
                    let total_alloc = self.total_alloc_point.read();
                    let reward = (time_elapsed.into() * cyg_per_block * shuttle.alloc_point);
                    let reward_by_alloc = reward / total_alloc;
                    let reward_share = reward_by_alloc.full_mul_div(ACC_PRECISION, total_shares);

                    shuttle.acc_reward_per_share += reward_share;
                }

                /// Store timestamp as latest reward update
                shuttle.last_reward_time = timestamp;

                /// Store shuttle to mapping storage
                self.shuttle_info.write((borrowable, collateral), shuttle);
            }

            shuttle
        }

        /// Tries to advance the epoch internally, if advances it emits a `NewEpoch` event
        /// and updates the following variables:
        /// * `cyg_per_block_rewards` - The new CYG per block for lenders/borrowers
        /// * `cyg_per_block_dao` - The new CYG per block for the DAO
        /// * `last_epoch_time` - The current timestamp if we manage to advance epoch.
        /// * `epoch_info` - The new epoch struct which contains info on epoch start, end, rewards, etc.
        fn _advance_epoch(ref self: ContractState) {
            /// How many blocks have passed since start of the epoch
            let timestamp = get_block_timestamp();
            let blocks_this_epoch = timestamp - self.last_epoch_time.read();

            /// 1. Check if we have passed epoch blocks
            if blocks_this_epoch >= BLOCKS_PER_EPOCH {
                /// Calculate the new epoch
                let new_epoch = self.get_current_epoch();

                /// 2. Check if we have passed death
                if new_epoch < TOTAL_EPOCHS {
                    /// 3. Store current timestamp as `last_epoch_time`
                    self.last_epoch_time.write(timestamp);

                    /// Get the CYG per block up to now (for the event)
                    let old_cyg_per_block = self.cyg_per_block_rewards.read();

                    /// 4. Get the total cyg rewards for borrowers/lenders and 
                    ///    calculate the new cyg per block given the new epoch
                    let total_cyg = self.total_cyg_rewards.read();
                    let new_cyg_per_block = self.calculate_cyg_per_block(new_epoch, total_cyg);
                    self.cyg_per_block_rewards.write(new_cyg_per_block);

                    /// 5. Get the total cyg rewards that the dao receives 
                    ///    calculate the new cyg per block given the new epoch
                    let total_cyg = self.total_cyg_dao.read();
                    let new_cyg_per_block_dao = self.calculate_cyg_per_block(new_epoch, total_cyg);
                    self.cyg_per_block_dao.write(new_cyg_per_block_dao);

                    /// 6. Create a new epoch and add to storage with
                    let epoch_info = EpochInfo {
                        epoch: new_epoch.try_into().unwrap(),
                        cyg_per_block: new_cyg_per_block,
                        total_rewards: new_cyg_per_block * BLOCKS_PER_EPOCH.into(),
                        total_claimed: 0,
                        start: timestamp,
                        end: timestamp + BLOCKS_PER_EPOCH
                    };
                    self.epoch_info.write(new_epoch, epoch_info);

                    /// # Event
                    /// * `NewEpoch`
                    let old_epoch = new_epoch - 1;
                    self.emit(NewEpoch { old_epoch, new_epoch, old_cyg_per_block, new_cyg_per_block });
                } else {
                    /// Try explode
                    self._supernova();
                }
            }
        }

        /// Emits supernova event when we reach the end of this contracts life
        fn _supernova(ref self: ContractState) {
            /// Check that we have passed total epochs
            if (self.get_current_epoch() < TOTAL_EPOCHS) {
                return;
            }

            /// # Error
            /// * `not_doomed_yet` - Assert we are doomed, can only be set my admin once (ideally in the last epoch)
            assert(self.doom_switch.read(), 'not_doomed_yet');

            // Hail Satan ʕ•ᴥ•ʔ
            // By now this contract would have minted exactly 5,000,000. Any mints after will be reverted by the
            // CYG contract. Remove self-destruct as will be deprecated
            let timestamp = get_block_timestamp();

            /// # Event
            /// * `Supernova`
            self.emit(Supernova { timestamp });
        }

        /// # Security
        /// * Checks that caller is admin
        fn _check_admin(self: @ContractState) {
            // Get admin address from the hangar18
            let admin = self.hangar18.read().admin();

            /// # Error
            /// * `ONLY_ADMIN` - Reverts if sender is not hangar18 admin 
            assert(get_caller_address() == admin, 'only_admin')
        }
    }
}

