/// Factory (shuttle deployer)
mod factory {
    mod hangar18;
    mod errors;
}

/// Borrowable and Collateral deployers
mod orbiters {
    mod albireo;
    mod deneb;
}

/// Borrowable and collateral contracts
mod terminal {
    mod collateral;
    mod borrowable;
    mod errors;
}

/// Router
mod periphery {
    mod altair;
    mod errors;
}

/// Oracle registry
mod registry {
    mod registry;
    mod errors;
}

/// LP Oracle
mod oracle {
    mod nebula;
}

/// Pillars of creation (CYG rewarder)
mod rewarder {
    mod pillars;
}

/// Mock tokens
mod token {
    mod erc20;
}

// Tests
// mod tests {
//     mod setup;
//     mod users;
//     mod repay {
//         mod test_repay;
//     }
//     mod periphery {
//         mod test_altair;
//     }
//     mod models {
//         mod test_collateral_model;
//     }
//     mod registry {
//         mod test_registry;
//     }
//     mod deposit {
//         mod test_deposit;
//     }
//     mod borrow {
//         mod test_borrow;
//     }
//     mod redeem {
//         mod test_flash_redeem;
//     }
//     mod orbiters {
//         mod test_deployers;
//     }
//     mod factory {
//         mod test_hangar;
//     }
//     mod utils {
//         mod datetime;
//     }
//     mod pillars {
//         mod test_cygtoken;
//         mod test_pillars_storage;
//         mod test_rewards;
//     }
// }

/// Data structures
mod data {
    mod orbiter;
    mod shuttle;
    mod registry;
    mod interest;
    mod calldata;
    mod pillars;
    mod signed_integer {
        mod i256;
        mod integer_trait;
    }
    mod altair;
}

/// Global utils
mod utils {
    mod datetime;
}

// Libraries
mod libraries {
    mod full_math_lib;
}

mod voids {
    mod bstrategy;
}
