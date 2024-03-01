mod Events {
    use starknet::ContractAddress;

    /// # Event
    /// * `NewPendingAdmin`
    #[derive(Drop, starknet::Event)]
    struct NewPendingAdmin {
        old_pending: ContractAddress,
        new_pending: ContractAddress
    }

    /// # Event
    /// * `NewAdmin`
    #[derive(Drop, starknet::Event)]
    struct NewAdmin {
        old_admin: ContractAddress,
        new_admin: ContractAddress
    }

    /// # Event
    /// * `NewNebula`
    #[derive(Drop, starknet::Event)]
    struct NewNebula {
        name: felt252,
        nebula_id: u32,
        nebula_address: ContractAddress,
        created_at: u64
    }

    /// # Event
    /// * `NewOracle`
    #[derive(Drop, starknet::Event)]
    struct NewOracle {
        nebula_id: u32,
        lp_token_pair: ContractAddress
    }
}
