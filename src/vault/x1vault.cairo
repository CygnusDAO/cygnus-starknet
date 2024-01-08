use starknet::ContractAddress;
use array::ArrayTrait;
use cygnus::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::data::x1vault::{UserInfo};

/// Interface - Pillars Of Creation
#[starknet::interface]
trait IX1Vault<T> {
    /// ─────────────────────────────── CONSTANT FUNCTIONS ───────────────────────────────────

    /// # Returns
    /// * The name of the contract `Cygnus X1 Vault`
    fn name(self: @T) -> felt252;

    /// # Returns
    /// * The version of the vault deployed (to compare with other chains)
    fn version(self: @T) -> felt252;

    /// # Returns
    /// * The address of the hangar18 contract on Starknet
    fn hangar18(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of CYG on Starknet
    fn cyg_token(self: @T) -> ContractAddress;

    /// # Returns
    /// * The reward per share precision
    fn ACC_REWARD_PER_SHARE_PRECISION(self: @T) -> u256;

    /// # Returns
    /// * The maximum reward tokens allowed in the vault
    fn MAX_REWARD_TOKENS(self: @T) -> u32;

    /// # Returns
    /// * The maximum deposit fee allowed to be set by admin
    fn MAX_DEPOSIT_FEE(self: @T) -> u256;

    /// # Returns
    /// * The current deposit fee (prevents deposit spam before rewards are paid)
    fn deposit_fee(self: @T) -> u256;

    /// # Returns
    /// * The current balance of staked CYG
    fn cyg_staked_balance(self: @T) -> u256;

    /// # Returns
    /// * The total number of reward tokens that the vault pays rewards in
    fn reward_tokens_length(self: @T) -> u32;

    /// # Returns
    /// * The balance of a token in the vault
    fn vault_balance(self: @T, token: ContractAddress) -> u256;

    /// Gets the stored info given a user and a reward token
    ///
    /// # Arguments
    /// * `user` - The address of the user
    /// * `reward_token` - The address of the reward token
    ///
    /// # Returns
    /// * The stored data struct for `user` and `reward_token`
    fn get_user_info(self: @T, user: ContractAddress, reward_token: ContractAddress) -> UserInfo;

    /// Gets the pending reward of `reward_token` for `user`
    ///
    /// # Arguments
    /// * `user` - The address of the user
    /// * `reward_token` - The address of the reward token
    ///
    /// # Returns
    /// * The pending claimable reward for user of `reward_token`
    fn pending_reward(self: @T, user: ContractAddress, reward_token: ContractAddress) -> u256;

    /// ─────────────────────────────── NON-CONSTANT FUNCTIONS ───────────────────────────────

    /// Updates the reward_per_share for each token in the vault
    fn update_rewards_all(ref self: T);

    /// Updates the reward_per_share for `reward_token` with the latest accounting
    ///
    /// # Arguments
    /// * `reward_token` - The address of the reward token
    fn update_reward(ref self: T, reward_token: ContractAddress);

    /// Deposits CYG from caller into the X1 Vault
    ///
    /// # Arguments
    /// * `cyg_amount` - The amount of CYG to deposit.
    fn deposit(ref self: T, cyg_amount: u256);

    /// Withdraws CYG from the X1 Vault and sends to caller
    ///
    /// # Arguments
    /// * `cyg_amount` - The amount of CYG to withdraw.
    fn withdraw(ref self: T, cyg_amount: u256);

    /// ──────────── Admin ────────────

    /// Adds a reward token to the vault
    /// 
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `token` - The address of the token to add from the x1 vault
    fn add_reward_token(ref self: T, token: ContractAddress);

    /// Removes a reward token from the vault
    /// 
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `token` - The address of the token to remove from the x1 vault
    /// * `token_index` - The index of the reward token
    fn remove_reward_token(ref self: T, token: ContractAddress, token_index: u32);

    /// Sweeps a token from the vault
    /// 
    /// # Security
    /// * Only-admin
    /// * Can't withdraw reward token
    /// * Can't withdraw CYG
    ///
    /// # Arguments
    /// * `token` - The address of the token to sweep
    /// * `is_compatible` - Whether is erc20 compatible or not
    fn sweep_token(ref self: T, token: ContractAddress, is_compatible: bool);
}

#[starknet::contract]
mod X1Vault {
    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ══════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::IX1Vault;
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::token::erc20::cyg::{ICygnusDAODispatcher, ICygnusDAODispatcherTrait};
    use cygnus::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    /// # Libraries
    use cygnus::libraries::full_math_lib::FixedPointMathLib::FixedPointMathLibTrait;
    use starknet::{get_contract_address, ContractAddress, get_caller_address, get_block_timestamp};

