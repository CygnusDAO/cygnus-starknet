use starknet::ContractAddress;

#[starknet::interface]
trait ICygnusDAO<TState> {
    /// ──────────────────────────────────── ERC20 ───────────────────────────────────────────

    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;

    /// ──────────────────────────────────── CYG TOKEN ────────────────────────────────────────

    /// # Returns
    /// * The address of the owner
    fn owner(self: @TState) -> ContractAddress;

    /// The only address capable of minting CYG
    ///
    /// # Returns
    /// * The pillars of creation contract address
    fn pillars_of_creation(self: @TState) -> ContractAddress;

    /// We need this because CYG is a layer zero token on EVMs. Relying solely on `totalSupply`
    /// to cap the mints is problematic as bridging CYG across chains increases/decreases total supply 
    /// across chains. So instead of relying on totalSupply < CAP we update total_minted storage
    /// on each mint until total_minted = CAP
    ///
    /// # Returns
    /// The total amount of CYG that has been minted on this chain so far
    fn total_minted(self: @TState) -> u256;

    /// # Returns
    /// * The maximum number of CYG tokens that can be minted on this chain
    fn CAP(self: @TState) -> u256;

    /// Sets the pillars of creation contract which is the only address capable of minting CYG.
    /// Can only be set once!
    ///
    /// # Security
    /// * Only-owner
    ///
    /// # Arguments
    /// * `pillars` - The address of the pillars of creation contract
    fn set_pillars(ref self: TState, new_pillars: ContractAddress);

    /// Mints CYG into existence
    ///
    /// # Security
    /// * Only-pillars
    ///
    /// # Arguments
    /// * `to` - Receive of CYG
    /// * `amount` - The amount to mint
    fn mint(ref self: TState, to: ContractAddress, amount: u256);
}

#[starknet::contract]
mod CygnusDAO {
    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ══════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::ICygnusDAO;

    /// # Libraries
    use integer::BoundedInt;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ══════════════════════════════════════════════════════════════════════════════════════

