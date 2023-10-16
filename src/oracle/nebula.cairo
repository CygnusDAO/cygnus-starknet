use starknet::ContractAddress;

#[starknet::interface]
trait ICygnusNebula<TState> {
    fn lp_token_price(self: @TState, lp_token_pair: ContractAddress) -> u256;
    fn name(self: @TState) -> felt252;
    fn initialize_oracle(
        ref self: TState, lp_token_pair: ContractAddress, price_feeds: Array<ContractAddress>
    );
}

#[starknet::contract]
mod CygnusNebula {
    use starknet::{ContractAddress, get_caller_address};
    use super::ICygnusNebula;

    /// # Storage
    #[storage]
    struct Storage {
        name: felt252,
    }

    #[external(v0)]
    impl NebulaImpl of ICygnusNebula<ContractState> {
        /// Human friendly name for this nebula implementation (ie `Balancer Weighted Pools`, etc.)
        fn name(self: @ContractState) -> felt252 {
            120
        }

        fn lp_token_price(self: @ContractState, lp_token_pair: ContractAddress) -> u256 {
            //TODO - Implement correct pricing
            3_000000000_000000000
        }


        fn initialize_oracle(
            ref self: ContractState,
            lp_token_pair: ContractAddress,
            price_feeds: Array<ContractAddress>
        ) { // TODO
        }
    }
}
