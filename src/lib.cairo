
/// # Module - factory - The factory contract that stores deployers and keeps a record of all shuttles deployed
/// * `hangar18` - The Cygnus factory contract that uses orbiters to deploy shuttles
/// * `errors` - Hangar18 errors
mod factory {
    mod hangar18;
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

/// # Module 
/// * `terminal` - The core Cygnus contracts where users deposit liquidity/stablecoins
mod terminal {
    mod borrowable;
    mod collateral;
    mod errors;
}

/// # Module
/// * `voids` - Strategies used by core
mod voids {
    mod zklend;
}

/// # Module
/// * `periphery` - User friendly contracts to interact with core
mod periphery {
    mod altair;
    mod altair_call;
    mod errors;
    mod integrations { 
      mod jediswap_router;
    }
}

/// # Module
/// * `rewarder` - CYG rewarder contract
mod rewarder {
    mod pillars;
}

/// # Module 
/// * `data` - Data structures of all Cygnus contracts
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

/// # Module 
/// * `registry` - The Registry of oracles deployed that keeps track of all LP oracles deployed by CygnusDAO
mod registry {
    mod registry;
    mod errors;
}

/// # Module 
/// * `oracle` - LP Oracle
mod oracle {
    mod nebula;
    mod pragma_interface;
}

/// # Module - libraries - Libraries used by core and periphery contract
mod libraries {
    mod full_math_lib;
    mod date_time_lib;
    mod errors;
}

/// # Module
/// * `token` - Standard tokens/interfaces and the CYG Token
mod token {
    mod erc20;
    mod univ2pair;
    mod cyg;
}

/// # Module 
/// * `bridge` - The CYG bridge between mainnet and starknet
mod bridge {
    mod teleporter;
}

