//! Periphery

// Libraries
use starknet::ContractAddress;
use cygnus::data::altair::{ShuttleInfoC, ShuttleInfoB};
use cygnus::data::calldata::{LeverageCalldata, DeleverageCalldata};

/// # Interface - Altair
#[starknet::interface]
trait IAltairCall<T> {
    /// Function that is called by the CygnusBorrow contract and decodes data to carry out the leverage
    /// Will only succeed if: Caller is borrow contract & Borrow contract was called by router
    /// 
    /// # Arguments
    /// * `sender` - Address of the contract that initialized the borrow transaction (address of the router)
    /// * `borrow_amount` - The amount of USDC to leverage
    /// * `calldata` - The encoded byte data passed from the CygnusBorrow contract to the router
    ///
    /// # Returns
    /// * The amount of LP minted
    fn altair_borrow_09E(ref self: T, sender: ContractAddress, borrow_amount: u128, calldata: LeverageCalldata) -> u128;

    /// Function that is called by the CygnusCollateral contract and decodes data to carry out the deleverage.
    /// Will only succeed if: Caller is collateral contract & collateral contract was called by router
    ///
    /// # Arguments
    /// * `sender` - Address of the contract that initialized the redeem transaction (address of the router)
    /// * `redeem_amount` - The amount of LP to deleverage
    /// * `calldata` - The encoded byte data passed from the CygnusCollateral contract to the router
    ///
    /// # Returns
    /// * The amount of USDC received from deleveraging LP
    fn altair_redeem_u91A(
        ref self: T, sender: ContractAddress, redeem_amount: u128, calldata: DeleverageCalldata
    ) -> u128;

    /// Function used to flash liquidate a positoin
    ///
    /// # Arguments
    /// * `sender` - Address of the contract that initialized the redeem transaction (address of the router)
    /// * `redeem_amount` - The amount of LP Received
    /// * `repay_amount` - The amount of USD that must be repaid
    /// * `calldata` - The encoded byte data passed from the CygnusCollateral contract to the router
    ///
    /// # Returns
    /// * The amount of USDC received from deleveraging LP
    fn altair_liquidate_f2x(
        ref self: T, sender: ContractAddress, cyg_lp_amount: u128, repay_amount: u128, calldata: DeleverageCalldata
    ) -> u128;
}

