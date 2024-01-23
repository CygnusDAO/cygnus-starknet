mod Errors {
    const ONLY_OWNER: felt252 = 'only_owner';
    const PILLARS_ALREADY_SET: felt252 = 'pillars_already_set';
    const ONLY_PILLARS_OF_CREATION: felt252 = 'caller_not_pillars';
    const ABOVE_CAP: felt252 = 'above_cap';
    const CYG_MAINNET_ALREADY_SET: felt252 = 'cyg_mainnet_already_set';
    const THE_SYSTEM_HAS_FAILED: felt252 = 'the_system_has_failed';
    const RECIPIENT_HAS_PENDING_L1_MESSAGE: felt252 = 'recipient_has_pending_l1_msg';
    const INVALID_ETHEREUM_ADDRESS: felt252 = 'invalid_ethereum_address';
    const RECIPIENT_CANT_BE_CYG: felt252 = 'recipient_cant_be_cyg';
    const INVALID_TELEPORTER: felt252 = 'caller_not_ethereum_cyg';
    const CRYSTALLINE_ENTOMBMENT: felt252 = 'crystalline_entombment';
    const RECIPIENT_CANT_BE_TELEPORTER: felt252 = 'recipient_cant_be_cyg';
    const CANT_TELEPORT_ZERO: felt252 = 'cant_teleport_zero';
}