    /// Event
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        PillarsOfCreationSet: PillarsOfCreationSet
    }

    /// Transfer
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256
    }

    /// Approval
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256
    }

    /// PillarsOfCreationSet
    #[derive(Drop, starknet::Event)]
    struct PillarsOfCreationSet {
        old_pillars: ContractAddress,
        new_pillars: ContractAddress
    }


    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Name of the token ("CygnusDAO")
        _name: felt252,
        /// Symbol of the token ("CYG")
        _symbol: felt252,
        /// Total supply of CYG on this chain (different from total_minted, see above)
        _total_supply: u256,
        /// Balances mapping
        _balances: LegacyMap<ContractAddress, u256>,
        /// Allowances mapping
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        /// Total minted (see above)
        _total_minted: u256,
        /// Address of the CYG minter
        _pillars: ContractAddress,
        /// Initial owner, useless after setting pillars
        _owner: ContractAddress
    }

    /// Maximum available CYG to be minted on Starknet
    const CAP: u256 = 2_500_000_000000000000000000; // 2.5 M

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(
        ref self: ContractState, name: felt252, symbol: felt252, owner: ContractAddress,
    ) {
        self.initializer(name, symbol);
        self._owner.write(owner);
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[external(v0)]
    impl CygnusDAOImpl of ICygnusDAO<ContractState> {
        /// ──────────────────────────────────── ERC20 ───────────────────────────────────────────

        /// # Implementation
        /// * ICygnusDAO
        fn name(self: @ContractState) -> felt252 {
            self._name.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn symbol(self: @ContractState) -> felt252 {
            self._symbol.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn decimals(self: @ContractState) -> u8 {
            18
        }

        /// # Implementation
        /// * ICygnusDAO
        fn total_supply(self: @ContractState) -> u256 {
            self._total_supply.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self._balances.read(account)
        }

        /// # Implementation
        /// * ICygnusDAO
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self._allowances.read((owner, spender))
        }

        /// # Implementation
        /// * ICygnusDAO
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * ICygnusDAO
        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * ICygnusDAO
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }

        /// ──────────────────────────────────── CYG TOKEN ────────────────────────────────────────

        /// Constant functions

        /// # Implementation
        /// * ICygnusDAO
        fn owner(self: @ContractState) -> ContractAddress {
            self._owner.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn CAP(self: @ContractState) -> u256 {
            CAP
        }

        /// # Implementation
        /// * ICygnusDAO
        fn total_minted(self: @ContractState) -> u256 {
            self._total_minted.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn pillars_of_creation(self: @ContractState) -> ContractAddress {
            self._pillars.read()
        }

        /// Non-constant functions

        /// Sets the only address capable of minting CYG into existence. 
        /// Can only be set once!
        ///
        /// # Security
        /// * Only-owner
        ///
        /// # Implementation
        /// * ICygnusDAO
        fn set_pillars(ref self: ContractState, new_pillars: ContractAddress) {
            /// # Error
            /// * `only_owner` - Reverts if caller is not owner
            let caller = get_caller_address();
            assert(caller == self._owner.read(), 'only_owner');

            /// # Error 
            /// * `pillars_already_set` - Reverts if pillars is not address zero
            let old_pillars = self._pillars.read();
            assert(old_pillars.is_zero(), 'pillars_already_set');

            /// Update storage
            self._pillars.write(new_pillars);

            /// # Event
            /// * `PillarsOfCreationSet`
            self.emit(PillarsOfCreationSet { old_pillars, new_pillars });
        }

        /// # Implementation
        /// * ICygnusDAO
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            /// # Error
            /// * `only_pillars` - Reverts if sender is not pillars contract
            assert(get_caller_address() == self._pillars.read(), 'only_pillars');

            /// Check total minted against cap, if below then update it
            let total_minted = self._total_minted.read() + amount;

            /// # Error
            /// * `above_cap` - Reverts if minting above cap
            assert(total_minted <= CAP, 'above_cap');

            /// Update total minted storage
            self._total_minted.write(total_minted);

            /// Mint `amount` to `to`
            self._mint(to, amount);
        }
    }

    #[external(v0)]
    fn increase_allowance(
        ref self: ContractState, spender: ContractAddress, added_value: u256
    ) -> bool {
        self._increase_allowance(spender, added_value)
    }

    #[external(v0)]
    fn increaseAllowance(
        ref self: ContractState, spender: ContractAddress, addedValue: u256
    ) -> bool {
        increase_allowance(ref self, spender, addedValue)
    }

    #[external(v0)]
    fn decrease_allowance(
        ref self: ContractState, spender: ContractAddress, subtracted_value: u256
    ) -> bool {
        self._decrease_allowance(spender, subtracted_value)
    }

    #[external(v0)]
    fn decreaseAllowance(
        ref self: ContractState, spender: ContractAddress, subtractedValue: u256
    ) -> bool {
        decrease_allowance(ref self, spender, subtractedValue)
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, name_: felt252, symbol_: felt252) {
            self._name.write(name_);
            self._symbol.write(symbol_);
        }

        fn _increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self._allowances.read((caller, spender)) + added_value);
            true
        }

        fn _decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            let caller = get_caller_address();
            self
                ._approve(
                    caller, spender, self._allowances.read((caller, spender)) - subtracted_value
                );
            true
        }

        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(!recipient.is_zero(), 'ERC20: mint to 0');
            self._total_supply.write(self._total_supply.read() + amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self._total_supply.write(self._total_supply.read() - amount);
            self._balances.write(account, self._balances.read(account) - amount);
            self.emit(Transfer { from: account, to: Zeroable::zero(), value: amount });
        }

        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(!owner.is_zero(), 'ERC20: approve from 0');
            assert(!spender.is_zero(), 'ERC20: approve to 0');
            self._allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self._balances.write(sender, self._balances.read(sender) - amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn _spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self._allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }
    }
}

