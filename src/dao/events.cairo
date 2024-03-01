mod DAOReservesEvents {
    use starknet::ContractAddress;
    use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};

    #[derive(Drop, starknet::Event)]
    struct FundX1VaultUSD {
        borrowable: IBorrowableDispatcher,
        dao_shares: u128,
        assets: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct FundX1VaultUSDAll {
        total_shuttles: u32,
        dao_shares: u128,
        assets: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct FundDAOSafeCygLP {
        dao_shares: u128
    }

    #[derive(Drop, starknet::Event)]
    struct FundDAOSafeCygLPAll {
        total_shuttles: u32,
        dao_shares: u128
    }

    #[derive(Drop, starknet::Event)]
    struct NewX1VaultWeight {
        old_weight: u128,
        new_weight: u128
    }

    #[derive(Drop, starknet::Event)]
    struct CygTokenSet {
        cyg_token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct PrivateBankerSwitch {
        private_banker: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct CygTokenClaim {
        to: ContractAddress,
        amount: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct NewDAOSafe {
        old_safe: ContractAddress,
        new_safe: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct NewX1Vault {
        old_vault: ContractAddress,
        new_vault: ContractAddress,
    }
}
