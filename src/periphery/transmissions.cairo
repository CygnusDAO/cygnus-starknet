//  SPDX-License-Identifier: AGPL-3.0-or-later
//
//  transmissions.cairo
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
//       CORE TRANSMISSIONS - https://cygnusdao.finance                                                          .                     .
//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════

// Contract to quickly view user stored positions from core

// Libraries
use starknet::ContractAddress;
use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};

/// # Data
use cygnus::data::{
    shuttle::{Shuttle}, calldata::{LeverageCalldata, DeleverageCalldata, Aggregator},
    altair::{ShuttleInfoC, ShuttleInfoB, BorrowerPosition, LenderPosition, ShuttlePositions}
};

/// # Interface - Transmissions
#[starknet::interface]
trait ITransmissions<T> {
    /// -------------------------------------------------------------------------------------------------------
    ///                                        QUICK USER POSITIONS
    /// -------------------------------------------------------------------------------------------------------

    /// # Returns
    /// * Name of the contract (`Transmissions`)
    fn name(self: @T) -> felt252;

    /// # Returns
    /// * The version of this transmitter
    fn version(self: @T) -> felt252;

    /// These functions are for reporting purposes only, they serve no value to the router itself.

    /// # Arguments
    /// * `shuttle_id` - The ID of the shuttle
    ///
    /// # Returns
    /// * The Collateral shuttle struct for `shuttle_id`
    /// * The Borrowable shuttle struct for `shuttle_id`
    fn get_shuttle_info_by_id(self: @T, hangar18: IHangar18Dispatcher, shuttle_id: u32) -> (ShuttleInfoC, ShuttleInfoB);

    /// # Arguments
    /// * `shuttle_id` - The ID of the shuttle
    /// * `borrower` - The address of the borrower
    ///
    /// # Returns
    /// * The Borrower position struct
    fn latest_borrower_position(
        self: @T, hangar18: IHangar18Dispatcher, shuttle_id: u32, borrower: ContractAddress
    ) -> BorrowerPosition;

    /// The user's borrow positions for all pools
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    ///
    /// # Returns
    /// * The principal, borrow balance and USD position for all collaterals
    fn latest_borrower_position_all(
        self: @T, hangar18: IHangar18Dispatcher, borrower: ContractAddress
    ) -> (u128, u128, u128);

    /// # Arguments
    /// * `shuttle_id` - The ID of the shuttle
    /// * `lender` - The address of the lender
    ///
    /// # Returns
    /// * The Lender position struct
    fn latest_lender_position(
        self: @T, hangar18: IHangar18Dispatcher, shuttle_id: u32, lender: ContractAddress
    ) -> LenderPosition;

    /// The user's lending positions for all pools
    ///
    /// # Arguments
    /// * `lender` - The address of the lender
    ///
    /// # Returns
    /// * The cyg_usd balance, usdc balance and position in USD for all borrowables
    fn latest_lender_position_all(
        self: @T, hangar18: IHangar18Dispatcher, lender: ContractAddress
    ) -> (u128, u128, u128);

    /// Gets the shuttle's total borrowers addresses
    fn get_shuttle_borrowers(self: @T, hangar18: IHangar18Dispatcher, shuttle_id: u32) -> Array<ContractAddress>;
    fn get_shuttle_positions(self: @T, hangar18: IHangar18Dispatcher, shuttle_id: u32) -> Array<ShuttlePositions>;
    fn get_shuttles_borrowers_positions(
        self: @T, hangar18: IHangar18Dispatcher, shuttle_id: u32, borrowers: Array<ContractAddress>
    ) -> Array<ShuttlePositions>;
}

/// # Module - Transmissions
#[starknet::contract]
mod Transmissions {
    /// -------------------------------------------------------------------------------------------------------
    ///     1. IMPORTS
    /// -------------------------------------------------------------------------------------------------------

