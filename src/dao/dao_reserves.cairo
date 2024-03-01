//  SPDX-License-Identifier: AGPL-3.0-or-later
//
//  dao_reserves.cairo
//
//  Copyright (C) 2023 CygnusDAO
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════  
//   .              .            .               .      🛰️     .           .                .           .
//          █████████     🛰️      ---======*.                                                 .           ⠀
//         ███░░░░░███                                               📡                🌔                      . 
//        ███     ░░░  █████ ████  ███████ ████████   █████ ████  █████        ⠀
//       ░███         ░░███ ░███  ███░░███░░███░░███ ░░███ ░███  ███░░      .     .⠀           .           .
//       ░███          ░███ ░███ ░███ ░███ ░███ ░███  ░███ ░███ ░░█████       ⠀
//       ░░███     ███ ░███ ░███ ░███ ░███ ░███ ░███  ░███ ░███  ░░░░███              .             .⠀
//        ░░█████████  ░░███████ ░░███████ ████ █████ ░░████████ ██████     .----===*  ⠀
//         ░░░░░░░░░    ░░░░░███  ░░░░░███░░░░ ░░░░░   ░░░░░░░░ ░░░░░░            .                           .⠀
//                      ███ ░███  ███ ░███                .                 .                 .⠀
//       .             ░░██████  ░░██████        🛰️                        🛰️             .                 .     
//                      ░░░░░░    ░░░░░░      -------=========*                      .                     ⠀
//          .                            .       .          .            .                        .             .⠀
//       
//       DAO RESERVES - https://cygnusdao.finance                                                          .                     .
//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice This contract receives all reserves and fees (if applicable) from Core contracts.
//
//         From the borrowable, this contract receives the reserve rate from borrows in the form of CygUSD. Note
//         that the reserves are actually kept in CygUSD. The reserve rate is manually updatable at core contracts
//         by admin, it is by default set to 10% with the option to set between 0% to 20%.
//
//         From the collateral, this contract receives liquidation fees in the form of CygLP. The liquidation fee
//         is also an updatable parameter by admins, and can be set anywhere between 0% and 10%. It is by default
//         set to 1%. This means that when CygLP is seized from the borrower, an extra 1% of CygLP is taken also.
//
// @title  CygnusDAOReserves
// @author CygnusDAO
//
//                                             3.A. Harvest LP rewards
//                  +------------------------------------------------------------------------------+
//                  |                                                                              |
//                  |                                                                              ▼
//           +------------+                         +----------------------+            +--------------------+
//           |            |  3.B. Mint USD reserves |                      |            |                    |
//           |    CORE    |>----------------------► |     DAO RESERVES     |>---------► |      X1 VAULT      |
//           |            |                         |   (this contract)    |            |                    |
//           +------------+                         +----------------------+            +--------------------+
//              ▲      |                                                                      ▲         |
//              |      |    2. Track borrow/lend    +----------------------+                  |         |
//              |      +--------------------------► |     CYG REWARDER     |                  |         |  6. Claim LP rewards + USDC
//              |                                   +----------------------+                  |         |
//              |                                            ▲    |                           |         |
//              |                                            |    | 4. Claim CYG              |         |
//              |                                            |    |                           |         |
//              |                                            |    ▼                           |         |
//              |                                   +------------------------+                |         |
//              |    1. Deposit USDC / Liquidity    |                        |  5. Stake CYG  |         |
//              +-----------------------------------|    LENDERS/BORROWERS   |>---------------+         |
//                                                  |         ʕ•ᴥ•ʔ          |                          |
//                                                  +------------------------+                          |
//                                                             ▲                                        |
//                                                             |                                        |
//                                                             +----------------------------------------+
//                                                                       LP Rewards + USDC
//
//      Important: Main functionality of this contract is to split the reserves received to two main addresses:
//                 `daoReserves` and `cygnusX1Vault`
//
//                 This contract receives only CygUSD and CygLP (vault tokens of the Core contracts). The amount of
//                 assets received by the X1 Vault depends on the `x1VaultWeight` variable. Basically this contract
//                 redeems an amount of CygUSD shares for USDC and sends it to the vault so users can claim USD from
//                 reserves. The DAO receives the leftover shares which are NOT to be redeemed. These shares sit in
//                 the DAO reserves accruing interest (in the case of CygUSD) or earning from trading fees (in the
//                 case of CygLP).
//

