use starknet::ContractAddress;

#[starknet::interface]
trait ICygnusDAO<TState> {
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

    /// CygnusDAO Token
    fn mint(ref self: TState, to: ContractAddress, amount: u256);
    fn pillars_of_creation(self: @TState) -> ContractAddress;
    fn total_minted(self: @TState) -> u256;
    fn CAP(self: @TState) -> u256;

    /// Owner
    fn set_pillars(ref self: TState, pillars: ContractAddress);
    fn owner(self: @TState) -> ContractAddress;
}

#[starknet::contract]
mod CygnusDAO {
    use integer::BoundedInt;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    use super::ICygnusDAO;

    const CAP: u256 = 2_500_000_000000000000000000; // 2.5 M

    #[storage]
    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _total_supply: u256,
        _balances: LegacyMap<ContractAddress, u256>,
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        _total_minted: u256,
        _pillars: ContractAddress,
        _owner: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, name: felt252, symbol: felt252, owner: ContractAddress,
    ) {
        self.initializer(name, symbol);
        self._owner.write(owner);
    }

    //
    // External
    //

    #[external(v0)]
    impl CygnusDAOImpl of ICygnusDAO<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            self._owner.read()
        }

        fn set_pillars(ref self: ContractState, pillars: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == self._owner.read(), 'only_owner');

            let current_pillars = self._pillars.read();
            assert(current_pillars.is_zero(), 'pillars_already_set');

            self._pillars.write(pillars);
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            /// Assert only pillars
            let caller = get_caller_address();
            assert(caller == self._pillars.read(), 'only_pillars');

            // Assert we are not passed cap
            let total_minted = self._total_minted.read() + amount;
            assert(total_minted <= CAP, 'above_cap');
            self._total_minted.write(total_minted);

            self._mint(to, amount);
        }

        fn pillars_of_creation(self: @ContractState) -> ContractAddress {
            self._pillars.read()
        }

        fn CAP(self: @ContractState) -> u256 {
            CAP
        }

        fn total_minted(self: @ContractState) -> u256 {
            self._total_minted.read()
        }

        fn name(self: @ContractState) -> felt252 {
            self._name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self._symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            18
        }

        fn total_supply(self: @ContractState) -> u256 {
            self._total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self._balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self._allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

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

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
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