    /// # Data
    use cygnus::data::x1vault::{UserInfo};

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ClaimReward: ClaimReward,
        Deposit: Deposit,
        Withdraw: Withdraw,
        SweepToken: SweepToken,
        NewRewardToken: NewRewardToken
    }

    /// ClaimReward
    #[derive(Drop, starknet::Event)]
    struct ClaimReward {
        token: ContractAddress,
        pending: u256
    }

    /// Deposit
    #[derive(Drop, starknet::Event)]
    struct Deposit {
        caller: ContractAddress,
        cyg_amount: u256
    }

    /// Withdraw
    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        caller: ContractAddress,
        cyg_amount: u256
    }

    /// SweepToken
    #[derive(Drop, starknet::Event)]
    struct SweepToken {
        caller: ContractAddress,
        token: ContractAddress,
        amount: u256
    }

    /// NewRewardToken
    #[derive(Drop, starknet::Event)]
    struct NewRewardToken {
        token: ContractAddress
    }


    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Address of the factory for admin only functions
        hangar18: IHangar18Dispatcher,
        /// Address of the CYG token
        cyg_token: ICygnusDAODispatcher,
        /// The current set deposit fee
        deposit_fee: u256,
        /// The current staked balance of CYG
        cyg_staked_balance: u256,
        /// Current length of tokens
        total_reward_tokens: u32,
        /// Array of all reward tokens
        all_reward_tokens: LegacyMap<u32, ContractAddress>,
        /// Whether a token is a reward token or not
        is_reward_token: LegacyMap<ContractAddress, bool>,
        /// Mapping of user address + reward token => UserInfo
        user_info: LegacyMap<(ContractAddress, ContractAddress), UserInfo>,
        /// Mapping of reward token => Reward per share
        acc_reward_per_share: LegacyMap<ContractAddress, u256>,
        /// Mapping of reward token => balance
        last_reward_balance: LegacyMap<ContractAddress, u256>,
        /// User cyg balance
        vault_shares: LegacyMap<ContractAddress, u256>
    }

    /// The accounting reward per share
    const ACC_PRECISION: u256 = 1_000000000_000000000_000000; // 1e24

    /// Max possible reward tokens that the vault can have
    const MAX_REWARD_TOKENS: u32 = 25;

    /// The maximum deposit fee set by admin
    const MAX_DEPOSIT_FEE: u256 = 50000000000000000; // 0.05e18 = 5%

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, hangar18: IHangar18Dispatcher, cyg_token: ICygnusDAODispatcher,) {
        self.hangar18.write(hangar18);
        self.cyg_token.write(cyg_token);
        self.deposit_fee.write(5000000000000000) // Default deposit fee of 0.5%
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[external(v0)]
    impl X1Vault of IX1Vault<ContractState> {
        /// ─────────────────────────────── CONSTANT FUNCTIONS ───────────────────────────────────

        /// # Implementation
        /// * IPillarsOfCreation
        fn name(self: @ContractState) -> felt252 {
            'Cygnus X1 Vault'
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn version(self: @ContractState) -> felt252 {
            '1.0.0'
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn cyg_token(self: @ContractState) -> ContractAddress {
            self.cyg_token.read().contract_address
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn ACC_REWARD_PER_SHARE_PRECISION(self: @ContractState) -> u256 {
            ACC_PRECISION
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn MAX_DEPOSIT_FEE(self: @ContractState) -> u256 {
            MAX_DEPOSIT_FEE
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn MAX_REWARD_TOKENS(self: @ContractState) -> u32 {
            MAX_REWARD_TOKENS
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn cyg_staked_balance(self: @ContractState) -> u256 {
            self.cyg_staked_balance.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn deposit_fee(self: @ContractState) -> u256 {
            self.deposit_fee.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn reward_tokens_length(self: @ContractState) -> u32 {
            self.total_reward_tokens.read()
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn vault_balance(self: @ContractState, token: ContractAddress) -> u256 {
            /// Check whether we are tracking this token or not
            let is_reward_token = self.is_reward_token.read(token);

            /// Return vault balance of token
            if is_reward_token {
                IERC20Dispatcher { contract_address: token }.balance_of(get_contract_address())
            } else {
                0
            }
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn get_user_info(self: @ContractState, user: ContractAddress, reward_token: ContractAddress) -> UserInfo {
            self.user_info.read((user, reward_token))
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn pending_reward(self: @ContractState, user: ContractAddress, reward_token: ContractAddress) -> u256 {
            /// Load CYG balance and user info for `reward_token`
            let user_shares = self.vault_shares.read(user);
            let user = self.user_info.read((user, reward_token));

            /// Gas savings
            let total_cyg = self.cyg_staked_balance.read();
            let token_balance = self.vault_balance(reward_token);
            let last_reward_balance = self.last_reward_balance.read(reward_token);

            /// Get latest stored reward per share
            let mut reward_per_share = self.acc_reward_per_share.read(reward_token);

            /// Check for last reward balance to calculate latest reward per share
            if (token_balance != last_reward_balance && total_cyg != 0) {
                let new_reward = token_balance - last_reward_balance;
                reward_per_share += new_reward.full_mul_div(ACC_PRECISION, total_cyg);
            }

            /// Return pending reward for user given their total shares and reward debt
            user_shares.full_mul_div(reward_per_share, ACC_PRECISION) - user.reward_debt
        }

        /// ─────────────────────────────── NON-CONSTANT FUNCTIONS ───────────────────────────────

        /// # Implementation
        /// * IPillarsOfCreation
        fn update_reward(ref self: ContractState, reward_token: ContractAddress) {
            /// # Error
            /// * not_reward_token
            assert(self.is_reward_token.read(reward_token), 'not_reward_token');

            /// Total staked CYG
            let total_cyg = self.cyg_staked_balance.read();

            /// Update reward internally
            self.update_reward_internal(total_cyg, reward_token);
        }

        /// # Implementation
        /// * IPillarsOfCreation
        fn update_rewards_all(ref self: ContractState) {
            /// Total staked CYG
            let total_cyg = self.cyg_staked_balance.read();

            /// Total reward tokens
            let vault_size = self.total_reward_tokens.read();

            /// Loop through token `array` and update reward
            let mut len = 0;
            loop {
                /// Escape
                if len == vault_size {
                    break;
                }

                /// Update reward internally
                self.update_reward_internal(total_cyg, self.all_reward_tokens.read(len));
                len += 1;
            }
        }

        /// We only allow the msg.sender to be the depositor for hte vault
        ///
        /// # Implementation
        /// * IPillarsOfCreation
        fn deposit(ref self: ContractState, cyg_amount: u256) {
            /// Only allow sender to be depositor
            let caller = get_caller_address();

            /// 1. Update the user CYG staking balance
            let deposit_fee = cyg_amount.mul_wad(self.deposit_fee.read());
            let final_amount = cyg_amount - deposit_fee;
            let previous_shares = self.vault_shares.read(caller);
            let new_shares = previous_shares + final_amount;
            self.vault_shares.write(caller, new_shares);

            /// 2. Get total reward tokens and loop through each one to update reward
            let total_cyg = self.cyg_staked_balance.read();
            let total_reward_tokens = self.total_reward_tokens.read();
            let mut len = 0;

            loop {
                /// Escape 
                if len == total_reward_tokens {
                    break;
                }

                /// Get reward token
                let token = self.all_reward_tokens.read(len);
                let mut user = self.user_info.read((caller, token));

                /// Update reward token
                self.update_reward_internal(total_cyg, token);

                /// User's reward debt for `token` up to now
                let previous_reward_debt = user.reward_debt;

                /// Gas savings
                let reward_per_share = self.acc_reward_per_share.read(token);

                /// 3. Check for pending rewards. If any, transfer rewards and then update user info.
                if previous_shares != 0 {
                    /// Calculate pending reward
                    /// The pending reward is calculated with the previous shares, allowing users
                    /// to deposit 0 and claiming the rewards. The new shares are stored at the end
                    /// of the function. The calculation for the pending rewards is the same as above:
                    ///
                    /// shares * acc_reward_per_share[token] / ACC_PRECISION - reward_debt[token]
                    let pending = previous_shares.full_mul_div(reward_per_share, ACC_PRECISION) - previous_reward_debt;

                    /// Safe transfer the token to caller
                    if pending == 0 {
                        self.safe_token_transfer(token, caller, pending);

                        /// # Event
                        /// * `ClaimReward`
                        self.emit(ClaimReward { token, pending });
                    }
                }

                /// Update user info mapping:
                /// caller + token => User
                user.reward_debt = new_shares.full_mul_div(reward_per_share, ACC_PRECISION);
                self.user_info.write((caller, token), user);

                len += 1;
            };

            /// 4. Update total CYG staked balance
            let cyg_staked_balance = self.cyg_staked_balance.read();
            self.cyg_staked_balance.write(cyg_staked_balance + final_amount);

            /// 5. If positive then transfer CYG from caller to this vault
            if final_amount != 0 {
                /// Check for deposit fee first and transfer to the DAO reserves if necessary
                if deposit_fee != 0 {
                    /// Get latest DAO Reserves contract from the factory
                    let dao_reserves = self.hangar18.read().dao_reserves();
                    self.cyg_token.read().transfer_from(caller, dao_reserves, deposit_fee);
                }

                /// Transfer CYG from sender to this vault
                self.cyg_token.read().transfer_from(caller, get_contract_address(), final_amount);
            }

            /// # Event
            /// * `Deposit`
            self.emit(Deposit { caller, cyg_amount });
        }

        /// We only allow the msg.sender to withdraw  their tokens
        ///
        /// # Implementation
        /// * IPillarsOfCreation
        fn withdraw(ref self: ContractState, cyg_amount: u256) {
            /// Only allow sender to withdraw their staking balance
            let caller = get_caller_address();

            /// 1. Update the user CYG staking balance
            let previous_shares = self.vault_shares.read(caller);

            /// # Error
            /// * `withdrawing_too_much`
            assert(cyg_amount <= previous_shares, 'withdrawing_too_much');

            /// Update user shares
            let new_shares = previous_shares - cyg_amount;
            self.vault_shares.write(caller, new_shares);

            /// 2. Get total reward tokens and loop through each one to update reward
            let total_cyg = self.cyg_staked_balance.read();
            let total_reward_tokens = self.total_reward_tokens.read();
            let mut len = 0;

            /// 3. Check for pending rewards. If any, transfer rewards and then update user info.
            if previous_shares != 0 {
                loop {
                    /// Escape 
                    if len == total_reward_tokens {
                        break;
                    }

                    /// Get reward token
                    let token = self.all_reward_tokens.read(len);
                    let mut user = self.user_info.read((caller, token));

                    /// Update reward token
                    self.update_reward_internal(total_cyg, token);

                    /// User's reward debt for `token` up to now
                    let previous_reward_debt = user.reward_debt;

                    /// Gas savings
                    let reward_per_share = self.acc_reward_per_share.read(token);

                    /// Calculate pending reward, same as `deposit`
                    ///
                    /// shares * acc_reward_per_share[token] / ACC_PRECISION - reward_debt[token]
                    let pending = previous_shares.full_mul_div(reward_per_share, ACC_PRECISION) - previous_reward_debt;

                    if pending == 0 {
                        /// Transfer reward to user
                        self.safe_token_transfer(token, caller, pending);

                        /// # Event
                        /// * `ClaimReward`
                        self.emit(ClaimReward { token, pending });
                    }

                    /// Update user info mapping:
                    /// caller + token => User
                    user.reward_debt = new_shares.full_mul_div(reward_per_share, ACC_PRECISION);
                    self.user_info.write((caller, token), user);

                    len += 1;
                }
            }

            /// 4. Update CYG staked balance
            let cyg_staked_balance = self.cyg_staked_balance.read();
            self.cyg_staked_balance.write(cyg_staked_balance - cyg_amount);

            /// 5. Transfer CYG from caller to this vault
            if cyg_amount != 0 {
                self.cyg_token.read().transfer(caller, cyg_amount);
            }

            /// # Event
            /// * `Withdraw`
            self.emit(Withdraw { caller, cyg_amount });
        }

        /// ----- admin ------

        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IPillarsOfCreation
        fn remove_reward_token(ref self: ContractState, token: ContractAddress, token_index: u32) {
            /// Check admin
            self.check_admin();

            /// # Error
            /// * `already-added`
            assert(self.is_reward_token.read(token), 'token_not_added');
        }

        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IPillarsOfCreation
        fn add_reward_token(ref self: ContractState, token: ContractAddress) {
            /// Check admin
            self.check_admin();

            /// # Error
            /// * `already-added`
            assert(!self.is_reward_token.read(token), 'already_added');

            /// Get total reward tokens up to now (for the ID in array)
            let total_reward_tokens = self.total_reward_tokens.read();

            /// # Error
            /// * `vault_max_capacity`
            assert(total_reward_tokens < MAX_REWARD_TOKENS, 'vault_max_capacity');

            /// # Error
            /// * `cant_add_zero`
            assert(!token.is_zero(), 'cant_add_zero');

            /// Add to "array"
            self.all_reward_tokens.write(total_reward_tokens, token);

            /// Increase reward token counter
            self.total_reward_tokens.write(total_reward_tokens + 1);

            /// Mark as true
            self.is_reward_token.write(token, true);

            /// Update reward for `token`
            self.update_reward_internal(self.cyg_staked_balance.read(), token);

            /// # Event
            /// * `NewRewardToken`
            self.emit(NewRewardToken { token });
        }

        /// We only allow the msg.sender to withdraw  their tokens
        ///
        /// # Security
        /// * Only-admin
        /// * Can't withdraw reward token
        /// * Can't withdraw CYG
        ///
        /// # Implementation
        /// * IPillarsOfCreation
        fn sweep_token(ref self: ContractState, token: ContractAddress, is_compatible: bool) {
            /// Check admin
            self.check_admin();

            /// # Error
            /// * `cant_sweep_reward`
            assert(!self.is_reward_token.read(token), 'cant_sweep_reward');

            /// # Error
            /// * `cant_sweep_cyg`
            assert(token != self.cyg_token.read().contract_address, 'cant_sweep_cyg');

            /// Get vault balance of token
            let amount = if is_compatible {
                IERC20Dispatcher { contract_address: token }.balance_of(get_contract_address())
            } else {
                IERC20Dispatcher { contract_address: token }.balance_of(get_contract_address())
            };

            /// If here then caller is admin
            let caller = get_caller_address();

            /// Send balance to caller (ie hangar18 admin)
            if amount > 0 {
                IERC20Dispatcher { contract_address: token }.transfer(caller, amount);
            }

            /// # Event
            /// * `SweepToken`
            self.emit(SweepToken { caller, token, amount });
        }
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Update the acc_reward_per_share for token internally
        ///
        /// # Arguments
        /// * `total_cyg` - The current total amount of staked CYG in the X1 Vault
        /// * `reward_token` - The address of the reward token we are updating
        fn update_reward_internal(ref self: ContractState, total_cyg: u256, reward_token: ContractAddress) {
            /// Escape for internal loop
            // if !self.is_reward_token.read(reward_token) {
            //     return;
            // }

            /// Current vault balance of `reward_token`
            let balance = self.vault_balance(reward_token);

            /// Stored vault balance of `reward_token`
            let last_reward_balance = self.last_reward_balance.read(reward_token);

            /// Already up to date
            if (balance == last_reward_balance || total_cyg == 0) {
                return;
            }

            /// Calculate the new reward per share for `reward_token`
            let new_reward = balance - last_reward_balance;
            let reward_per_share = self.acc_reward_per_share.read(reward_token);
            let new_reward_per_share = new_reward.full_mul_div(ACC_PRECISION, total_cyg);

            /// Update token reward per share and last token balance
            self.acc_reward_per_share.write(reward_token, reward_per_share + new_reward_per_share);
            self.last_reward_balance.write(reward_token, balance);
        }

        /// Safe token transfer function, just in case if rounding error causes pool to not have enough reward tokens
        ///
        /// # Arguments
        /// `token` - The address of the token to transfer
        /// `to` - The address that will receive `amount` of `rewardToken`
        /// `amount` - The amount to send to `to`
        fn safe_token_transfer(ref self: ContractState, token: ContractAddress, to: ContractAddress, amount: u256) {
            /// Get current and stored balance of `token`
            let token_balance = self.vault_balance(token);
            let last_reward_balance = self.last_reward_balance.read(token);
            if amount > token_balance {
                self.last_reward_balance.write(token, last_reward_balance - token_balance);
                IERC20Dispatcher { contract_address: token }.transfer(to, token_balance);
            } else {
                self.last_reward_balance.write(token, last_reward_balance - amount);
                IERC20Dispatcher { contract_address: token }.transfer(to, amount);
            }
        }

        /// # Security
        /// * Checks that caller is admin
        fn check_admin(self: @ContractState) {
            // Get admin address from the hangar18
            let admin = self.hangar18.read().admin();

            /// # Error
            /// * `ONLY_ADMIN` - Reverts if sender is not hangar18 admin 
            assert(get_caller_address() == admin, 'only_admin')
        }
    }
}
