mod Events {
    use starknet::{ContractAddress};

    #[derive(Drop, starknet::Event)]
    struct DoomSwitch {
        timestamp: u64,
        caller: ContractAddress
    }


    #[derive(Drop, starknet::Event)]
    struct Supernova {
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct NewEpoch {
        old_epoch: u128,
        new_epoch: u128,
        old_cyg_per_block: u128,
        new_cyg_per_block: u128
    }

    #[derive(Drop, starknet::Event)]
    struct DAODrip {
        dao_reserves: ContractAddress,
        amount: u128
    }

    #[derive(Drop, starknet::Event)]
    struct AccelerateTheUniverse {
        shuttles_length: u32
    }

    #[derive(Drop, starknet::Event)]
    struct UpdateShuttle {
        borrowable: ContractAddress,
        collateral: ContractAddress,
        caller: ContractAddress,
        current_epoch: u128,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct Collect {
        borrowable: ContractAddress,
        collateral: ContractAddress,
        caller: ContractAddress,
        to: ContractAddress,
        amount: u128
    }

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
}
