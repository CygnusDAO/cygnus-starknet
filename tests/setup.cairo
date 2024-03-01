/// # Libraries
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait, ContractClass, CheatTarget};

/// # Interfaces
use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
use cygnus::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::registry::registry::{INebulaRegistryDispatcher, INebulaRegistryDispatcherTrait};
use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};
use cygnus::cyg::cygnusdao::{ICygnusDAODispatcher, ICygnusDAODispatcherTrait};
use cygnus::rewarder::pillars::{IPillarsOfCreationDispatcher, IPillarsOfCreationDispatcherTrait};
use cygnus::dao::dao_reserves::{ICygnusDAOReservesDispatcher, ICygnusDAOReservesDispatcherTrait};

use tests::users::{admin, dao_reserves_contract};

// BLOCK_TIMESTAMP: 1699658109

/// ----------------------------------------------------------------------------------
///                               SETUP WITHOUT ROUTER                                             
/// ----------------------------------------------------------------------------------

/// Admin = 0x666

/// 1. Deploy Borrowable deployer
/// 2. Deploy Collateral deployer
/// 3. Deploy LP Token and Stabelcoin
/// 4. Deploy Oracle registry & LP Token oracle
/// 5. Initialize LP token oracle in registry
/// 6. Deploy factory
/// 7. Initialize deployers in factory
/// 8. Deploy lending pool with orbiter id 0 and lp token address
use snforge_std::PrintTrait;

const FEED0: felt252 = 'DAI/USD';
const FEED1: felt252 = 'ETH/USD';

/// Setup above
fn setup() -> (IHangar18Dispatcher, IBorrowableDispatcher, ICollateralDispatcher, IERC20Dispatcher, IERC20Dispatcher) {
    // ----------------------------------------------------------------------------------------------
    //                                          SETUP
    // ----------------------------------------------------------------------------------------------

    // Make LP token
    let lp_token_address: ContractAddress = contract_address_const::<
        0x07e2a13b40fc1119ec55e0bcf9428eedaa581ab3c924561ad4e955f95da63138
    >();
    let lp_token = IERC20Dispatcher { contract_address: lp_token_address };

    // Make USDC
    let usdc_address: ContractAddress = contract_address_const::<
        0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
    >();
    let usdc = IERC20Dispatcher { contract_address: usdc_address };

    // ----------------------------------------------------------------------------------------------
    //                                          1. ORBITERS
    // ----------------------------------------------------------------------------------------------

    // Borrowable deployer
    let albireo: IAlbireoDispatcher = deploy_albireo();

    // Collateral deployer
    let deneb: IDenebDispatcher = deploy_deneb();

    // ----------------------------------------------------------------------------------------------
    //                                          2. REGISTRY
    // ----------------------------------------------------------------------------------------------

    // Deploy registry and initialize oracle
    let registry = deploy_registry(lp_token.contract_address);

    // ----------------------------------------------------------------------------------------------
    //                                          3. HANGAR 18
    // ----------------------------------------------------------------------------------------------

    let admin = admin();

    // Factory
    let hangar18: IHangar18Dispatcher = deploy_hangar(admin, registry);

    // Initialize orbiter in factory and deploy shuttle
    start_prank(CheatTarget::One(hangar18.contract_address), admin);
    hangar18.set_orbiter('Test', albireo, deneb);
    let (borrowable, collateral) = hangar18.deploy_shuttle(0, lp_token.contract_address);
    stop_prank(CheatTarget::One(hangar18.contract_address));

    /// Set interest rate model: 1% base rate, 4% slope, 80% kink
    start_prank(CheatTarget::One(borrowable.contract_address), admin);
    borrowable.set_interest_rate_model(10000000000000000, 40000000000000000, 3, 800000000000000000);
    stop_prank(CheatTarget::One(borrowable.contract_address));

    (hangar18, borrowable, collateral, lp_token, usdc)
}