/// # Title
/// * `CygnusDAOReserves`
///
/// # Description
/// * Where all DAO reserves go from the borrowable and collateral contracts
///
/// # Author
/// * CygnusDAO
use starknet::ContractAddress;
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::data::shuttle::{ShuttleDAOReserves};

/// # Interface
/// * `IDAOReserves`
#[starknet::interface]
trait ICygnusDAOReserves<T> {
    /// -------------------------------------------------------------------------------------------------------
    ///                                        CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// # Returns the name of the DAO reserves contract
    fn name(self: @T) -> felt252;

    /// # Returns the version of the DAO reserves contract
    fn version(self: @T) -> felt252;

    /// # Returns the cold address that holds DAO reserves in LPs and USDC according to the `dao_weight`
    fn cygnus_dao_safe(self: @T) -> ContractAddress;

    /// # Returns the CygnusX1 Vault address that sends this contract's LP and USDC reserves according to `x1_vault_weight`
    fn cygnus_x1_vault(self: @T) -> ContractAddress;

    /// # Returns the weight of reserves that gets sent to `cygnus_dao_safe`
    fn dao_weight(self: @T) -> u128;

    /// # Returns the weight of reserves that gets sent to `cygnus_x1_vault`
    fn x1_vault_weight(self: @T) -> u128;

    /// # Returns the address of the CYG token on Starknet
    fn cyg_token(self: @T) -> ContractAddress;

    /// # Returns the timestamp when CYG tokens get unlocked that get sent here
    fn dao_lock(self: @T) -> u64;

    /// # Returns the Address of USDC on Starknet
    fn usd(self: @T) -> ContractAddress;

    /// Address of the hangar18 factory on Starknet
    fn hangar18(self: @T) -> ContractAddress;

    /// Whether private banker is enabled or not
    fn private_banker(self: @T) -> bool;

    /// Mapping of shuttle_id => ShuttleDAOReserves struct
    fn all_shuttles(self: @T, shuttle_id: u32) -> ShuttleDAOReserves;

    /// # Returns the total shuttles stored in the DAO reserves contract
    fn all_shuttles_length(self: @T) -> u32;

    /// Quick view of our token balance of CYG
    fn cyg_token_balance(self: @T) -> u128;

    /// # Returns the pending x1 vault usd reserves
    fn pending_x1_vault_usd(self: @T) -> u128;

    /// -------------------------------------------------------------------------------------------------------
    ///                                      NON-CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// Redeems the USDC reserves accrued for `shuttle_id` and funds the X1 vault with USDC and funds the dao safe 
    /// with CygUSD according to the current x1_vault_weight
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    ///
    /// # Returns
    /// * The amount of USDC sent to the vault
    /// * The amount of CygUSD sent to the safe
    fn fund_x1_vault_usd(ref self: T, shuttle_id: u32) -> (u128, u128);

    /// # Redeems all reserves accrued across all lending pools and funds the x1 vault and dao safe
    ///
    /// # Returns
    /// * The amount of USDC sent to the vault
    /// * The amount of CygUSD sent to the safe
    fn fund_x1_vault_usd_all(ref self: T) -> (u128, u128);

    /// Sends the CygLP received for `shuttle_id` from the liquidation fees to the dao safe
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    ///
    /// # Returns
    /// * The amount of CygLP sent to the safe
    fn fund_safe_cyg_lp(ref self: T, shuttle_id: u32) -> u128;

    /// Sends all CygLP received from the liquidation fees to the dao safe
    ///
    /// # Returns
    /// * The amount of CygLP sent to the safe
    fn fund_safe_cyg_lp_all(ref self: T) -> u128;

