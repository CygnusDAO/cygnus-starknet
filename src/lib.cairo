/// # Module
/// * `token` - Standard tokens/interfaces and the CYG Token
mod token {
    mod erc20;
    mod univ2pair;
    //mod sithpair;
    mod cyg;
}

/// # Module 
/// * `bridge` - The CYG bridge between mainnet and starknet
mod bridge {
    mod teleporter;
}

/// # Module 
/// * `terminal` - The core Cygnus contracts where users deposit liquidity/stablecoins
mod terminal {
    mod borrowable;
    mod collateral;
    mod errors;
}

/// # Module 
/// * `orbiters` - The deployer contracts that deploy Cygnus Core (borrowable and collateral contracts)
/// * `albireo` - The borrowable deployer
/// * `deneb` - The collateral deployer
mod orbiters {
    mod albireo;
    mod deneb;
}

/// # Module - factory - The factory contract that stores deployers and keeps a record of all shuttles deployed
/// * `hangar18` - The Cygnus factory contract that uses orbiters to deploy shuttles
/// * `errors` - Hangar18 errors
mod factory {
    mod hangar18;
    mod errors;
}

mod rewarder {
    mod pillars;
}

/// # Module - data - Data structures of all Cygnus contracts
/// * `orbiter` - Holds data of albireo/deneb orbiters deployed and added to the hangar18 contract
/// * `shuttle` - Keeps track of shuttles deployed on the factory
/// * `registry` - Data of ebulas (LP oracles) deplpoyed. Ideally 1 per dex or 1 per type of collateral (BPTs, LPs, etc.)
/// * `interest` - Interest rate variables of each borrowable contract with base rate, slope, kink and kink multiplier.
/// * `calldata` - Calldata used by the periphery contract to interact with core to leverage/deleverage/flash liquidate positions
/// * `pillars` - Data used by the CYG rewarder contract to keep track of lenders, borrowers and epochs
mod data {
    mod orbiter;
    mod shuttle;
    mod registry;
    mod interest;
    mod calldata;
    mod pillars;
    mod signed_integer {
        mod i256;
        mod i128;
        mod i64;
        mod integer_trait;
    }
    mod altair;
    mod x1vault;
    mod nebula;
}

/// # Module - registry - The LP Oracle registry that keeps track of all LP oracles deployed by CygnusDAO
/// * `registry` - The registry contract where the factory reports to to check for oracles before deploying shuttles
/// * `errors` - Registry errors
mod registry {
    mod registry;
    mod errors;
}

/// # Module - oracle - Nebulas (LP oracles) deployed
/// * `nebula` - The nebula contract that handles the logic for pricing liquidity (BPTs, LPs, YAS positions, etc.)
mod oracle {
    mod nebula;
    mod pragma_interface;
}

/// # Module - libraries - Libraries used by core and periphery contract
/// * `full_math_lib` - Simple u128 math lib used by core/periphery contracts
/// * `errors` - Math Library errors
mod libraries {
    mod full_math_lib;
    mod date_time_lib;
    mod errors;
}

mod voids {
    mod zklend;
}

mod periphery {
    mod altair;
    mod errors;
    mod integrations {
        mod jediswap_router;
    }
}

mod dao {
    mod dao_reserves;
}