// Deploys hangar18 contract
fn deploy_hangar(usd_stablecoin: ContractAddress, registry: INebulaRegistryDispatcher) -> IHangar18Dispatcher {
    let contract = declare('Hangar18');
    let admin: ContractAddress = admin();
    let constructor_calldata = array![admin.into(), registry.contract_address.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    let hangar18 = IHangar18Dispatcher { contract_address };

    /// Set the dao reserves contract
    start_prank(CheatTarget::One(hangar18.contract_address), admin);
    let dao_reserves = deploy_reserves(hangar18);
    hangar18.set_dao_reserves(dao_reserves);
    stop_prank(CheatTarget::One(hangar18.contract_address));

    hangar18
}

fn deploy_reserves(hangar18: IHangar18Dispatcher) -> ICygnusDAOReservesDispatcher {
    let contract = declare('CygnusDAOReserves');
    let constructor_calldata = array![hangar18.contract_address.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    ICygnusDAOReservesDispatcher { contract_address }
}

// Deploys borrowable deployer
fn deploy_albireo() -> IAlbireoDispatcher {
    let contract = declare('Albireo');
    let borrowable_class_hash = declare('Borrowable');
    let constructor_calldata = array![borrowable_class_hash.class_hash.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();

    IAlbireoDispatcher { contract_address }
}

// Deploys collateral deployer
fn deploy_deneb() -> IDenebDispatcher {
    let contract = declare('Deneb');
    let collateral_class_hash = declare('Collateral');
    let constructor_calldata = array![collateral_class_hash.class_hash.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();

    IDenebDispatcher { contract_address }
}

// Deploys registry
fn deploy_registry(lp_token: ContractAddress) -> INebulaRegistryDispatcher {
    /// Registry
    let contract = declare('NebulaRegistry');
    let admin = admin();
    let constructor_calldata = array![admin.into()];
    let registry = INebulaRegistryDispatcher { contract_address: contract.deploy(@constructor_calldata).unwrap() };

    /// Oracle for `lp_token`
    let contract = declare('CygnusNebula');

    // USDC
    let usdc_address: ContractAddress = contract_address_const::<
        0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
    >();
    let usdc = IERC20Dispatcher { contract_address: usdc_address };
    let constructor_calldata = array![usdc_address.into(), registry.contract_address.into()];
    let nebula = contract.deploy(@constructor_calldata).unwrap();

    /// Initialize Oracle in the registry
    start_prank(CheatTarget::One(registry.contract_address), admin);
    registry.create_nebula(nebula);
    registry.create_nebula_oracle(0, lp_token, FEED0, FEED1, false);
    stop_prank(CheatTarget::One(registry.contract_address));

    registry
}


/// ----------------------------------------------------------------------------------
///                                 SETUP WITH ROUTER                                                
/// ----------------------------------------------------------------------------------

/// Same as above but using the periphery router
fn setup_with_router() -> (
    IHangar18Dispatcher,
    IBorrowableDispatcher,
    ICollateralDispatcher,
    IERC20Dispatcher,
    IERC20Dispatcher,
    IAltairDispatcher
) {
    let (hangar18, borrowable, collateral, lp_token, usdc) = setup();
    let contract = declare('Altair');
    let constructor_calldata = array![hangar18.contract_address.into()];

    let router_address: ContractAddress = 3571209267755763903763264597735339599831736041712076943754439530500687754911
        .try_into()
        .unwrap();
    let contract_address = contract.deploy_at(@constructor_calldata, router_address).unwrap();
    let altair = IAltairDispatcher { contract_address };

    (hangar18, borrowable, collateral, lp_token, usdc, altair)
}

/// Same as above but using the periphery router + pillars
fn setup_with_pillars() -> (
    IHangar18Dispatcher,
    IBorrowableDispatcher,
    ICollateralDispatcher,
    IERC20Dispatcher,
    IERC20Dispatcher,
    IAltairDispatcher,
    ICygnusDAODispatcher,
    IPillarsOfCreationDispatcher
) {
    let (hangar18, borrowable, collateral, lp_token, usdc) = setup();
    let contract = declare('Altair');
    let constructor_calldata = array![hangar18.contract_address.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    let altair = IAltairDispatcher { contract_address };

    // Deploy CYG
    let name = 'CygnusDAO';
    let symbol = 'CYG';
    let owner = admin();
    let contract = declare('CygnusDAO');
    let constructor_calldata = array![owner.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    let cyg_token = ICygnusDAODispatcher { contract_address };

    // Deploy Pillars
    let contract = declare('PillarsOfCreation');
    let constructor_calldata = array![hangar18.contract_address.into(), cyg_token.contract_address.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    let pillars = IPillarsOfCreationDispatcher { contract_address };

    (hangar18, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars)
}
