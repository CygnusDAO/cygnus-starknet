/// Interest Rate Model
#[derive(Drop, starknet::Store, Serde)]
struct InterestRateModel {
    base_rate_per_second: u64,
    multiplier_per_second: u64,
    jump_multiplier_per_second: u64,
    kink: u64
}

/// Borrow Snapshot of each borrower across all pools
#[derive(Drop, Copy, starknet::Store, Serde)]
struct BorrowSnapshot {
    principal: u256,
    interest_index: u256,
}
