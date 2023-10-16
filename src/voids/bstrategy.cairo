#[starknet::interface]
trait IZKLendMarket<TContractState> {
    /// Deposit a token into a market
    fn deposit(ref self: TContractState, token: felt252, amount: felt252);

    /// Withdraw a token from a market
    fn withdraw(ref self: TContractState, token: felt252, amount: felt252);

    /// Get our balance of zTOKEN
    fn balanceOf(self: @TContractState, account: felt252) -> u256;
}

#[starknet::interface]
trait IZKToken<TContractState> {
    /// Get our balance of zTOKEN
    fn balanceOf(self: @TContractState, account: felt252) -> u256;
}
