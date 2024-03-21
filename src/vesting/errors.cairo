/// Errors for `token_vesting.cairo`
mod Errors {
    const VESTING_SCHEDULE_IS_REVOKED: felt252 = 'vesting_schedule_revoked';
    const VESTING_TOKEN_CANT_BE_ZERO: felt252 = 'vesting_token_cant_be_zero';
    const CALLER_NOT_OWNER: felt252 = 'only_owner';
    const INDEX_OUT_OF_BOUNDS: felt252 = 'index_out_of_bounds';
    const REENTRANT_CALL: felt252 = 'reentrant_call';
    const INSUFFICIENT_FUNDS: felt252 = 'insufficient_funds';
    const CANT_VEST_ZERO: felt252 = 'cant_vest_zero';
    const SLICE_PERIODS_ZERO: felt252 = 'slice_periods_zero';
    const DURATION_BELOW_CLIFF: felt252 = 'duration_below_cliff';
}
