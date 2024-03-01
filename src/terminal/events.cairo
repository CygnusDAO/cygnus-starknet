mod BorrowableEvents {
    use starknet::{ContractAddress};
    use cygnus::rewarder::pillars::{IPillarsOfCreationDispatcher, IPillarsOfCreationDispatcherTrait};

    /// Transfer
    #[derive(Drop, starknet::Event)]
    struct NewPillarsOfCreation {
        old_pillars: IPillarsOfCreationDispatcher,
        new_pillars: IPillarsOfCreationDispatcher,
    }


    /// Transfer
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u128
    }

    /// Approval
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u128
    }

    // SyncBalance
    #[derive(Drop, starknet::Event)]
    struct SyncBalance {
        balance: u128
    }

    /// Deposit
    #[derive(Drop, starknet::Event)]
    struct Deposit {
        caller: ContractAddress,
        recipient: ContractAddress,
        assets: u128,
        shares: u128
    }

    /// Withdraw
    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        caller: ContractAddress,
        recipient: ContractAddress,
        owner: ContractAddress,
        assets: u128,
        shares: u128
    }

    /// NewReserveFactor
    #[derive(Drop, starknet::Event)]
    struct NewReserveFactor {
        old_reserve_factor: u128,
        new_reserve_factor: u128
    }

    /// NewInterestRateModel
    #[derive(Drop, starknet::Event)]
    struct NewInterestRateModel {
        base_rate: u128,
        multiplier: u128,
        kink_muliplier: u128,
        kink: u128
    }

    /// AccrueInterest
    #[derive(Drop, starknet::Event)]
    struct AccrueInterest {
        cash: u128,
        borrows: u128,
        interest: u128,
        new_reserves: u128
    }

    /// Borrow
    #[derive(Drop, starknet::Event)]
    struct Borrow {
        caller: ContractAddress,
        borrower: ContractAddress,
        receiver: ContractAddress,
        borrow_amount: u128,
        repay_amount: u128
    }

    /// Liquidate
    #[derive(Drop, starknet::Event)]
    struct Liquidate {
        caller: ContractAddress,
        borrower: ContractAddress,
        receiver: ContractAddress,
        cyg_lp_amount: u128,
        max: u128,
        amount_usd: u128
    }
}

mod CollateralEvents {
    use starknet::{ContractAddress};

    /// Transfer
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u128
    }

    /// Approval
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u128
    }

    // SyncBalance
    #[derive(Drop, starknet::Event)]
    struct SyncBalance {
        balance: u128
    }

    /// Deposit
    #[derive(Drop, starknet::Event)]
    struct Deposit {
        caller: ContractAddress,
        recipient: ContractAddress,
        assets: u128,
        shares: u128
    }

    /// Withdraw
    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        caller: ContractAddress,
        recipient: ContractAddress,
        owner: ContractAddress,
        assets: u128,
        shares: u128
    }


    /// NewLiquidationFee
    #[derive(Drop, starknet::Event)]
    struct NewLiquidationFee {
        old_liq_fee: u128,
        new_liq_fee: u128
    }

    /// NewLiqIncentive
    #[derive(Drop, starknet::Event)]
    struct NewLiquidationIncentive {
        old_incentive: u128,
        new_incentive: u128
    }


    /// NewDebtRatio
    #[derive(Drop, starknet::Event)]
    struct NewDebtRatio {
        old_ratio: u128,
        new_ratio: u128
    }

    /// Seize
    #[derive(Drop, starknet::Event)]
    struct Seize {
        liquidator: ContractAddress,
        borrower: ContractAddress,
        cyg_lp_amount: u128
    }
}
