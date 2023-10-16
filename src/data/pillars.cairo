use starknet::ContractAddress;
use cygnus::data::signed_integer::{i256::{i256, i256TryIntou256}, integer_trait::{IntegerTrait}};

/// Epoch Information on each epoch
///
/// epoch - The ID for this epoch
/// cyg_per_block - The CYG reward rate for this epoch
/// total_rewards - The total amount of CYG estimated to be rewarded in this epoch
/// total_claimed - The total amount of claimed CYG
/// start - The unix timestamp of when this epoch started
/// end - The unix timestamp of when it ended or is estimated to end
#[derive(Copy, Drop, starknet::Store, Serde)]
struct EpochInfo {
    epoch: u8,
    cyg_per_block: u256,
    total_rewards: u256,
    total_claimed: u256,
    start: u64,
    end: u64
}

/// ShuttleInfo Info of each borrowable
///
/// active - Whether the pool is active or not
/// shuttle_id - The ID for this shuttle to identify in hangar18
/// borrowable - The address of this shuttle id's borrowable
/// collateral - The address of this shuttle id's collateral
/// total_shares - The total number of shares held in the pool
/// acc_reward_per_share - The accumulated reward per share
/// last_reward_time - The timestamp of the last reward distribution
/// alloc_point The allocation points of the pool
/// pillars_id - Unique ID for this shuttle (1 shuttle id = 2 pillars id)
#[derive(Copy, Drop, starknet::Store, Serde)]
struct ShuttleInfo {
    active: bool,
    shuttle_id: u32,
    borrowable: ContractAddress,
    collateral: ContractAddress,
    total_shares: u256,
    acc_reward_per_share: u256,
    last_reward_time: u64,
    alloc_point: u256,
    pillars_id: u32
}

/// UserInfo Info of each user
///
/// shares - The amount of shares of the user (for borrowers their borrow balance and for lenders their USD lend amount)
/// reward_debt - The amount of rewards debt for each user
#[derive(Drop, starknet::Store, Serde)]
struct UserInfo {
    shares: u256,
    reward_debt: i256
}
