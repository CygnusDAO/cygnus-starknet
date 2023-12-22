use starknet::ContractAddress;

#[starknet::interface]
trait IUniswapV2Pair<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn totalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;

    // LP
    fn get_reserves(self: @TState) -> (u256, u256, felt252);
    fn token0(self: @TState) -> ContractAddress;
    fn token1(self: @TState) -> ContractAddress;

    fn swap(
        ref self: TState, amount0Out: u256, amount1Out: u256, to: ContractAddress, data_len: felt252, data: felt252
    );

    fn burn(ref self: TState, recipient: ContractAddress) -> (u256, u256);
}
