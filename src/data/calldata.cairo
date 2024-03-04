use starknet::ContractAddress;

#[derive(Drop, Serde, Copy)]
enum Aggregator {
    #[default]
    JEDISWAP,
    EKUBO,
    AVNU,
    FIBROUS,
}

#[derive(Drop, Serde)]
enum CallbackID {
    LEVERAGE,
    DELEVERAGE,
    FLASH_LIQUIDATE,
}

#[derive(Drop, Serde)]
struct LeverageCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    lp_amount_min: u128,
    aggregator: Aggregator,
    swapdata: Array<Span<felt252>>
}

#[derive(Drop, Serde)]
struct DeleverageCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    cyg_lp_amount: u128,
    usd_amount_min: u128,
    aggregator: Aggregator,
    swapdata: Array<Span<felt252>>
}

#[derive(Drop, Serde)]
struct LiquidateCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    borrower: ContractAddress,
    repay_amount: u128,
    aggregator: Aggregator,
    swapdata: Array<Span<felt252>>
}

