// Core libs
use starknet::{
    ContractAddress, get_caller_address, ClassHash, contract_address_const, ClassHashIntoFelt252,
    Felt252TryIntoClassHash, class_hash_const, class_hash_to_felt252, class_hash_try_from_felt252
};

// Foundry
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait, start_warp, stop_warp, ContractClass};

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
use cygnus::data::nebula::{LPInfo, NebulaOracle};

// TIMESTAMP FORK: 1699559919

/// ----------------------------------------------------------------------------------
///                               DEPOSIT & REDEEM TEST
/// ----------------------------------------------------------------------------------

#[test]
#[fork("MAINNET")]
fn correct_price_for_eth_feed() {
    let (_, _, collateral, _, _) = setup();
    let oracle = ICygnusNebulaDispatcher { contract_address: collateral.nebula() };
    let o = oracle.get_asset_price(DataType::SpotEntry('ETH/USD'));
    /// Check manually
    o.print();
}

#[test]
#[fork("MAINNET")]
fn test_get_lp_token_price_from_oracle() {
    let (_, _, collateral, lp_token, _) = setup();
    let oracle = ICygnusNebulaDispatcher { contract_address: collateral.nebula() };
    let o = oracle.lp_token_price(lp_token.contract_address);
    /// Check manually
    o.print();
}

#[test]
#[fork("MAINNET")]
fn oracle_matches_collateral() {
    let (_, _, collateral, lp_token, _) = setup();
    let oracle = ICygnusNebulaDispatcher { contract_address: collateral.nebula() };
    let o = oracle.lp_token_price(lp_token.contract_address);
    let price = collateral.get_lp_token_price();
    assert(o == price, 'collateral,oracle differ');
}

#[test]
#[fork("MAINNET")]
fn lp_info_is_correct() {
    let (_, _, collateral, lp_token, _) = setup();
    let oracle = ICygnusNebulaDispatcher { contract_address: collateral.nebula() };

    let info: LPInfo = oracle.lp_token_info(lp_token.contract_address);

    'Tokens'.print();
    info.token0.print();
    info.token1.print();

    'Prices'.print();
    info.token0_price.print();
    info.token1_price.print();

    'Reserves'.print();
    info.token0_reserves.print();
    info.token1_reserves.print();

    'Decimals'.print();
    info.token0_decimals.print();
    info.token1_decimals.print();

    'Reserves USD'.print();
    info.reserves0_usd.print();
    info.reserves1_usd.print();
}
