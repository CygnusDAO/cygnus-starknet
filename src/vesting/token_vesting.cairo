/// This is a Cairo implementation of https://github.com/AbdelStark/token-vesting-contracts/blob/main/src/TokenVesting.sol
/// Which is released as under the Apache-2.0 license.
use starknet::ContractAddress;
use cygnus::data::token_vesting::{VestingSchedule};

#[starknet::interface]
trait ITokenVesting<T> {
    /// # Returns
    /// * The address of the vested token
    fn get_token(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of the vester owner
    fn owner(self: @T) -> ContractAddress;

    /// # Returns
    /// * The current timestamp in seconds
    fn get_current_time(self: @T) -> u256;

    /// # Returns
    /// * The vesting schedule information for a given identifier.
    fn get_vesting_schedule(self: @T, vesting_schedule_id: felt252) -> VestingSchedule;

    /// # Returns
    /// * The amount of tokens that can be withdrawn by the owner.
    fn get_withdrawable_amount(self: @T) -> u256;

    /// # Returns
    /// * The vesting schedule id at the given index.
    fn get_vesting_id_at_index(self: @T, index: u32) -> felt252;

    /// # Returns
    /// * The amount of vesting tokens that can be released
    fn compute_releasable_amount(self: @T, vesting_schedule_id: felt252) -> u256;

    /// # Returns 
    /// * The number of vesting schedules managed by this contract.
    fn get_vesting_schedules_count(self: @T) -> u32;

    /// # Returns 
    /// * The total amount of vested tokens
    fn get_vesting_schedules_total_amount(self: @T) -> u256;

    /// # Returns
    /// * The last vesting schedule for a given holder address.
    fn get_last_vesting_schedule_for_holder(self: @T, holder: ContractAddress) -> VestingSchedule;

    /// # Returns 
    /// * The number of vesting schedules associated to a beneficiary.
    fn get_vesting_schedules_count_by_beneficiary(self: @T, beneficiary: ContractAddress) -> u32;

    /// # Returns
    /// * The next vesting schedule for a given holder address.
    fn compute_next_vesting_schedule_id_for_holder(self: @T, holder: ContractAddress) -> felt252;

    /// # Returns
    /// * The vesting schedule identifier for an address and an index.
    fn compute_vesting_schedule_id_for_address_and_index(self: @T, holder: ContractAddress, index: u32) -> felt252;

    fn create_vesting_schedule(
        ref self: T,
        beneficiary: ContractAddress,
        start: u256,
        cliff: u256,
        duration: u256,
        slice_period_seconds: u256,
        revocable: bool,
        amount: u256
    );

    /// # Security
    /// * Non-reentrant
    /// * Only-owner
    fn withdraw(ref self: T, amount: u256);
}

#[starknet::contract]
mod TokenVesting {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::ITokenVesting;
    use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

    /// # Imports
    use integer::BoundedInt;
    use poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use cygnus::data::token_vesting::{VestingSchedule};

