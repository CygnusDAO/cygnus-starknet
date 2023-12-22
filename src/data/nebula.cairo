use starknet::ContractAddress;
use cygnus::oracle::pragma_interface::{DataType};

#[derive(Drop, starknet::Store, Serde, Copy)]
struct NebulaOracle {
    initialized: bool,
    oracle_id: u8,
    name: felt252,
    underlying: ContractAddress,
    token0: ContractAddress,
    token1: ContractAddress,
    price_feed0: felt252,
    price_feed1: felt252,
    token0_decimals: u64,
    token1_decimals: u64,
    created_at: u64
}

#[derive(Drop, Serde)]
struct LPInfo {
    token0: ContractAddress,
    token1: ContractAddress,
    token0_price: u128,
    token1_price: u128,
    token0_reserves: u128,
    token1_reserves: u128,
    token0_decimals: u64,
    token1_decimals: u64,
    reserves0_usd: u128,
    reserves1_usd: u128
}