    /// # Interfaces
    use super::ITransmissions;
    use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, get_block_timestamp, contract_address_const,
        call_contract_syscall
    };

    /// # Data
    use cygnus::data::{
        shuttle::{Shuttle}, calldata::{LeverageCalldata, DeleverageCalldata, Aggregator},
        altair::{ShuttleInfoC, ShuttleInfoB, BorrowerPosition, LenderPosition, ShuttlePositions}
    };


    #[storage]
    struct Storage {}

    /// -------------------------------------------------------------------------------------------------------
    ///     5. IMPLEMENTATION
    /// -------------------------------------------------------------------------------------------------------

    #[abi(embed_v0)]
    impl AltairImpl of ITransmissions<ContractState> {
        /// # Implementation
        /// * ITransmissions
        fn name(self: @ContractState) -> felt252 {
            'Cygnus: Transmissions'
        }

        /// # Implementation
        /// * ITransmissions
        fn version(self: @ContractState) -> felt252 {
            '1.0.0'
        }

        /// Useful for testing

        /// # Implementation
        /// * ITransmissions
        fn latest_borrower_position(
            self: @ContractState, hangar18: IHangar18Dispatcher, shuttle_id: u32, borrower: ContractAddress
        ) -> BorrowerPosition {
            let shuttle = hangar18.all_shuttles(shuttle_id);
            let (position_lp, position_usd, health) = shuttle.collateral.get_borrower_position(borrower);
            let cyg_lp_balance = shuttle.collateral.balance_of(borrower);
            let (principal, borrow_balance) = shuttle.borrowable.get_borrow_balance(borrower);
            let lp_token_price = shuttle.collateral.get_lp_token_price();
            let (liquidity, shortfall) = shuttle.collateral.get_account_liquidity(borrower);
            let exchange_rate = shuttle.collateral.exchange_rate();

            BorrowerPosition {
                shuttle_id,
                position_lp,
                position_usd,
                health,
                cyg_lp_balance,
                borrow_balance,
                principal,
                lp_token_price,
                liquidity,
                shortfall,
                exchange_rate
            }
        }

        /// # Implementation
        /// * ITransmissions
        fn latest_borrower_position_all(
            self: @ContractState, hangar18: IHangar18Dispatcher, borrower: ContractAddress
        ) -> (u128, u128, u128) {
            /// Get length of shuttles deployed
            let total_shuttles = hangar18.total_shuttles_deployed();

            /// Accumulators
            let mut principal = 0;
            let mut borrow_balance = 0;
            let mut position_usd = 0;

            /// Break case
            let mut len = 0;

            loop {
                if len == total_shuttles {
                    break;
                }

                /// Get shuttle for this ID
                let shuttle = hangar18.all_shuttles(len);

                /// Principal and borrow balance (ie. owed amount)
                let (_principal, _borrow_balance) = shuttle.borrowable.get_borrow_balance(borrower);

                /// The collateral's position in USD
                let (_, _position_usd, _) = shuttle.collateral.get_borrower_position(borrower);

                principal += _principal;
                borrow_balance += _borrow_balance;
                position_usd += _position_usd;
                len += 1;
            };

            (principal, borrow_balance, position_usd)
        }

        /// # Implementation
        /// * ITransmissions
        fn latest_lender_position(
            self: @ContractState, hangar18: IHangar18Dispatcher, shuttle_id: u32, lender: ContractAddress
        ) -> LenderPosition {
            let shuttle = hangar18.all_shuttles(shuttle_id);
            let (cyg_usd_balance, position_usdc, position_usd) = shuttle.borrowable.get_lender_position(lender);
            let usd_price = shuttle.borrowable.get_usd_price();
            let exchange_rate = shuttle.borrowable.exchange_rate();
            LenderPosition { shuttle_id, cyg_usd_balance, position_usdc, position_usd, usd_price, exchange_rate }
        }

        /// # Implementation
        /// * ITransmissions
        fn latest_lender_position_all(
            self: @ContractState, hangar18: IHangar18Dispatcher, lender: ContractAddress
        ) -> (u128, u128, u128) {
            /// Get length of shuttles deployed
            let total_shuttles = hangar18.total_shuttles_deployed();

            /// Accumulators
            let mut cyg_usd_balance = 0;
            let mut position_usdc = 0;
            let mut position_usd = 0;

            /// Break case
            let mut len = 0;

            loop {
                if len == total_shuttles {
                    break;
                }

                /// Get shuttle for this ID
                let shuttle = hangar18.all_shuttles(len);

                /// Principal and borrow balance (ie. owed amount)
                let (_cyg_usd_balance, _position_usdc, _position_usd) = shuttle.borrowable.get_lender_position(lender);

                cyg_usd_balance += _cyg_usd_balance;
                position_usdc += _position_usdc;
                position_usd += _position_usd;
                len += 1;
            };

            (cyg_usd_balance, position_usdc, position_usd)
        }

        /// # Implementation
        /// * ITransmissions
        fn get_shuttle_info_by_id(
            self: @ContractState, hangar18: IHangar18Dispatcher, shuttle_id: u32
        ) -> (ShuttleInfoC, ShuttleInfoB) {
            /// Get the shuttle with `shuttle_id` from the factory
            let shuttle = hangar18.all_shuttles(shuttle_id);

            /// Get the collateral dispatcher 
            let collateral = shuttle.collateral;

            /// The collateral shuttle stored vars
            let shuttleC = ShuttleInfoC {
                shuttle_id: shuttle_id,
                total_supply: collateral.total_supply(),
                total_balance: collateral.total_balance(),
                total_assets: collateral.total_assets(),
                exchange_rate: collateral.exchange_rate(),
                debt_ratio: collateral.debt_ratio(),
                liquidation_fee: collateral.liquidation_fee(),
                liquidation_incentive: collateral.liquidation_incentive(),
                lp_token_price: collateral.get_lp_token_price()
            };

            /// Get the borrowable dispatcher
            let borrowable = shuttle.borrowable;

            /// The borrowable shuttle stored vars (uses borrow indices)
            let shuttleB = ShuttleInfoB {
                shuttle_id: shuttle_id,
                total_supply: borrowable.total_supply(),
                total_balance: borrowable.total_balance(),
                total_borrows: borrowable.total_borrows(),
                total_assets: borrowable.total_assets(),
                exchange_rate: borrowable.exchange_rate(),
                reserve_factor: borrowable.reserve_factor(),
                utilization_rate: borrowable.utilization_rate(),
                supply_rate: borrowable.supply_rate(),
                borrow_rate: borrowable.borrow_rate(),
                usd_price: borrowable.get_usd_price()
            };

            (shuttleC, shuttleB)
        }

        /// # Implementation
        /// * ITransmissions
        fn get_shuttle_borrowers(
            self: @ContractState, hangar18: IHangar18Dispatcher, shuttle_id: u32
        ) -> Array<ContractAddress> {
            /// Get the shuttle for shuttle_id from the hangar18 contract
            let shuttle = hangar18.all_shuttles(shuttle_id);

            let borrowable = shuttle.borrowable;
            let collateral = shuttle.collateral;

            /// Get the borrowable's total positions length
            let all_positions_length = borrowable.all_positions_length();

            /// Accumulator and return array struct
            let mut len = 0;
            let mut borrowers = array![];

            loop {
                /// Break clause
                if len == all_positions_length {
                    break;
                }

                /// Get the borrower's address
                let borrower = borrowable.all_positions(len);
                let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);
                if (borrow_balance.is_non_zero()) {
                    borrowers.append(borrower);
                }

                len += 1;
            };

            borrowers
        }

        /// # Implementation
        /// * ITransmissions
        fn get_shuttles_borrowers_positions(
            self: @ContractState, hangar18: IHangar18Dispatcher, shuttle_id: u32, borrowers: Array<ContractAddress>
        ) -> Array<ShuttlePositions> {
            /// Get the shuttle for shuttle_id from the hangar18 contract
            let shuttle = hangar18.all_shuttles(shuttle_id);
            let borrowable = shuttle.borrowable;
            let collateral = shuttle.collateral;

            /// Get the borrowable's total positions length
            let borrowers_length = borrowers.len();

            /// Accumulator and return array struct
            let mut len = 0;
            let mut positions = array![];

            loop {
                /// Break clause
                if (len == borrowers_length) {
                    break;
                }

                /// Get borrower at index `len`
                let borrower = *borrowers.at(len);

                /// Get borrower's info from borrowable and collateral
                let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);
                let (position_lp, position_usd, health) = collateral.get_borrower_position(borrower);
                let cyg_lp_balance = collateral.balance_of(borrower);

                /// Add to position array
                positions
                    .append(
                        ShuttlePositions { borrower, cyg_lp_balance, position_lp, position_usd, borrow_balance, health }
                    );

                len += 1;
            };

            positions
        }

        /// # Implementation
        /// * ITransmissions
        fn get_shuttle_positions(
            self: @ContractState, hangar18: IHangar18Dispatcher, shuttle_id: u32
        ) -> Array<ShuttlePositions> {
            /// Get the shuttle for shuttle_id from the hangar18 contract
            let shuttle = hangar18.all_shuttles(shuttle_id);
            let borrowable = shuttle.borrowable;
            let collateral = shuttle.collateral;

            /// Get the borrowable's total positions length
            let all_positions_length = borrowable.all_positions_length();

            /// Accumulator and return array struct
            let mut len = 0;
            let mut positions = array![];

            loop {
                /// Break clause
                if len == all_positions_length {
                    break;
                }

                /// Get the borrower's address
                let borrower = borrowable.all_positions(len);

                /// Get borrower's info from borrowable and collateral
                let (_, borrow_balance) = borrowable.get_borrow_balance(borrower);
                let (position_lp, position_usd, health) = collateral.get_borrower_position(borrower);
                let cyg_lp_balance = collateral.balance_of(borrower);

                if (borrow_balance.is_non_zero()) {
                    positions
                        .append(
                            ShuttlePositions {
                                borrower, cyg_lp_balance, position_lp, position_usd, borrow_balance, health
                            }
                        );
                }

                len += 1;
            };

            positions
        }
    }
}
