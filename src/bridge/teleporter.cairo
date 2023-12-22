use starknet::ContractAddress;

#[starknet::interface]
trait ITeleporter<T> {
    /// # Returns
    /// * The address of the CYG token on Starknet
    fn cyg_token(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of the CYG bridge on Ethereum as a felt
    fn ethereum_teleporter(self: @T) -> felt252;
}

#[starknet::contract]
mod CygnusDAO {
    /// -------------------------------------------------------------------------------------------------------
    ///     1. IMPORTS
    /// -------------------------------------------------------------------------------------------------------

    /// # Interfaces
    use super::ITeleporter;
    use cygnus::token::cyg::{ICygnusDAODispatcher, ICygnusDAODispatcherTrait};

    /// # Libraries
    use starknet::ContractAddress;

    /// -------------------------------------------------------------------------------------------------------
    ///     2. EVENTS
    /// -------------------------------------------------------------------------------------------------------

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        HandleTeleport: HandleTeleport,
        InitiateWithdrawal: InitiateWithdrawal
    }

    /// # Event
    /// * `HandleTeleport` - Emitted when deposit is handled from StarknetCore contract
    #[derive(Drop, starknet::Event)]
    struct HandleTeleport {
        from_address: felt252,
        recipient: ContractAddress,
        amount: u256
    }

    /// # Event
    /// * `InitiateWithdrawal` - Emitted when user emits a withdrawal of CYG
    #[derive(Drop, starknet::Event)]
    struct InitiateWithdrawal {
        recipient: felt252,
        value: u128
    }

    /// -------------------------------------------------------------------------------------------------------
    ///     3. STORAGE
    /// -------------------------------------------------------------------------------------------------------

    #[storage]
    struct Storage {
        ethereum_teleporter: felt252,
        cyg_token: ICygnusDAODispatcher
    }

    /// -------------------------------------------------------------------------------------------------------
    ///     3. STORAGE
    /// -------------------------------------------------------------------------------------------------------

    #[constructor]
    fn constructor(ref self: ContractState, teleporter: felt252, cyg_token: ICygnusDAODispatcher) {
        /// Store L1 Bridge as a felt252
        self.ethereum_teleporter.write(teleporter);

        /// Store the CYG token address on Starknet
        self.cyg_token.write(cyg_token);
    }

    /// -------------------------------------------------------------------------------------------------------
    ///     4. HANDLER
    /// -------------------------------------------------------------------------------------------------------

    /// L1 Handler deposit function. Followed impl from: https://book.cairo-lang.org/ch99-04-00-L1-L2-messaging.html
    ///
    /// # Arguments
    /// * `from_address` - Used to verify that we handle messages only from a trusted L1 source (ie. mainnet teleporter).
    /// * `recipient` - Recipient of CYG
    /// * `amount` - CYG Amount being bridged from Mainnet to Starknet
    #[l1_handler]
    fn handle_teleport(ref self: ContractState, from_address: felt252, recipient: ContractAddress, amount: u256) {
        /// # Error
        /// * `ONLY_TELEPORTER` - Avoid if depositor is not the l1 bridge
        assert(from_address == self.ethereum_teleporter.read(), 'ONLY_TELEPORTER');

        /// Teleport mint CYG token to recipient
        self.cyg_token.read().teleport_mint(recipient, amount.try_into().unwrap());

        /// # Event
        /// * `HandleTeleport`
        self.emit(HandleTeleport { from_address, recipient, amount });
    }

    /// -------------------------------------------------------------------------------------------------------
    ///     5. IMPLEMENTATION
    /// -------------------------------------------------------------------------------------------------------

    #[abi(embed_v0)]
    impl Teleporter of ITeleporter<ContractState> {
        /// # Implementation
        /// * ITeleporter
        fn ethereum_teleporter(self: @ContractState) -> felt252 {
            self.ethereum_teleporter.read()
        }

        /// # Implementation
        /// * ITeleporter
        fn cyg_token(self: @ContractState) -> ContractAddress {
            self.cyg_token.read().contract_address
        }
    }
}

