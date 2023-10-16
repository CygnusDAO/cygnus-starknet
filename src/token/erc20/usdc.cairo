use starknet::ContractAddress;

#[starknet::interface]
trait IUsdc<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn balanceOf(self: @TState, account: felt252) -> u256;
    fn approve(ref self: TState, account: felt252, amount: u256);
    fn transfer(ref self: TState, recipient: felt252, amount: u256) -> bool;
    fn transferFrom(ref self: TState, sender: felt252, recipient: felt252, amount: u256) -> bool;
}
