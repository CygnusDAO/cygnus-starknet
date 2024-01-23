mod Events {
    use starknet::{ContractAddress};

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u128
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u128
    }

    #[derive(Drop, starknet::Event)]
    struct PillarsOfCreationSet {
        old_pillars_of_creation: ContractAddress,
        new_pillars_of_creation: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct CygMainnetSet {
        old_cyg_mainnet: felt252,
        new_cyg_mainnet: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct InitializeTeleport {
        caller: ContractAddress,
        recipient: felt252,
        amount: u128
    }

    #[derive(Drop, starknet::Event)]
    struct TeleportToEthereum {
        recipient: ContractAddress,
        amount: u128
    }

    #[derive(Drop, starknet::Event)]
    struct TeleportToStarknet {
        recipient: ContractAddress,
        amount: u128
    }
}
