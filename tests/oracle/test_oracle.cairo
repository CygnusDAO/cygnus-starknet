// Core libs
use starknet::{ContractAddress, get_caller_address, ClassHash, contract_address_const};

// Foundry
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait, start_warp, stop_warp};

// Cygnus
use tests::setup::{setup};
use tests::users::{admin, borrower, lender};
use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use integer::BoundedInt;
use snforge_std::PrintTrait;
use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
use cygnus::oracle::pragma_interface::{DataType};

// TIMESTAMP FORK: 1699559919

/// ----------------------------------------------------------------------------------
///                               DEPOSIT & REDEEM TEST
/// ----------------------------------------------------------------------------------

#[test]
#[fork("MAINNET")]
fn correct_price_for_eth_feed() {
    let (hangar18, borrowable, collateral, lp_token, usdc) = setup();
    let oracle = ICygnusNebulaDispatcher { contract_address: collateral.nebula() };
    let o = oracle.get_asset_price(DataType::SpotEntry('ETH/USD'));
    /// Check manually
    o.print();
}

#[test]
#[fork("MAINNET")]
fn test_get_lp_token_price_from_oracle() {
    let (hangar18, borrowable, collateral, lp_token, usdc) = setup();
    let oracle = ICygnusNebulaDispatcher { contract_address: collateral.nebula() };
    let o = oracle.lp_token_price(lp_token.contract_address);
    /// Check manually
    o.print();
}

#[test]
#[fork("MAINNET")]
fn oracle_matches_collateral() {
    let (hangar18, borrowable, collateral, lp_token, usdc) = setup();
    let oracle = ICygnusNebulaDispatcher { contract_address: collateral.nebula() };
    let o = oracle.lp_token_price(lp_token.contract_address);
    let price = collateral.get_lp_token_price();
    assert(o == price, 'collateral,oracle differ');
}
