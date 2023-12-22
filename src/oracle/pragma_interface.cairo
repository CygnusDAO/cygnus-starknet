use starknet::ContractAddress;

/// Data Types
/// The value is the `pair_id` of the data
/// For future option, pair_id and expiration timestamp
///
/// * `Spot` - Spot price
/// * `Future` - Future price
/// * `Option` - Option price
#[derive(Drop, Copy, Serde)]
enum DataType {
    SpotEntry: felt252,
    FutureEntry: (felt252, u64),
    GenericEntry: felt252,
// OptionEntry: (felt252, felt252),
}

#[derive(Serde, Drop, Copy)]
struct PragmaPricesResponse {
    price: u128,
    decimals: u32,
    last_updated_timestamp: u64,
    num_sources_aggregated: u32,
    expiration_timestamp: Option<u64>,
}

#[derive(Serde, Drop, Copy, starknet::Store)]
enum AggregationMode {
    Median: (),
    Mean: (),
    Error: (),
}

#[starknet::interface]
trait IOracleABI<TContractState> {
    fn get_decimals(self: @TContractState, data_type: DataType) -> u32;
    fn get_data_median(self: @TContractState, data_type: DataType) -> PragmaPricesResponse;
    fn get_data(self: @TContractState, data_type: DataType, aggregation_mode: AggregationMode) -> PragmaPricesResponse;
}

