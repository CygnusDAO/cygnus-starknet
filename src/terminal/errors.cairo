mod CollateralErrors {
    const BORROWER_ZERO_ADDRESS: felt252 = 'c_borrower_cant_be_zero';
    const BORROWER_COLLATERAL_ADDRESS: felt252 = 'c_borrower_cant_be_collateral';
    const INVALID_RANGE: felt252 = 'c_invalid_range';
    const ONLY_ADMIN: felt252 = 'c_only_admin';
    const INVALID_PRICE: felt252 = 'c_price_cant_be_zero';
    const REENTRANT_CALL: felt252 = 'c_reentrant_call';
    const CANT_MINT_ZERO: felt252 = 'c_cant_mint_zero';
    const CANT_REDEEM_ZERO: felt252 = 'c_cant_redeem_zero';
    const INSUFFICIENT_LIQUIDITY: felt252 = 'c_insufficient_liquidity';
    const SENDER_NOT_BORROWABLE: felt252 = 'c_sender_not_borrowable';
    const CANT_SEIZE_ZERO: felt252 = 'c_cant_seize_zero';
    const NOT_LIQUIDATABLE: felt252 = 'c_not_liquidatable';
    const INSUFFICIENT_CYG_LP_RECEIVED: felt252 = 'c_insufficient_cyg_lp';
}

mod BorrowableErrors {
    const BORROWER_ZERO_ADDRESS: felt252 = 'b_borrower_cant_be_zero';
    const BORROWER_COLLATERAL_ADDRESS: felt252 = 'b_borrower_cant_be_collateral';
    const INVALID_RANGE: felt252 = 'b_invalid_range';
    const ONLY_ADMIN: felt252 = 'b_only_admin';
    const INVALID_PRICE: felt252 = 'b_price_cant_be_zero';
    const REENTRANT_CALL: felt252 = 'b_reentrant_call';
    const CANT_MINT_ZERO: felt252 = 'b_cant_mint_zero';
    const CANT_REDEEM_ZERO: felt252 = 'b_cant_redeem_zero';
    const INSUFFICIENT_BALANCE: felt252 = 'b_insufficient_balance';
    const INSUFFICIENT_LIQUIDITY: felt252 = 'b_insufficient_liquidity';
    const INSUFFICIENT_USD_RECEIVED: felt252 = 'b_insufficient_usd_received';
}

