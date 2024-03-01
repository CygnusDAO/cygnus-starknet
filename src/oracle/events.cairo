mod Events {
    use starknet::ContractAddress;
    /// # Event
    /// * `NewLPOracle`
    #[derive(Drop, starknet::Event)]
    struct NewLPOracle {
        lp_token_pair: ContractAddress
    }
}
