use starknet::ContractAddress;

#[starknet::interface]
trait IUniV2Pair<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn balanceOf(self: @TState, account: felt252) -> u256;
    fn approve(ref self: TState, account: felt252, amount: u256);
    fn transfer(ref self: TState, recipient: felt252, amount: u256) -> bool;
    fn transferFrom(ref self: TState, sender: felt252, recipient: felt252, amount: u256) -> bool;
    fn token0(self: @TState) -> felt252;
    fn token1(self: @TState) -> felt252;
    fn get_reserves(self: @TState) -> (u256, u256, felt252);
    fn totalSupply(self: @TState) -> u256;
}
