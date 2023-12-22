mod BorrowableErrors {
    const APPROVE_FROM_ZERO: felt252 = 'ERC20: approve from 0';
    const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
    const TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
    const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
    const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0';
    const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0';

    // Terminal
    const CALLER_NOT_ADMIN: felt252 = 'caller_not_admin';
    const CANT_MINT_ZERO: felt252 = 'cant_mint_zero';
    const CANT_REDEEM_ZERO: felt252 = 'cant_redeem_zero';

    // Control
    const INVALID_RANGE: felt252 = 'invalid_range';

    // BOrrowable
    const INSUFFICIENT_LIQUIDITY: felt252 = 'insufficient_liquidity';
    const INSUFFICIENT_USD_RECEIVED: felt252 = 'insufficient_usd_received';

    // Utils
    const REENTRANT_CALL: felt252 = 'reentrant_call';
}

mod CollateralErrors {
    // ERC20
    const APPROVE_FROM_ZERO: felt252 = 'ERC20: approve from 0';
    const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
    const TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
    const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
    const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0';
    const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0';
    // terminal
    const CALLER_NOT_ADMIN: felt252 = 'caller_not_admin';
    // CONTROL
    const BORROWABLE_ALREADY_SET: felt252 = 'borrowable_already_set';
    const REENTRANT_CALL: felt252 = 'reentrant_call';
    const CANT_MINT_ZERO: felt252 = 'cant_mint_zero';
    const CANT_REDEEM_ZERO: felt252 = 'cant_redeem_zero';

    // Control
    const INVALID_RANGE: felt252 = 'invalid_range';

    const BORROWER_ZERO_ADDRESS: felt252 = 'borrower_cant_be_zero';
    const BORROWER_COLLATERAL: felt252 = 'borrower_cant_be_collateral';
    const INVALID_PRICE: felt252 = 'price_cant_be_zero';

    const SENDER_NOT_BORROWABLE: felt252 = 'sender_not_borrowable';
    const CANT_SEIZE_ZERO: felt252 = 'cant_seize_zero';
    const NOT_LIQUIDATABLE: felt252 = 'not_liquidatable';

    const INSUFFICIENT_CYG_LP_RECEIVED: felt252 = 'insufficient_cyg_lp';
}
