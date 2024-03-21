use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
struct VestingSchedule {
    beneficiary: ContractAddress,
    cliff: u256,
    start: u256,
    duration: u256,
    slice_period_seconds: u256,
    revocable: bool,
    amount_total: u256,
    released: u256,
    revoked: bool
}
