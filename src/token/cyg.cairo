use starknet::ContractAddress;

#[starknet::interface]
trait ICygnusDAO<T> {
    /// --------------------------------------------------------------------------------------------------------
    ///                                          1. ERC20
    /// --------------------------------------------------------------------------------------------------------

    /// # Returns
    /// * The name of the token ('CygnusDAO')
    fn name(self: @T) -> felt252;

    /// # Returns
    /// * The symbol of the token ('CYG')
    fn symbol(self: @T) -> felt252;

    /// # Returns
    /// * Decimals used (18)
    fn decimals(self: @T) -> u8;

    /// # Returns 
    /// * Total Supply of CYG on this chain. This is different than amount minted as amount minted refers
    ///   to the total minted on Starknet, this takes into account the whole supply
    fn total_supply(self: @T) -> u128;

    /// # Returns
    /// * The CYG balance for `account`
    fn balance_of(self: @T, account: ContractAddress) -> u128;

    /// # Returns
    /// * The allowance given from `owner` to `spender`
    fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u128;

    /// Transfer `amount` of CYG from msg.sender to `recipient`
    fn transfer(ref self: T, recipient: ContractAddress, amount: u128) -> bool;

    /// Transfer `amount` of CYG from `sender` to `recipient`
    fn transfer_from(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u128) -> bool;

    /// Gives the `spender` allowance over the sender's tokens
    fn approve(ref self: T, spender: ContractAddress, amount: u128) -> bool;

    /// --------------------------------------------------------------------------------------------------------
    ///                                          2. CYG TOKEN
    /// --------------------------------------------------------------------------------------------------------

    /// # Returns
    /// * The maximum number of CYG tokens that can be minted on this chain
    fn CAP(self: @T) -> u128;

    /// # Returns
    /// * The address of the owner
    fn owner(self: @T) -> ContractAddress;

    /// # Returns
    /// The total amount of CYG that has been minted on this chain so far (can't surpass CAP)
    fn total_minted(self: @T) -> u128;

    /// The only address capable of minting CYG
    ///
    /// # Returns
    /// * The pillars of creation contract address
    fn pillars_of_creation(self: @T) -> ContractAddress;

    /// Sets the pillars of creation contract which is the only address capable of minting CYG.
    /// Can only be set once!
    ///
    /// # Security
    /// * Only-owner
    /// * Only-once
    ///
    /// # Arguments
    /// * `pillars` - The address of the pillars of creation contract
    fn set_pillars(ref self: T, new_pillars: ContractAddress);

    /// Sets the L2 bridge to teleport CYG from mainnet to Starknet
    /// Can only be set once!
    ///
    /// # Security
    /// * Only-owner
    /// * Only-once
    ///
    /// # Arguments
    /// * `new_cyg_teleporter` - The bridge capable of teleporting CYG
    fn set_cyg_teleporter(ref self: T, new_cyg_teleporter: ContractAddress);

    /// Mints CYG into existence
    ///
    /// # Security
    /// * Only-pillars
    ///
    /// # Arguments
    /// * `to` - Receive of CYG
    /// * `amount` - The amount to mint
    fn mint(ref self: T, to: ContractAddress, amount: u128);

    fn teleport_mint(ref self: T, to: ContractAddress, amount: u128);
    fn teleport_burn(ref self: T, account: ContractAddress, amount: u128);
}

#[starknet::contract]
mod CygnusDAO {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::ICygnusDAO;

