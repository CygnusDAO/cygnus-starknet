#[derive(Drop, Serde)]
struct ShuttleInfoC {
    shuttle_id: u32,
    total_supply: u128,
    total_balance: u128,
    total_assets: u128,
    exchange_rate: u128,
    debt_ratio: u128,
    liquidation_fee: u128,
    liquidation_incentive: u128,
    lp_token_price: u128
}

#[derive(Drop, Serde)]
struct ShuttleInfoB {
    shuttle_id: u32,
    total_supply: u128,
    total_balance: u128,
    total_borrows: u128,
    total_assets: u128,
    exchange_rate: u128,
    reserve_factor: u128,
    utilization_rate: u128,
    supply_rate: u128,
    borrow_rate: u128,
    usd_price: u128
}

#[derive(Drop, Serde)]
struct BorrowerPosition {
    shuttle_id: u32,
    position_lp: u128,
    position_usd: u128,
    health: u128,
    cyg_lp_balance: u128,
    principal: u128,
    borrow_balance: u128,
    lp_token_price: u128,
    liquidity: u128,
    shortfall: u128,
    exchange_rate: u128,
}
