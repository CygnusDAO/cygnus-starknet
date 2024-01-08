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
    fn totalSupply(self: @T) -> u128;

    /// # Returns
    /// * The CYG balance for `account`
    fn balance_of(self: @T, account: ContractAddress) -> u128;
    fn balanceOf(self: @T, account: ContractAddress) -> u128;

    /// # Returns
    /// * The allowance given from `owner` to `spender`
    fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u128;

    /// Transfer `amount` of CYG from msg.sender to `recipient`
    fn transfer(ref self: T, recipient: ContractAddress, amount: u128) -> bool;

    /// Transfer `amount` of CYG from `sender` to `recipient`
    fn transfer_from(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u128) -> bool;
    fn transferFrom(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u128) -> bool;

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

    /// Mints CYG into existence
    ///
    /// # Security
    /// * Only-pillars
    ///
    /// # Arguments
    /// * `to` - Receive of CYG
    /// * `amount` - The amount to mint
    fn mint(ref self: T, to: ContractAddress, amount: u128);

    /// ---------------------------------------------------------------------------------------------------
    ///                                  Ethereum Mainnet <> Starknet Bridge
    /// ---------------------------------------------------------------------------------------------------

    /// Address of CYG on mainnet
    ///
    /// # Returns
    /// * The address of the CYG token on Ethereum Mainnet
    fn cyg_token_mainnet(self: @T) -> felt252;

    /// Can only be set once!
    ///
    /// # Security
    /// * Only-owner
    /// * Only-once
    ///
    /// # Arguments
    /// * `new_cyg_mainnet` - The address of CYG on Ethereum Mainnet
    fn set_cyg_token_mainnet(ref self: T, new_cyg_mainnet: felt252);

    /// Teleports CYG from Starknet to Ethereum Mainnet
    ///
    /// # Arguments
    /// * `recipient` - The ETH address of the recipient
    /// * `amount` - The amount of CYG to bridge to Ethereum
    fn teleport(ref self: T, recipient: felt252, teleport_amount: u128);
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
    use starknet::{ContractAddress, send_message_to_l1_syscall, get_caller_address};

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
        NewTeleporter: NewTeleporter,
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

    /// NewTeleporter
    #[derive(Drop, starknet::Event)]
    struct NewTeleporter {
        old_cyg_mainnet: felt252,
        new_cyg_mainnet: felt252
    }

    /// TeleportMint
    #[derive(Drop, starknet::Event)]
    struct TeleportMint {
        recipient: ContractAddress,
        teleport_amount: u128
    }

    /// TeleportBurn
    #[derive(Drop, starknet::Event)]
    struct TeleportBurn {
        caller: ContractAddress,
        teleport_amount: u128
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
        /// CYG teleporter on Starknet
        cyg_token_mainnet: felt252
    }

    /// Maximum available CYG to be minted on Starknet
    const CAP: u128 = 5_000000_000000000_000000000; // 5M

    /// Max Ethereum address (uint160)
    const MAX_ETH_ADDRESS: u256 = 0x10000000000000000000000000000000000000000;

    // Payload to L1
    const PROCESS_WITHDRAWAL: felt252 = 1;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, symbol: felt252, owner: ContractAddress,) {
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
            'CygnusDAO'
        }

        /// # Implementation
        /// * ICygnusDAO
        fn symbol(self: @ContractState) -> felt252 {
            'CYG'
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
        fn totalSupply(self: @ContractState) -> u128 {
            self._total_supply.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn balance_of(self: @ContractState, account: ContractAddress) -> u128 {
            self._balances.read(account)
        }

        /// # Implementation
        /// * ICygnusDAO
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u128 {
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
        fn transferFrom(
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

        /// # Implementation
        /// * ICygnusDAO
        fn cyg_token_mainnet(self: @ContractState) -> felt252 {
            self.cyg_token_mainnet.read()
        }

        /// # Security
        /// * Only-owner
        ///
        /// # Implementation
        /// * ICygnusDAO
        fn set_cyg_token_mainnet(ref self: ContractState, new_cyg_mainnet: felt252) {
            /// # Error
            /// * `only_owner` - Reverts if caller is not owner
            assert(get_caller_address() == self._owner.read(), 'only_owner');

            /// Teleporter up to now
            let old_cyg_mainnet = self.cyg_token_mainnet.read();

            /// # Error 
            /// * `teleporter_already_set` - Reverts if teleporter is already set
            assert(old_cyg_mainnet.is_zero(), 'teleporter_already_set');

            /// Update storage
            self.cyg_token_mainnet.write(new_cyg_mainnet);

            /// # Event
            /// * `NewTeleporter`
            self.emit(NewTeleporter { old_cyg_mainnet, new_cyg_mainnet });
        }

        /// We set amount as a u128 as we are transferring from Starknet to Mainnet and converting
        /// it to felts
        ///
        /// # Implementation
        /// * ICygnusDAO
        fn teleport(ref self: ContractState, recipient: felt252, teleport_amount: u128) {
            /// Get caller to burn tokens from
            let caller = get_caller_address();

            /// # Error
            /// * `RECIPIENT_IS_ZERO`
            assert(!recipient.is_zero(), 'Bridge: L1 address cannot be 0');

            /// # Error
            /// * `INVALID_MAINNET_ADDRESS`
            assert(recipient.into() < MAX_ETH_ADDRESS, 'invalid_mainnet_address');

            /// Burn tokens from caller
            self._burn(caller, teleport_amount);

            /// Send message to L1
            let message: Array<felt252> = array![PROCESS_WITHDRAWAL, recipient, teleport_amount.into(), 0];
            send_message_to_l1_syscall(self.cyg_token_mainnet.read(), message.span());

            /// # Event
            /// * `TeleportBurn`
            self.emit(TeleportBurn { caller, teleport_amount });
        }
    }

    /// L1 Handler to handle teleports from Ethereum Mainnet to Starknet. Amount here is a u256 as we are transferring from
    /// Mainnet to Starknet. We check for u128 overflow.
    ///
    /// # Arguments
    /// * `from_address` - The ethereum address of the sender
    /// * `recipient` - The starknet address of the recipient of the CYG tokens
    /// * `amount` - The amount being bridged from mainnet to Starknet
    #[l1_handler]
    fn teleport_cyg_from_mainnet(
        ref self: ContractState, from_address: felt252, recipient: ContractAddress, amount: u256
    ) {
        /// # Error
        /// * `ONLY_TELEPORTER_ALLOWED` - Avoid if `from_address` is not the CYG L1 token
        assert(from_address == self.cyg_token_mainnet.read(), 'only_releporter');

        /// # Error
        /// * `U128_OVERFLOW`
        assert(amount.high.is_zero(), 'u128 overflow');

        /// Convert to u128
        let teleport_amount: u128 = amount.try_into().unwrap();

        /// Mint to recipient
        self._mint(recipient, teleport_amount);

        /// # Event
        /// * `TeleportMint`
        self.emit(TeleportMint { recipient, teleport_amount })
    }


    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
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

