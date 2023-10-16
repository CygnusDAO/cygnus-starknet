use starknet::ContractAddress;
//use array::ArrayTrait;

// TODO: ADD BYTES array for avnu calldata

#[derive(Drop, Copy, Serde, PartialEq)]
struct LeverageCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    lp_amount_min: u256,
}

#[derive(Drop, Copy, Serde, PartialEq)]
struct LiquidateCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    borrower: ContractAddress,
    repay_amount: u256
}

#[derive(Drop, Copy, Serde, PartialEq)]
struct DeleverageCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    redeem_tokens: u256,
    usd_amount_min: u256,
}
