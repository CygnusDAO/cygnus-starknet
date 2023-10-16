#[derive(Drop, starknet::Store, Serde)]
struct ShuttleInfoC {
    shuttle_id: u32,
    total_supply: u256,
    total_balance: u256,
    total_assets: u256,
    exchange_rate: u256,
    debt_ratio: u256,
    liquidation_fee: u256,
    liquidation_incentive: u256,
}

#[derive(Drop, starknet::Store, Serde)]
struct ShuttleInfoB {
    shuttle_id: u32,
    total_supply: u256,
    total_balance: u256,
    total_borrows: u256,
    total_assets: u256,
    exchange_rate: u256,
    reserve_factor: u256,
    utilization_rate: u256,
    supply_rate: u256,
    borrow_rate: u256,
}
