use starknet::ContractAddress;

/// The info of the user in the X1 Vault
///
/// total_shares - The user's amount of Staked CYG
/// reward_debt - The reward debt for the token
/// last_claim - The timestamp of the last claim
#[derive(Copy, Drop, starknet::Store, Serde)]
struct UserInfo {
    reward_debt: u256,
    last_claim: u64,
}
