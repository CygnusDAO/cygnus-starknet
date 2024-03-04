//! Jediswap

// Libraries
use starknet::ContractAddress;

#[starknet::interface]
trait IJediswapRouter<T> {
    // @notice Swaps an exact amount of input tokens for as many output tokens as possible, along the route determined by the path
    // @dev `caller` should have already given the router an allowance of at least amountIn on the input token
    // @param amountIn The amount of input tokens to send
    // @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert
    // @param path_len Length of path array
    // @param path Array of pair addresses through which swaps are chained
    // @param to Recipient of the output tokens
    // @param deadline Timestamp after which the transaction will revert
    // @return amounts_len Length of amounts array
    // @return amounts The input token amount and all subsequent output token amounts
    fn swap_exact_tokens_for_tokens(
        ref self: T,
        amountIn: u256,
        amountOutMin: u256,
        path: Array<ContractAddress>,
        to: ContractAddress,
        deadline: u64
    ) -> Array<u256>;

    // @notice Add liquidity to a pool
    // @dev `caller` should have already given the router an allowance of at least amountADesired/amountBDesired on tokenA/tokenB
    // @param tokenA Address of tokenA
    // @param tokenB Address of tokenB
    // @param amountADesired The amount of tokenA to add as liquidity
    // @param amountBDesired The amount of tokenB to add as liquidity
    // @param amountAMin Bounds the extent to which the B/A price can go up before the transaction reverts. Must be <= amountADesired
    // @param amountBMin Bounds the extent to which the A/B price can go up before the transaction reverts. Must be <= amountBDesired
    // @param to Recipient of liquidity tokens
    // @param deadline Timestamp after which the transaction will revert
    // @return amountA The amount of tokenA sent to the pool
    // @return amountB The amount of tokenB sent to the pool
    // @return liquidity The amount of liquidity tokens minted
    fn add_liquidity(
        ref self: T,
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        amountADesired: u256,
        amountBDesired: u256,
        amountAMin: u256,
        amountBMin: u256,
        to: ContractAddress,
        deadline: u64,
    ) -> (u256, u256, u256);
}
