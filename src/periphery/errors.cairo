mod Errors {
    const CALLER_NOT_ADMIN: felt252 = 'caller_not_admin';
    const TRANSACTION_EXPIRED: felt252 = 'atx_expired';
    const SHUTTLE_NOT_DEPLOYED: felt252 = 'shuttle_not_deployed';
    const INSUFFICIENT_USD_RECEIVED: felt252 = 'insufficient_usd_received';
    const INSUFFICIENT_LIQUIDATED_USD: felt252 = 'insufficient_liquidated_usd';
    const CALLER_NOT_BORROWABLE: felt252 = 'caller_not_borrowable';
    const CALLER_NOT_COLLATERAL: felt252 = 'caller_not_collateral';
    const SENDER_NOT_ROUTER: felt252 = 'sender_not_router';
    const ALTAIR_EXTENSION_DOESNT_EXIST: felt252 = 'extension_doesnt_exist';
    const AVNU_SYSCALL_FAIL: felt252 = 'extension_avnu_call_fail';
    const FIBROUS_SYSCALL_FAIL: felt252 = 'extension_fibrous_call_fail';
}