    /// Adds shuttle to DAO reserves
    ///
    /// # Security
    /// * Only-Factory
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    /// * `borrowable` - The address of the borrowable contract for this lending pool
    /// * `collateral` - The address of the collateral contract for this lending pool
    fn add_shuttle(ref self: T, shuttle_id: u32, borrowable: IBorrowableDispatcher, collateral: ICollateralDispatcher);

    // Admin only //

    /// Admin sets a new weight for the x1 vault from all reserves
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_weight` - The new weight that is sent to the X1 vault from all collected reserves
    fn set_x1_vault_weight(ref self: T, new_weight: u128);

    /// Admin sweeps a token that was sent here by mistake (cant sweep CYG). Uses `amount` to aovid the whole
    /// balance_of/balanceOf and just use `transfer`
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments 
    /// * `token` - The address of the token
    /// * `amount` - The amount to sweep
    fn sweep_token(ref self: T, token: ContractAddress, amount: u256);

    /// Admin claims the CYG token
    ///
    /// # Security
    /// * Only-admin
    /// 
    /// # Arguments
    /// * `amount` - The amount of CYG to recover
    /// * `to` - The address to send the CYG to
    fn claim_cyg_token_dao(ref self: T, amount: u128, to: ContractAddress);

    /// Admin switches on/off the private banker feature, allowing anyone to fund the x1 vault
    ///
    /// # Security
    /// * Only-admin
    fn switch_private_banker(ref self: T);

    /// Admin sets the CYG token
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `cyg_token` - The address of the CYG token on Starknet
    fn set_cyg_token(ref self: T, cyg_token: ContractAddress);


    /// Set the safe to receive CygLP and CygUSD, never redeem assets unless emergency
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments 
    /// * `new_safe` - The address of the new safe
    fn set_cygnus_dao_safe(ref self: T, new_safe: ContractAddress);

    /// Admin sets a new X1 Vault
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments 
    /// * `new_vault` - The address of the x1 vault
    fn set_cygnus_x1_vault(ref self: T, new_vault: ContractAddress);
}

/// # Module
/// * `CygnusDAOReserves`
#[starknet::contract]
mod CygnusDAOReserves {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use super::ICygnusDAOReserves;

    /// # Imports
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

    /// # Cygnus Core
    use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use cygnus::data::shuttle::{ShuttleDAOReserves};
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use cygnus::libraries::full_math_lib::FullMathLib::FixedPointMathLibTrait;
    use cygnus::cyg::cygnusdao::{ICygnusDAODispatcher, ICygnusDAODispatcherTrait};

    /// # Errors
    use cygnus::dao::errors::DAOReservesErrors as Errors;

    /// # Events
    use cygnus::dao::events::DAOReservesEvents::{
        FundX1VaultUSD, FundX1VaultUSDAll, FundDAOSafeCygLP, FundDAOSafeCygLPAll, NewX1VaultWeight, CygTokenSet,
        PrivateBankerSwitch, CygTokenClaim, NewDAOSafe, NewX1Vault
    };

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        FundX1VaultUSD: FundX1VaultUSD,
        FundX1VaultUSDAll: FundX1VaultUSDAll,
        FundDAOSafeCygLP: FundDAOSafeCygLP,
        FundDAOSafeCygLPAll: FundDAOSafeCygLPAll,
        NewX1VaultWeight: NewX1VaultWeight,
        CygTokenSet: CygTokenSet,
        PrivateBankerSwitch: PrivateBankerSwitch,
        CygTokenClaim: CygTokenClaim,
        NewDAOSafe: NewDAOSafe,
        NewX1Vault: NewX1Vault
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        guard: bool,
        dao_lock: u64,
        all_shuttles_length: u32,
        all_shuttles: LegacyMap::<u32, ShuttleDAOReserves>,
        usd: IERC20Dispatcher,
        hangar18: IHangar18Dispatcher,
        cygnus_dao_safe: ContractAddress,
        cygnus_x1_vault: ContractAddress,
        dao_weight: u128,
        x1_vault_weight: u128,
        private_banker: bool,
        cyg_token: ContractAddress
    }

    /// For the DAO lock
    const NINETY_DAYS: u64 = 7776000;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, hangar18: IHangar18Dispatcher) {
        /// USDC on Starknet
        self.usd.write(IERC20Dispatcher { contract_address: hangar18.usd() });

        /// Factory
        self.hangar18.write(hangar18);

        /// CYG tokens sent here are locked for 90 days post deployment
        self.dao_lock.write(get_block_timestamp() + 7776000);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl CygnusDAOReservesImpl of ICygnusDAOReserves<ContractState> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                        CONSTANT FUNCTIONS
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICygnusDAOReserves
        fn name(self: @ContractState) -> felt252 {
            'Cygnus: DAO Reserves'
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn version(self: @ContractState) -> felt252 {
            '1.0.0'
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn cygnus_dao_safe(self: @ContractState) -> ContractAddress {
            self.cygnus_dao_safe.read()
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn cygnus_x1_vault(self: @ContractState) -> ContractAddress {
            self.cygnus_x1_vault.read()
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn usd(self: @ContractState) -> ContractAddress {
            self.usd.read().contract_address
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn x1_vault_weight(self: @ContractState) -> u128 {
            self.x1_vault_weight.read()
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn dao_weight(self: @ContractState) -> u128 {
            self.dao_weight.read()
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn cyg_token(self: @ContractState) -> ContractAddress {
            self.cyg_token.read()
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn dao_lock(self: @ContractState) -> u64 {
            self.dao_lock.read()
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn private_banker(self: @ContractState) -> bool {
            self.private_banker.read()
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn all_shuttles_length(self: @ContractState) -> u32 {
            self.all_shuttles_length.read()
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn all_shuttles(self: @ContractState, shuttle_id: u32) -> ShuttleDAOReserves {
            self.all_shuttles.read(shuttle_id)
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn cyg_token_balance(self: @ContractState) -> u128 {
            let cyg_token = ICygnusDAODispatcher { contract_address: self.cyg_token.read() };
            cyg_token.balanceOf(get_contract_address())
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn pending_x1_vault_usd(self: @ContractState) -> u128 {
            /// Get total lending pools added to the reserves contract
            let total_shuttles = self.all_shuttles_length.read();

            let mut length = 0;
            let mut usd = 0;

            /// The weight for the x1 vault
            let x1_vault_weight = self.x1_vault_weight.read();

            loop {
                /// Break clause
                if length == total_shuttles {
                    break;
                }

                /// Get shuttle at index `length`
                let shuttle = self.all_shuttles.read(length);

                /// Get our balance of CygUSD
                let cyg_usd_balance = shuttle.borrowable.balance_of(get_contract_address());

                /// The current exchange rate of CygUSD - USDC
                let exchange_rate = shuttle.borrowable.exchange_rate();

                /// Increase USD
                usd += cyg_usd_balance.mul_wad(exchange_rate).mul_wad(x1_vault_weight);

                length += 1;
            };

            usd
        }

        /// --------------------------------------------------------------------------------------------------------
        ///                                      NON-CONSTANT FUNCTIONS
        /// --------------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICygnusDAOReserves
        fn fund_x1_vault_usd(ref self: ContractState, shuttle_id: u32) -> (u128, u128) {
            /// If private banker is enabled, then caller must be hangar18 admin
            if (self.private_banker.read()) {
                self._check_admin();
            }

            /// Get borrowable for this shuttle id
            let borrowable = self.all_shuttles.read(shuttle_id).borrowable;

            /// Split between DAO and X1 Vault
            let (dao_shares, assets) = self
                ._redeem_and_fund_usd(
                    borrowable, self.x1_vault_weight.read(), self.cygnus_x1_vault.read(), self.cygnus_dao_safe.read()
                );

            /// # Event
            /// * `FundX1VaultUSD` - Log the transfer of USDC to the vault and CygUSD to the safe
            self.emit(FundX1VaultUSD { borrowable, dao_shares, assets });

            (dao_shares, assets)
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn fund_x1_vault_usd_all(ref self: ContractState) -> (u128, u128) {
            /// If private banker is enabled, then caller must be hangar18 admin
            if (self.private_banker.read()) {
                self._check_admin();
            }

            /// Get length of shuttles
            let total_shuttles = self.all_shuttles_length.read();

            /// Return variables of CygUSD shares and USDC assets
            let mut dao_shares = 0;
            let mut assets = 0;

            let mut index = 0;

            /// Savings
            let x1_vault_weight = self.x1_vault_weight.read();
            let cygnus_x1_vault = self.cygnus_x1_vault.read();
            let cygnus_dao_safe = self.cygnus_dao_safe.read();

            loop {
                /// Index
                if index == total_shuttles {
                    break;
                }

                /// Get borrowable  from stored shuttles
                let borrowable = self.all_shuttles.read(index).borrowable;

                /// Split between DAO and X1 Vault
                let (_dao_shares, _assets) = self
                    ._redeem_and_fund_usd(borrowable, x1_vault_weight, cygnus_x1_vault, cygnus_dao_safe);

                /// Accumulate shares and assets
                dao_shares += _dao_shares;
                assets += _assets;

                /// Increase index
                index += 1;
            };

            /// # Event
            /// * `FundX1VaultUSDAll` - Logs when we redeem all CygUSD and transfer to vault or dao
            self.emit(FundX1VaultUSDAll { total_shuttles, dao_shares, assets });

            (dao_shares, assets)
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn fund_safe_cyg_lp(ref self: ContractState, shuttle_id: u32) -> u128 {
            /// If private banker is enabled, then caller must be hangar18 admin
            if (self.private_banker.read()) {
                self._check_admin();
            }

            /// Get collateral for this shuttle id
            let collateral = self.all_shuttles.read(shuttle_id).collateral;

            /// Split between DAO and X1 Vault
            let dao_shares = self._fund_cyg_lp(collateral);

            /// # Event
            /// * `FundX1VaultUSD` - Log the transfer of USDC to the vault and CygUSD to the safe
            self.emit(FundDAOSafeCygLP { dao_shares });

            dao_shares
        }

        /// # Implementation
        /// * ICygnusDAOReserves
        fn fund_safe_cyg_lp_all(ref self: ContractState) -> u128 {
            /// If private banker is enabled, then caller must be hangar18 admin
            if (self.private_banker.read()) {
                self._check_admin();
            }

            /// Get length of shuttles
            let total_shuttles = self.all_shuttles_length.read();

            /// Return variable of CygLP shares
            let mut dao_shares = 0;

            let mut index = 0;

            loop {
                /// Index
                if index == total_shuttles {
                    break;
                }

                /// Get collateral from stored shuttles
                let collateral = self.all_shuttles.read(index).collateral;

                /// Fund CygLP to dao safe
                let _dao_shares = self._fund_cyg_lp(collateral);

                /// Accumulate CygLP shares
                dao_shares += _dao_shares;

                /// Increase index
                index += 1;
            };

            /// # Event
            /// * `FundDAOSafeCygLPAll` - Logs when we transfer all CygLP to the safe
            self.emit(FundDAOSafeCygLPAll { total_shuttles, dao_shares });

            dao_shares
        }

        /// # Security
        /// * Only-Hangar
        ///
        /// # Implementation
        /// * ICygnusDAOReserves
        fn add_shuttle(
            ref self: ContractState,
            shuttle_id: u32,
            borrowable: IBorrowableDispatcher,
            collateral: ICollateralDispatcher
        ) {
            /// # Error
            /// * Can only be called by hangar18 directly
            assert(get_caller_address() == self.hangar18.read().contract_address, Errors::CALLER_NOT_HANGAR18);

            /// Create quick view to store here
            let shuttle: ShuttleDAOReserves = ShuttleDAOReserves { shuttle_id, borrowable, collateral };

            /// Get length
            let total_shuttles = self.all_shuttles_length.read();

            /// Write to storage
            self.all_shuttles.write(total_shuttles, shuttle);

            /// Increase length
            self.all_shuttles_length.write(total_shuttles + 1);
        }

        /// # Security
        /// * Only-Admin
        ///
        /// # Implementation
        /// * ICygnusDAOReserves
        fn set_x1_vault_weight(ref self: ContractState, new_weight: u128) {
            /// Check admin
            self._check_admin();

            let old_weight = self.x1_vault_weight.read();

            self.x1_vault_weight.write(new_weight);
            self.dao_weight.write(1_000_000_000_000_000_000 - new_weight);

            /// # Event
            /// * NewX1VaultWeight
            self.emit(NewX1VaultWeight { old_weight, new_weight });
        }

        /// # Security
        /// * Only-Admin
        ///
        /// # Implementation
        /// * ICygnusDAOReserves
        fn set_cyg_token(ref self: ContractState, cyg_token: ContractAddress) {
            /// Check admin
            self._check_admin();

            /// # Error
            /// * Can only be set once
            assert(self.cyg_token.read().is_zero(), Errors::CYG_TOKEN_ALREADY_SET);

            /// Update
            self.cyg_token.write(cyg_token);

            /// # Event
            /// * CygTokenSet
            self.emit(CygTokenSet { cyg_token });
        }

        /// # Security
        /// * Only-Admin
        ///
        /// # Implementation
        /// * ICygnusDAOReserves
        fn sweep_token(ref self: ContractState, token: ContractAddress, amount: u256) {
            /// Check admin
            self._check_admin();

            /// # Error
            /// * Avoid sweeping CYG
            assert(token != self.cyg_token.read(), Errors::CANT_SWEEP_CYG);

            /// Transfer to caller
            if amount.is_non_zero() {
                IERC20Dispatcher { contract_address: token }.transfer(get_caller_address(), amount);
            }
        }

        /// # Security
        /// * Only-Admin
        ///
        /// # Implementation
        /// * ICygnusDAOReserves
        fn claim_cyg_token_dao(ref self: ContractState, amount: u128, to: ContractAddress) {
            /// Check admin
            self._check_admin();

            /// # Error
            /// * Make sure we are past the dao lock timestamp of 90 days
            assert(get_block_timestamp() > self.dao_lock.read(), Errors::NOT_UNLOCKED_YET);

            /// # Error
            /// * Make sure that we have enough CYG in contract
            assert(amount < self.cyg_token_balance(), Errors::NOT_ENOUGH_CYG_IN_RESERVES);

            ICygnusDAODispatcher { contract_address: self.cyg_token.read() }.transfer(to, amount);

            /// # Event
            /// * `CygTokenClaim` - Log when cyg token is claimed by admin
            self.emit(CygTokenClaim { amount, to });
        }

        /// # Security
        /// * Only-Admin
        ///
        /// # Implementation
        /// * ICygnusDAOReserves
        fn switch_private_banker(ref self: ContractState) {
            /// Check admin
            self._check_admin();

            /// Get private banker status and switch
            let private_banker = !self.private_banker.read();

            /// Update to storage
            self.private_banker.write(private_banker);

            /// # Event
            /// * `PrivateBankerSwitch` - Logs when the private banker is switch on/off
            self.emit(PrivateBankerSwitch { private_banker })
        }

        /// # Security
        /// * Only-Admin
        ///
        /// # Implementation
        /// * ICygnusDAOReserves
        fn set_cygnus_dao_safe(ref self: ContractState, new_safe: ContractAddress) {
            /// Check admin
            self._check_admin();

            /// Current safe
            let old_safe = self.cygnus_dao_safe.read();

            /// Update safe to storage
            self.cygnus_dao_safe.write(new_safe);

            /// # Event
            /// * `NewDAOSafe` - Logs when new safe is set for CygLP  and CygUSD
            self.emit(NewDAOSafe { old_safe, new_safe });
        }

        /// # Security
        /// * Only-Admin
        ///
        /// # Implementation
        /// * ICygnusDAOReserves
        fn set_cygnus_x1_vault(ref self: ContractState, new_vault: ContractAddress) {
            /// Check admin
            self._check_admin();

            /// Current vault
            let old_vault = self.cygnus_x1_vault.read();

            /// Update safe to storage
            self.cygnus_x1_vault.write(new_vault);

            /// # Event
            /// * `NewX1Vault` - Logs when new vault is set
            self.emit(NewX1Vault { old_vault, new_vault });
        }
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Hangar18 - Internal
    #[generate_trait]
    impl InternalDAOImpl of InternalDAOImplTrait {
        /// Redeems CygUSD for USDC according to the x1 vault weight and sends it to the x1 vault. The remaining
        /// CygUSD (which was not redeemed) is sent to the DAO safe
        ///
        /// # Arguments
        /// * `borrowable` - The address of the CygUSD
        /// * `x1_vault_weight` - The weight of the x1 vault
        /// * `cygnus_x1_vault` - The address of the x1 vault on Starknet
        /// * `cygnus_dao_safe` - The address of the dao safe
        ///
        /// # Returns
        /// * The amount of USDC sent to the x1 vault
        /// * The amount of CygUSD sent to the safe
        fn _redeem_and_fund_usd(
            ref self: ContractState,
            borrowable: IBorrowableDispatcher,
            x1_vault_weight: u128,
            cygnus_x1_vault: ContractAddress,
            cygnus_dao_safe: ContractAddress
        ) -> (u128, u128) {
            /// Avoid if zero
            if borrowable.contract_address.is_zero() {
                return (0, 0);
            }

            /// Force sync
            borrowable.sync();

            /// Our balance of CygUSD for this borrowable
            let total_shares = borrowable.balance_of(get_contract_address());

            /// Get shares for the X1 Vault
            let x1_vault_shares = total_shares.mul_wad(x1_vault_weight);

            /// Shares for the DAO
            let dao_shares = total_shares - x1_vault_shares;

            let mut assets = 0;

            /// Redeem shares to vault
            if (x1_vault_shares > 0) {
                assets = borrowable.redeem(x1_vault_shares, cygnus_x1_vault, get_contract_address());
            }
            /// Send leftover shares to DAO cold wallet
            if (dao_shares > 0) {
                borrowable.transfer(cygnus_dao_safe, dao_shares);
            }

            (dao_shares, assets)
        }

        /// Funds CygLP received from liquidation fees to the dao safe
        ///
        /// # Arguments
        /// * `collateral` - The address of the CygLP contract
        ///
        /// # Returns
        /// * The amount of CygLP sent to the dao safe
        fn _fund_cyg_lp(ref self: ContractState, collateral: ICollateralDispatcher) -> u128 {
            /// Escape if zero
            if collateral.contract_address.is_zero() {
                return (0);
            }

            /// Our balance of CygLP for this collateral
            let dao_shares: u128 = collateral.balance_of(get_contract_address());

            /// Send all LP shares to DAO cold wallet
            if (dao_shares > 0) {
                collateral.transfer(self.cygnus_dao_safe.read(), dao_shares);
            }

            dao_shares
        }
    }

    /// # Hangar18 - Internal
    #[generate_trait]
    impl InternalImpl of InternalImplTrait {
        /// Checks msg.sender is admin
        ///
        /// # Security
        /// * Checks that caller is admin
        #[inline(always)]
        fn _check_admin(self: @ContractState) {
            /// # Error
            /// * `ONLY_ADMIN` - Reverts if sender is not hangar18 admin 
            assert(get_caller_address() == self.hangar18.read().admin(), Errors::ONLY_ADMIN)
        }
    }
}