    /// # Errors
    use cygnus::vesting::errors::Errors;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        owner: ContractAddress,
        token: IERC20Dispatcher,
        reentrant_guard: bool,
        /// Vesting schedule id's array
        vesting_schedule_ids: LegacyMap::<u32, felt252>,
        vesting_schedule_ids_length: u32,
        /// Vesting Schedules array
        vesting_schedules: LegacyMap::<felt252, VestingSchedule>,
        /// Vesting schedules total amount
        vesting_schedules_total_amount: u256,
        holders_vesting_count: LegacyMap::<ContractAddress, u32>
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, token: ContractAddress) {
        /// # Error
        /// * `VESTING_TOKEN_CANT_BE_ZERO` - Avoid not setting a vesting token
        assert(token.is_non_zero(), Errors::VESTING_TOKEN_CANT_BE_ZERO);

        /// Store admin
        self.owner.write(owner);

        /// Store vested token
        self.token.write(IERC20Dispatcher { contract_address: token });
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl TokenVestingImpl of ITokenVesting<ContractState> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                        CONSTANT FUNCTIONS
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ITokenVesting
        fn get_token(self: @ContractState) -> ContractAddress {
            self.token.read().contract_address
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_withdrawable_amount(self: @ContractState) -> u256 {
            /// Get the balance of token we own and the amount in vesting schedules
            let balance = self.token.read().balanceOf(get_contract_address());
            let vesting_schedules_amount = self.vesting_schedules_total_amount.read();

            balance - vesting_schedules_amount
        }

        /// # Implementation
        /// * ITokenVesting
        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_vesting_schedule(self: @ContractState, vesting_schedule_id: felt252) -> VestingSchedule {
            self.vesting_schedules.read(vesting_schedule_id)
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_vesting_schedules_total_amount(self: @ContractState) -> u256 {
            self.vesting_schedules_total_amount.read()
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_vesting_schedules_count_by_beneficiary(self: @ContractState, beneficiary: ContractAddress) -> u32 {
            self.holders_vesting_count.read(beneficiary)
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_vesting_id_at_index(self: @ContractState, index: u32) -> felt252 {
            /// # Error
            /// * `INDEX_OUT_OF_BOUNDS`
            assert(index < self.get_vesting_schedules_count(), Errors::INDEX_OUT_OF_BOUNDS);

            /// Get vesting schedule at `index`
            self.vesting_schedule_ids.read(index)
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_vesting_schedules_count(self: @ContractState) -> u32 {
            self.vesting_schedule_ids_length.read()
        }

        /// # Implementation
        /// * ITokenVesting
        fn compute_next_vesting_schedule_id_for_holder(self: @ContractState, holder: ContractAddress) -> felt252 {
            /// Get holder's total vesting counts
            let index = self.holders_vesting_count.read(holder);

            /// Return the next vesting ID for holder
            self.compute_vesting_schedule_id_for_address_and_index(holder, index)
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_last_vesting_schedule_for_holder(self: @ContractState, holder: ContractAddress) -> VestingSchedule {
            /// Get holder's total vesting counts - 1
            let index = self.holders_vesting_count.read(holder) - 1;

            /// Compute the vesting id for the holder at index 
            let vesting_schedule_id = self.compute_vesting_schedule_id_for_address_and_index(holder, index);

            /// Return the last vesting ID for holder
            self.vesting_schedules.read(vesting_schedule_id)
        }

        /// # Implementation
        /// * ITokenVesting
        fn compute_vesting_schedule_id_for_address_and_index(
            self: @ContractState, holder: ContractAddress, index: u32
        ) -> felt252 {
            /// We compute the Poseidon hash of the holder and index instead of the sn_keccak
            let arr: Array<felt252> = array![holder.into(), index.into()];

            poseidon_hash_span(arr.span())
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_current_time(self: @ContractState) -> u256 {
            /// Convert to u256 to follow `TokenVesting.sol` but maybe better to keep u64?
            get_block_timestamp().into()
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                      NON-CONSTANT FUNCTIONS
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ITokenVesting
        fn compute_releasable_amount(self: @ContractState, vesting_schedule_id: felt252) -> u256 {
            /// Check that vesting schedule is not revoked
            self._only_if_vesting_schedule_not_revoked(vesting_schedule_id);

            /// Get vesting scehdule struct 
            let vesting_schedule: VestingSchedule = self.vesting_schedules.read(vesting_schedule_id);

            /// Compute token amount that can be relased
            self._compute_releasable_amounts(vesting_schedule)
        }

        /// # Implementation
        /// * ITokenVesting
        fn withdraw(ref self: ContractState, amount: u256) {
            /// Reverts if caller is not the owner
            self._only_owner();

            /// Lock
            self._lock();

            /// # Error
            /// * `INSUFFICIENT_FUNDS` - Avoid if amount is more than withdrawable amount
            assert(self.get_withdrawable_amount() >= amount, Errors::INSUFFICIENT_FUNDS);

            /// Transfer `amount` to owner
            self.token.read().transfer(get_caller_address(), amount);
        }

        /// # Implementation
        /// * ITokenVesting
        fn create_vesting_schedule(
            ref self: ContractState,
            beneficiary: ContractAddress,
            start: u256,
            cliff: u256,
            duration: u256,
            slice_period_seconds: u256,
            revocable: bool,
            amount: u256
        ) {
            /// Check caller is owner of the vester
            self._only_owner();

            /// # Error
            /// * `INSUFFICIENT_FUNDS` - Avoid if amount is more than withdrawable
            assert(self.get_withdrawable_amount() >= amount, Errors::INSUFFICIENT_FUNDS);

            /// # Error
            /// * `CANT_VEST_ZERO` - Avoid vesting 0 tokens
            assert(amount > 0, Errors::CANT_VEST_ZERO);

            /// # Error
            /// * `SLICE_PERIODS_ZERO` - Must be at least 1 second
            assert(slice_period_seconds > 0, Errors::SLICE_PERIODS_ZERO);
            
            /// # Error
            /// * `DURATION_BELOW_CLIFF` - Duration must be gte cliff
            assert(duration >= cliff, Errors::DURATION_BELOW_CLIFF);

            let vesting_schedule_id = self.compute_next_vesting_schedule_id_for_holder(beneficiary);
            let cliff = start + cliff;
            let vesting_schedule = VestingSchedule {
                beneficiary,
                cliff,
                start,
                duration,
                slice_period_seconds,
                revocable,
                amount_total: amount,
                released: 0,
                revoked: false
            };

            /// Write to vesting schedules `array`
            self.vesting_schedules.write(vesting_schedule_id, vesting_schedule);

            /// Add total amount of vested tokens
            let vesting_schedules_amount = self.vesting_schedules_total_amount.read();
            self.vesting_schedules_total_amount.write(vesting_schedules_amount + amount);

            /// Add to vesting schedule IDs
            let ids_length = self.vesting_schedule_ids_length.read();
            self.vesting_schedule_ids.write(ids_length, vesting_schedule_id);
            self.vesting_schedule_ids_length.write(ids_length + 1);

            let current_vesting_count = self.holders_vesting_count.read(beneficiary);
            self.holders_vesting_count.write(beneficiary, current_vesting_count + 1);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Locks the contract preventing reentrancy
        fn _lock(ref self: ContractState) {
            /// # Error
            /// * `REENTRANT_CALL` - Reverts if already entered
            assert(!self.reentrant_guard.read(), Errors::REENTRANT_CALL);

            /// Lock
            self.reentrant_guard.write(true);
        }

        /// Unlocks the reentrancy guard
        fn _unlock(ref self: ContractState) {
            self.reentrant_guard.write(false)
        }

        /// Internal function to compute the amount of that can be relased according to its vesting schedule
        fn _compute_releasable_amounts(self: @ContractState, vesting_schedule: VestingSchedule) -> u256 {
            /// Current timestmap in seconds
            let current_time = self.get_current_time();

            /// If the current time is before the cliff, no tokens are releasable.
            if current_time < vesting_schedule.cliff || vesting_schedule.revoked {
                return 0;
            }

            // If the current time is after the vesting period, all tokens are releasable,
            // minus the amount already released.
            if current_time >= vesting_schedule.start + vesting_schedule.duration {
                return vesting_schedule.amount_total - vesting_schedule.released;
            }

            // Otherwise, some tokens are releasable.
            let time_from_start = current_time - vesting_schedule.start;
            let seconds_per_slice = vesting_schedule.slice_period_seconds;
            let vested_slice_periods = time_from_start / seconds_per_slice;
            let vested_seconds = vested_slice_periods * seconds_per_slice;
            let vested_amount = (vesting_schedule.amount_total * vested_seconds) / vesting_schedule.duration;

            vested_amount - vesting_schedule.released
        }

        /// Modifier function called before revoke, release and compute
        ///
        /// # Arguments
        /// * `vesting_schedule_id` - The ID of the vesting schedule
        fn _only_if_vesting_schedule_not_revoked(self: @ContractState, vesting_schedule_id: felt252) {
            /// Get vesting schedule
            let vesting_schedule = self.vesting_schedules.read(vesting_schedule_id);

            /// # Error
            /// * `VESTING_SCHEDULE_IS_REVOKED` - Reverts if the vesting schedule is revoked by the user
            assert(!vesting_schedule.revoked, Errors::VESTING_SCHEDULE_IS_REVOKED);
        }

        /// Modifier function called for owner only functions
        fn _only_owner(self: @ContractState) {
            /// # Error
            /// * `CALLER_NOT_OWNER` - Reverts if the caller is not the vester owner
            assert(get_caller_address() == self.owner.read(), Errors::CALLER_NOT_OWNER);
        }
    }
}
