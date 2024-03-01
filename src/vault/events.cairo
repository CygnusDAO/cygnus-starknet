mod Events {
    use starknet::{ContractAddress};

    /// ClaimReward
    #[derive(Drop, starknet::Event)]
    struct ClaimReward {
        token: ContractAddress,
        pending: u256
    }

    /// Deposit
    #[derive(Drop, starknet::Event)]
    struct Deposit {
        caller: ContractAddress,
        cyg_amount: u256
    }

    /// Withdraw
    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        caller: ContractAddress,
        cyg_amount: u256
    }

    /// SweepToken
    #[derive(Drop, starknet::Event)]
    struct SweepToken {
        caller: ContractAddress,
        token: ContractAddress,
        amount: u256
    }

    /// NewRewardToken
    #[derive(Drop, starknet::Event)]
    struct NewRewardToken {
        token: ContractAddress
    }
}
