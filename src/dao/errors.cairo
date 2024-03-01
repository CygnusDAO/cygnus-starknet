mod DAOReservesErrors {
    const ONLY_ADMIN: felt252 = 'dao_only_admin';
    const CALLER_NOT_HANGAR18: felt252 = 'dao_only_hangar18';
    const CYG_TOKEN_ALREADY_SET: felt252 = 'dao_cyg_already_set';
    const CANT_SWEEP_CYG: felt252 = 'dao_cant_sweep_cyg';
    const NOT_UNLOCKED_YET: felt252 = 'dao_not_unlocked_yet';
    const NOT_ENOUGH_CYG_IN_RESERVES: felt252 = 'dao_not_enough_cyg';
    const BORROWABLE_IS_ZERO: felt252 = 'dao_borrowable_is_zero';
}