    /// # Libraries
    use integer::BoundedInt;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// Event
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        PillarsOfCreationSet: PillarsOfCreationSet,
        TeleporterSet: TeleporterSet,
        TeleportMint: TeleportMint,
        TeleportBurn: TeleportBurn
    }

    /// Transfer
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u128
    }

    /// Approval
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u128
    }

    /// PillarsOfCreationSet
    #[derive(Drop, starknet::Event)]
    struct PillarsOfCreationSet {
        old_pillars: ContractAddress,
        new_pillars: ContractAddress
    }

    /// TeleporterSet
    #[derive(Drop, starknet::Event)]
    struct TeleporterSet {
        old_cyg_teleporter: ContractAddress,
        new_cyg_teleporter: ContractAddress
    }

    /// TeleportMint
    #[derive(Drop, starknet::Event)]
    struct TeleportMint {
        to: ContractAddress,
        amount: u128
    }

    /// TeleportMint
    #[derive(Drop, starknet::Event)]
    struct TeleportBurn {
        account: ContractAddress,
        amount: u128
    }


    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Name of the token ("CygnusDAO")
        _name: felt252,
        /// Symbol of the token ("CYG")
        _symbol: felt252,
        /// Total supply of CYG on this chain (different from total_minted, see above)
        _total_supply: u128,
        /// Balances mapping
        _balances: LegacyMap<ContractAddress, u128>,
        /// Allowances mapping
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u128>,
        /// Total minted (see above)
        _total_minted: u128,
        /// Address of the CYG minter
        _pillars: ContractAddress,
        /// Initial owner, useless after setting pillars
        _owner: ContractAddress,
        /// CYG bridge on Starknet
        _teleporter: ContractAddress
    }

    /// Maximum available CYG to be minted on Starknet
    const CAP: u128 = 5_000000_000000000_000000000; // 5M

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, symbol: felt252, owner: ContractAddress,) {
        self.initializer(name, symbol);
        self._owner.write(owner);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl CygnusDAOImpl of ICygnusDAO<ContractState> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                          1. ERC20
        /// ---------------------------------------------------------------------------------------------------

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
        fn total_supply(self: @ContractState) -> u128 {
            self._total_supply.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn balance_of(self: @ContractState, account: ContractAddress) -> u128 {
            self._balances.read(account)
        }

        /// # Implementation
        /// * ICygnusDAO
        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u128 {
            self._allowances.read((owner, spender))
        }

        /// # Implementation
        /// * ICygnusDAO
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u128) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * ICygnusDAO
        fn transfer_from(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u128
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * ICygnusDAO
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                             CYG TOKEN
        /// ---------------------------------------------------------------------------------------------------

        /// Constant functions

        /// # Implementation
        /// * ICygnusDAO
        fn CAP(self: @ContractState) -> u128 {
            CAP
        }

        /// # Implementation
        /// * ICygnusDAO
        fn owner(self: @ContractState) -> ContractAddress {
            self._owner.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn total_minted(self: @ContractState) -> u128 {
            self._total_minted.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn pillars_of_creation(self: @ContractState) -> ContractAddress {
            self._pillars.read()
        }

        /// Non-constant functions

        /// # Security
        /// * Only-owner
        ///
        /// # Implementation
        /// * ICygnusDAO
        fn set_pillars(ref self: ContractState, new_pillars: ContractAddress) {
            /// # Error
            /// * `only_owner` - Reverts if caller is not owner
            assert(get_caller_address() == self._owner.read(), 'only_owner');

            /// Pillars up to now
            let old_pillars = self._pillars.read();

            /// # Error 
            /// * `pillars_already_set` - Reverts if pillars is not address zero
            assert(old_pillars.is_zero(), 'pillars_already_set');

            /// Update storage
            self._pillars.write(new_pillars);

            /// # Event
            /// * `PillarsOfCreationSet`
            self.emit(PillarsOfCreationSet { old_pillars, new_pillars });
        }

        /// # Security
        /// * Only-pillars
        ///
        /// # Implementation
        /// * ICygnusDAO
        fn mint(ref self: ContractState, to: ContractAddress, amount: u128) {
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

        /// ---------------------------------------------------------------------------------------------------
        ///                                  Ethereum Mainnet <> Starknet Bridge
        /// ---------------------------------------------------------------------------------------------------

        /// # Security
        /// * Only-owner
        ///
        /// # Implementation
        /// * ICygnusDAO
        fn set_cyg_teleporter(ref self: ContractState, new_cyg_teleporter: ContractAddress) {
            /// # Error
            /// * `only_owner` - Reverts if caller is not owner
            assert(get_caller_address() == self._owner.read(), 'only_owner');

            /// Teleporter up to now
            let old_cyg_teleporter = self._teleporter.read();

            /// # Error 
            /// * `teleporter_already_set` - Reverts if pillars is not address zero
            assert(old_cyg_teleporter.is_zero(), 'teleporter_already_set');

            /// Update storage
            self._teleporter.write(new_cyg_teleporter);

            /// # Event
            /// * `TeleporterSet`
            self.emit(TeleporterSet { old_cyg_teleporter, new_cyg_teleporter });
        }

        /// # Implementation
        /// * ICygnusDAO
        fn teleport_mint(ref self: ContractState, to: ContractAddress, amount: u128) {
            /// # Error
            /// * `only_teleporter` - Reverts if sender is not the CYG bridge
            assert(get_caller_address() == self._teleporter.read(), 'only_teleporter');

            /// Mint `amount` to `to` and emit `Transfer` event
            self._mint(to, amount);

            /// # Event
            /// * `TeleportMint`
            self.emit(TeleportMint { to, amount });
        }

        /// # Implementation
        /// * ICygnusDAO
        fn teleport_burn(ref self: ContractState, account: ContractAddress, amount: u128) {
            /// # Error
            /// * `only_teleporter` - Reverts if sender is not the CYG bridge
            assert(get_caller_address() == self._teleporter.read(), 'only_teleporter');

            /// Burn `amount` of tokens from `account`
            self._burn(account, amount);

            /// # Event
            /// * `TeleportBurn`
            self.emit(TeleportBurn { account, amount });
        }
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

        fn _increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self._allowances.read((caller, spender)) + added_value);
            true
        }

        fn _decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self._allowances.read((caller, spender)) - subtracted_value);
            true
        }

        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u128) {
            assert(!recipient.is_zero(), 'ERC20: mint to 0');
            self._total_supply.write(self._total_supply.read() + amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u128) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self._total_supply.write(self._total_supply.read() - amount);
            self._balances.write(account, self._balances.read(account) - amount);
            self.emit(Transfer { from: account, to: Zeroable::zero(), value: amount });
        }

        fn _approve(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u128) {
            assert(!owner.is_zero(), 'ERC20: approve from 0');
            assert(!spender.is_zero(), 'ERC20: approve to 0');
            self._allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn _transfer(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u128) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self._balances.write(sender, self._balances.read(sender) - amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn _spend_allowance(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u128) {
            let current_allowance = self._allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }
    }
}

