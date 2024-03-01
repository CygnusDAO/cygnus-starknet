/// # Module 
/// * `terminal` - The core Cygnus contracts where users deposit liquidity/stablecoins
mod terminal {
    mod borrowable;
    mod collateral;
    mod errors;
    mod events;
}

/// # Module
/// * `periphery` - The periphery contracts to interact with core
mod periphery {
    mod altair;
    mod altair_x;
    mod transmissions;
    mod errors;
    mod integrations {
        mod jediswap_router;
    }
}

/// # Module 
/// * `orbiters` - The deployer contracts that deploy Cygnus Core (borrowable and collateral contracts)
mod orbiters {
    mod albireo;
    mod deneb;
}

/// # Module 
/// * `factory` - The factory contract that stores deployers and keeps a record of all shuttles deployed
mod factory {
    mod hangar18;
    mod errors;
    mod events;
}

/// # Module
/// * `dao` - The DAO reserves contract
mod dao {
    mod dao_reserves;
    mod errors;
    mod events;
}

/// # Module 
/// * `registry` - The registry for all LP token oracles (balancer oracle, univ2, univ3, etc.)
mod registry {
    mod registry;
    mod errors;
    mod events;
}

/// # Module
/// * `oracle` - The LP Token oracle (in this case jedi)
mod oracle {
    mod nebula;
    mod pragma_interface;
    mod errors;
    mod events;
}

/// # Module
/// * `cyg` - The CYG token
mod cyg {
    mod cygnusdao;
    mod events;
    mod errors;
}

/// # Module
/// * `rewarder` - The CYG rewarder contract
mod rewarder {
    mod pillars;
    mod errors;
    mod events;
}

/// # Module 
/// * `data` - Data structures for all contracts
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
/// * `libraries` - Libraries used by core and periphery contract
mod libraries {
    mod full_math_lib;
    mod date_time_lib;
    mod errors;
}

/// # Module
/// * `voids` - The interface of borrowable/collateral strategies
mod voids {
    mod zklend;
}


/// # Module
/// * `token` - Standard tokens/interfaces
mod token {
    mod erc20;
    mod univ2pair;
}
