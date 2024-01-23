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
    fn set_pillars_of_creation(ref self: T, new_pillars_of_creation: ContractAddress);

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
    /// # Security
    /// * Only-owner
    /// * Only-once
    ///
    /// # Returns
    /// * The address of the CYG token on Ethereum Mainnet
    fn cyg_token_mainnet(self: @T) -> felt252;

    /// Checks to see if user has a message to consume on Ethereum mainnet
    ///
    /// # Arguments
    /// * `recipient` - Recipient of the message
    ///
    /// # Returns
    /// * The amount of CYG the recipient has pending to be consumed on Ethereum
    fn pending_cyg_mainnet(self: @T, recipient: felt252) -> u128;

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
    fn teleport(ref self: T, recipient: felt252, amount: u128);
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

    /// # Errors
    use cygnus::cyg::errors::Errors::{
        ONLY_OWNER, PILLARS_ALREADY_SET, ABOVE_CAP, ONLY_PILLARS_OF_CREATION, CYG_MAINNET_ALREADY_SET,
        THE_SYSTEM_HAS_FAILED, RECIPIENT_CANT_BE_CYG, INVALID_ETHEREUM_ADDRESS, RECIPIENT_HAS_PENDING_L1_MESSAGE,
        INVALID_TELEPORTER, CRYSTALLINE_ENTOMBMENT, CANT_TELEPORT_ZERO, RECIPIENT_CANT_BE_TELEPORTER
    };

    /// # Events
    use cygnus::cyg::events::Events::{
        Transfer, Approval, PillarsOfCreationSet, CygMainnetSet, InitializeTeleport, TeleportFromEthereum,
        TeleportToEthereum
    };

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        PillarsOfCreationSet: PillarsOfCreationSet,
        CygMainnetSet: CygMainnetSet,
        InitializeTeleport: InitializeTeleport,
        TeleportFromEthereum: TeleportFromEthereum,
        TeleportToEthereum: TeleportToEthereum,
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Total supply of CYG on this chain (different from total_minted, see above)
        total_supply: u128,
        /// Balances mapping
        balances: LegacyMap<ContractAddress, u128>,
        /// Allowances mapping
        allowances: LegacyMap<(ContractAddress, ContractAddress), u128>,
        /// Total minted (see above)
        total_minted: u128,
        /// Address of the CYG minter
        pillars_of_creation: ContractAddress,
        /// Initial owner, useless after setting pillars
        owner: ContractAddress,
        /// CYG teleporter on Starknet
        cyg_token_mainnet: felt252,
        /// Has pending message
        pending_cyg_mainnet: LegacyMap<felt252, u128>,
    }

    /// Maximum available CYG to be minted on Starknet
    const CAP: u128 = 5_000000_000000000_000000000; // 5M

    /// Max Ethereum address (uint160)
    const MAX_ETH_ADDRESS: u256 = 0x10000000000000000000000000000000000000000;

    /// Teleport
    const T_T: felt252 = 6370215410494176513779785366845958513491968;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self._mint(owner, 250000_000000000000000000); // Mint the owner 250k CYG tokens, same as other chains
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
            self.total_supply.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn totalSupply(self: @ContractState) -> u128 {
            self.total_supply.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn balance_of(self: @ContractState, account: ContractAddress) -> u128 {
            self.balances.read(account)
        }

        /// # Implementation
        /// * ICygnusDAO
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u128 {
            self.balances.read(account)
        }


        /// # Implementation
        /// * ICygnusDAO
        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u128 {
            self.allowances.read((owner, spender))
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
            self.owner.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn total_minted(self: @ContractState) -> u128 {
            self.total_minted.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn pillars_of_creation(self: @ContractState) -> ContractAddress {
            self.pillars_of_creation.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn cyg_token_mainnet(self: @ContractState) -> felt252 {
            self.cyg_token_mainnet.read()
        }

        /// # Implementation
        /// * ICygnusDAO
        fn pending_cyg_mainnet(self: @ContractState, recipient: felt252) -> u128 {
            self.pending_cyg_mainnet.read(recipient)
        }

        /// Non-constant functions

        /// # Security
        /// * Only-owner
        ///
        /// # Implementation
        /// * ICygnusDAO
        fn set_pillars_of_creation(ref self: ContractState, new_pillars_of_creation: ContractAddress) {
            /// # Error
            /// * `ONLY_OWNER` - Reverts if caller is not owner
            assert(get_caller_address() == self.owner.read(), ONLY_OWNER);

            /// Pillars up to now
            let old_pillars_of_creation = self.pillars_of_creation.read();

            /// # Error 
            /// * `PILLARS_ALREADY_SET` - Reverts if pillars is not address zero
            assert(old_pillars_of_creation.is_zero(), PILLARS_ALREADY_SET);

            /// Update storage
            self.pillars_of_creation.write(new_pillars_of_creation);

            /// # Event
            /// * `PillarsOfCreationSet`
            self.emit(PillarsOfCreationSet { old_pillars_of_creation, new_pillars_of_creation });
        }

        /// # Security
        /// * Only-pillars
        ///
        /// # Implementation
        /// * ICygnusDAO
        fn mint(ref self: ContractState, to: ContractAddress, amount: u128) {
            /// # Error
            /// * `ONLY_PILLARS_OF_CREATION` - Reverts if sender is not pillars contract
            assert(get_caller_address() == self.pillars_of_creation.read(), ONLY_PILLARS_OF_CREATION);

            /// Check total minted against cap, if below then update it
            let total_minted = self.total_minted.read() + amount;

            /// # Error
            /// * `ABOVE_CAP` - Reverts if minting above cap
            assert(total_minted <= CAP, ABOVE_CAP);

            /// Update total minted storage
            self.total_minted.write(total_minted);

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
        fn set_cyg_token_mainnet(ref self: ContractState, new_cyg_mainnet: felt252) {
            /// # Error
            /// * `ONLY_OWNER` - Reverts if caller is not owner
            assert(get_caller_address() == self.owner.read(), ONLY_OWNER);

            /// Teleporter up to now
            let old_cyg_mainnet = self.cyg_token_mainnet.read();

            /// # Error 
            /// * `CYG_MAINNET_ALREADY_SET` - Reverts if teleporter is already set
            assert(old_cyg_mainnet.is_zero(), CYG_MAINNET_ALREADY_SET);

            /// Update storage
            self.cyg_token_mainnet.write(new_cyg_mainnet);

            /// # Event
            /// * `CygMainnetSet`
            self.emit(CygMainnetSet { old_cyg_mainnet, new_cyg_mainnet });
        }

        /// Initiates the teleporting of CYG from starknet to Mainnet
        ///
        /// # Implementation
        /// * ICygnusDAO
        fn teleport(ref self: ContractState, recipient: felt252, amount: u128) {
            /// # Error
            /// * `INVALID_ETHEREUM_ADDRESS`
            assert(recipient.is_non_zero() && recipient.into() < MAX_ETH_ADDRESS, INVALID_ETHEREUM_ADDRESS);

            /// # Error
            /// * `CANT_TELEPORT_ZERO`
            assert(amount.is_non_zero(), CANT_TELEPORT_ZERO);

            /// # Error
            /// * `RECIPIENT_HAS_PENDING_L1_MESSAGE`
            assert(self.pending_cyg_mainnet.read(recipient).is_zero(), RECIPIENT_HAS_PENDING_L1_MESSAGE);

            /// Get CYG token address on Ethereum
            let cyg_token_mainnet = self.cyg_token_mainnet.read();

            /// # Error
            /// * `RECIPIENT_CANT_BE_TELEPORTER`
            assert(recipient != cyg_token_mainnet, RECIPIENT_CANT_BE_TELEPORTER);

            /// Burn tokens from caller
            let caller = get_caller_address();
            self._burn(caller, amount);

            /// Send message to L1
            let message: Array<felt252> = array![T_T, recipient, amount.into()];

            match send_message_to_l1_syscall(cyg_token_mainnet, message.span()) {
                /// Update recipient pending message if success
                Result::Ok(()) => { self.pending_cyg_mainnet.write(recipient, amount) },
                /// # Error
                /// * `TheSystemHasFailed`
                Result::Err(err) => { panic_with_felt252(THE_SYSTEM_HAS_FAILED) }
            }

            /// # Event
            /// * `InitializeTeleport`
            self.emit(InitializeTeleport { caller, recipient, amount });
        }
    }

    /// L1 Handler to handle teleports from Ethereum Mainnet to Starknet.
    ///
    /// # Arguments
    /// * `from_address` - The ethereum address of the sender
    /// * `recipient` - The starknet address of the recipient of the CYG tokens
    /// * `amount` - The amount being bridged from mainnet to Starknet
    #[l1_handler]
    fn teleport_to_starknet(
        ref self: ContractState, from_address: felt252, t_t: felt252, recipient: ContractAddress, amount: u128
    ) {
        /// # Error
        /// * `INVALID_TELEPORTER` - Reverts if the message is not from the CYG token on mainnet
        assert(from_address == self.cyg_token_mainnet.read(), INVALID_TELEPORTER);

        // # Error
        // * `CRYSTALLINE_ENTOMBMENT`
        assert(t_t == T_T, CRYSTALLINE_ENTOMBMENT);

        /// Mint to recipient
        self._mint(recipient, amount);

        /// # Event
        /// * `TeleportFromEthereum`
        self.emit(TeleportFromEthereum { recipient, amount });
    }

    /// L1 Handler to handle teleports from Starknet to Ethereum Mainnet.
    ///
    /// # Arguments
    /// * `from_address` - The address on Ethereum where the message initiated
    /// * `recipient` - The address of the receiver of CYG on Ethereum
    /// * `amount` - The amount bridged from Starknet to Ethereum
    #[l1_handler]
    fn teleport_from_starknet(
        ref self: ContractState, from_address: felt252, t_t: felt252, recipient: ContractAddress, amount: u128
    ) {
        /// # Error
        /// * `INVALID_TELEPORTER` - Reverts if the message is not from the CYG token on mainnet
        assert(from_address == self.cyg_token_mainnet.read(), INVALID_TELEPORTER);

        // # Error
        // * `CRYSTALLINE_ENTOMBMENT`
        assert(t_t == T_T, CRYSTALLINE_ENTOMBMENT);

        /// Reset recipient slot
        self.pending_cyg_mainnet.write(recipient.into(), 0);

        /// # Event
        /// * `TeleportToEthereum`
        self.emit(TeleportToEthereum { recipient, amount });
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self.allowances.read((caller, spender)) + added_value);
            true
        }

        fn _decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self.allowances.read((caller, spender)) - subtracted_value);
            true
        }

        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u128) {
            assert(!recipient.is_zero(), 'ERC20: mint to 0');
            self.total_supply.write(self.total_supply.read() + amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u128) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self.total_supply.write(self.total_supply.read() - amount);
            self.balances.write(account, self.balances.read(account) - amount);
            self.emit(Transfer { from: account, to: Zeroable::zero(), value: amount });
        }

        fn _approve(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u128) {
            assert(!owner.is_zero(), 'ERC20: approve from 0');
            assert(!spender.is_zero(), 'ERC20: approve to 0');
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn _transfer(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u128) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self.balances.write(sender, self.balances.read(sender) - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn _spend_allowance(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u128) {
            let current_allowance = self.allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }
    }
}

