use starknet::ContractAddress;

#[derive(Drop, Serde, Copy)]
enum Aggregator {
    #[default]
    NONE,
    AVNU,
    FIBROUS,
    JEDISWAP,
}

#[derive(Drop, Serde)]
struct LeverageCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    lp_amount_min: u128,
    aggregator: Aggregator,
    swapdata: Array<Span<felt252>>,
}

#[derive(Drop, Serde)]
struct DeleverageCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    borrower: ContractAddress,
    cyg_lp_amount: u128,
    usd_amount_min: u128,
    aggregator: Aggregator,
    swapdata: Array<Span<felt252>>
}

impl DefaultLeverage of Default<LeverageCalldata> {
    fn default() -> LeverageCalldata {
        LeverageCalldata {
            lp_token_pair: Zeroable::zero(),
            collateral: Zeroable::zero(),
            borrowable: Zeroable::zero(),
            recipient: Zeroable::zero(),
            lp_amount_min: 0,
            aggregator: Aggregator::NONE,
            swapdata: array![],
        }
    }
}

impl DefaultDeleverage of Default<DeleverageCalldata> {
    fn default() -> DeleverageCalldata {
        DeleverageCalldata {
            lp_token_pair: Zeroable::zero(),
            collateral: Zeroable::zero(),
            borrowable: Zeroable::zero(),
            recipient: Zeroable::zero(),
            borrower: Zeroable::zero(),
            cyg_lp_amount: 0,
            usd_amount_min: 0,
            aggregator: Aggregator::NONE,
            swapdata: array![]
        }
    }
}

