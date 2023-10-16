use starknet::{ContractAddress};
use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};

// Nebula struct
#[derive(Drop, Copy, starknet::Store, Serde)]
struct Nebula {
    name: felt252,
    nebula_address: ContractAddress,
    nebula_id: u32,
    total_oracles: u32,
    created_at: u64
}
