//! Deneb

// Libraries
use starknet::{ClassHash, ContractAddress};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};

/// Interface - Collateral Deployer
#[starknet::interface]
trait IDeneb<T> {
    /// # Returns
    /// * The class hash of the collateral contract this orbiter deploys
    fn collateral_class_hash(self: @T) -> ClassHash;

    /// Deploys the collateral contract with the borrowable address
    ///
    /// # Arguments
    /// * `underlying` - The address of the underlying LP
    /// * `borrowable` - The address of the borrowable
    /// * `oracle` - The address of the oracle for the underlying
    /// * `shuttle_id` - Unique lending pool ID (shared with borrowable)
    ///
    /// # Returns
    /// * The deployed collateral contract
    fn deploy_collateral(
        ref self: T,
        underlying: ContractAddress,
        borrowable: IBorrowableDispatcher,
        oracle: ContractAddress,
        shuttle_id: u32
    ) -> ICollateralDispatcher;
}

/// Module - Collateral Deployer
#[starknet::contract]
mod Deneb {
    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ══════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::IDeneb;
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};

    /// # Libraries
    use poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, ClassHash, get_caller_address, deploy_syscall};

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// The class hash of the collateral contract this orbiter deploys
        collateral_class_hash: ClassHash,
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, class_hash: ClassHash) {
        self.collateral_class_hash.write(class_hash);
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[external(v0)]
    impl DenebImpl of IDeneb<ContractState> {
        /// # Implementation
        /// * IDeneb
        fn collateral_class_hash(self: @ContractState) -> ClassHash {
            self.collateral_class_hash.read()
        }

        /// # Implementation
        /// * IDeneb
        fn deploy_collateral(
            ref self: ContractState,
            underlying: ContractAddress,
            borrowable: IBorrowableDispatcher,
            oracle: ContractAddress,
            shuttle_id: u32
        ) -> ICollateralDispatcher {
            // Get caller address (this should be the factory, but it's callable by anyone)
            let factory = get_caller_address();

            // 1. The class hash for the syscall
            let class = self.collateral_class_hash.read();

            // 2. Salt of collateral is always: [lp_token, hangar18]
            let salt = self.collateral_salt(underlying, factory);

            // 3. Build constructor arguments
            let calldata = self.c_calldata(factory, underlying, borrowable, oracle, shuttle_id);

            // 4. Deploy collateral
            let (contract_address, _) = deploy_syscall(class, salt, calldata, false).unwrap();

            // Return new collateral address
            ICollateralDispatcher { contract_address }
        }
    }

    /// ══════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ══════════════════════════════════════════════════════════════════════════════════════

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// The salt for deploying a new `Borrowable`
        ///
        /// # Arguments
        /// * `underlying` - The address of the underlying LP
        /// * `sender` - The address of the msg.sender
        ///
        /// # Returns
        /// * The salt used to deploy the collateral
        fn collateral_salt(
            self: @ContractState, underlying: ContractAddress, sender: ContractAddress,
        ) -> felt252 {
            /// Build salt for collateral with the arguments
            let mut data = array![];

            data.append('CYGNUS_COLLATERAL');
            data.append(underlying.into());
            data.append(sender.into());

            // https://docs.starknet.io/documentation/architecture_and_concepts/Cryptography/hash-functions/
            poseidon_hash_span(data.span())
        }

        /// The constructor arguments for the collateral
        ///
        /// # Arguments
        /// * `factory` - The address of hangar18
        /// * `underlying` - The address of the underlying stablecoin
        /// * `borrowable` - The address of the borrowable contract
        /// * `oracle` - The address of the oracle for the collateral and collateral
        /// * `shuttle_id` - Unique lending pool ID, shared by the collateral
        ///
        /// # Returns
        /// * The spanned constructor arguments of the collateral
        fn c_calldata(
            self: @ContractState,
            factory: ContractAddress,
            underlying: ContractAddress,
            borrowable: IBorrowableDispatcher,
            oracle: ContractAddress,
            shuttle_id: u32
        ) -> Span<felt252> {
            // Build constructor arguments
            let mut constructor_calldata = array![];

            constructor_calldata.append(factory.into());
            constructor_calldata.append(underlying.into());
            constructor_calldata.append(borrowable.contract_address.into());
            constructor_calldata.append(oracle.into());
            constructor_calldata.append(shuttle_id.into());

            constructor_calldata.span()
        }
    }
}
