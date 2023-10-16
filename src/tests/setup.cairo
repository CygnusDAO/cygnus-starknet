use starknet::{ContractAddress};
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait, ContractClass};

use cygnus::rewarder::pillars::{IPillarsOfCreationDispatcher, IPillarsOfCreationDispatcherTrait};
use cygnus::factory::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
use cygnus::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};
use cygnus::terminal::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::terminal::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::token::erc20::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use cygnus::registry::registry::{INebulaRegistryDispatcher, INebulaRegistryDispatcherTrait};
use cygnus::oracle::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};
use cygnus::token::erc20::cyg::{ICygnusDAODispatcher, ICygnusDAODispatcherTrait};

use cygnus::tests::users::{admin, borrower, lender, dao_reserves_contract};
// use snforge_std::io::PrintTrait;

/// ----------------------------------------------------------------------------------
///                               SETUP WITHOUT ROUTER                                             
/// ----------------------------------------------------------------------------------

/// Admin = 0x333
/// Borrower = 0x666
/// Lender = 0x999

/// 1. Deploy Borrowable deployer
/// 2. Deploy Collateral deployer
/// 3. Deploy LP Token and Stabelcoin
/// 4. Deploy Oracle registry & LP Token oracle
/// 5. Initialize LP token oracle in registry
/// 6. Deploy factory
/// 7. Initialize deployers in factory
/// 8. Deploy lending pool with orbiter id 0 and lp token address

/// Setup above
fn setup() -> (
    IHangar18Dispatcher,
    IBorrowableDispatcher,
    ICollateralDispatcher,
    IERC20Dispatcher,
    IERC20Dispatcher
) {
    // Make admin
    let admin = admin();

    // 1-2. Orbiters
    let albireo: IAlbireoDispatcher = deploy_albireo();
    let deneb: IDenebDispatcher = deploy_deneb();

    // 3. Mocks
    let erc20_contract = declare('ERC20');
    let (lp_token, usdc) = deploy_mock_tokens(erc20_contract);

    // 4-5. Registry and initialize oracle for lp_token
    let registry = deploy_registry(lp_token.contract_address);

    // 6. Factory
    let hangar18: IHangar18Dispatcher = deploy_hangar(usdc.contract_address, registry);

    // 7-8. Initialize orbiter and deploy factory
    start_prank(hangar18.contract_address, admin);
    hangar18.set_orbiter('Test', albireo, deneb);
    let (borrowable, collateral) = hangar18.deploy_shuttle(0, lp_token.contract_address);
    stop_prank(hangar18.contract_address);

    /// Set interest rate model: 1% base rate, 4% slope, 80% kink
    start_prank(borrowable.contract_address, admin);
    borrowable.set_interest_rate_model(10000000000000000, 40000000000000000, 3, 800000000000000000);
    stop_prank(borrowable.contract_address);

    (hangar18, borrowable, collateral, lp_token, usdc)
}


// Deploys hangar18 contract
fn deploy_hangar(
    usd_stablecoin: ContractAddress, registry: INebulaRegistryDispatcher
) -> IHangar18Dispatcher {
    let contract = declare('Hangar18');
    let admin: ContractAddress = admin();
    let constructor_calldata = array![
        admin.into(), registry.contract_address.into(), usd_stablecoin.into()
    ];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    let hangar18 = IHangar18Dispatcher { contract_address };

    /// Set the dao reserves contract
    start_prank(hangar18.contract_address, admin);
    let dao_reserves = dao_reserves_contract();
    hangar18.set_dao_reserves(dao_reserves);
    stop_prank(hangar18.contract_address);

    hangar18
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
    let registry = INebulaRegistryDispatcher {
        contract_address: contract.deploy(@constructor_calldata).unwrap()
    };

    /// Oracle for `lp_token`
    let contract = declare('CygnusNebula');
    let nebula = contract.deploy(@ArrayTrait::new()).unwrap();

    /// Initialize Oracle in the registry
    start_prank(registry.contract_address, admin);
    registry.create_nebula(nebula);
    let arr = array![registry.contract_address];
    registry.create_nebula_oracle(0, lp_token, arr, false);
    stop_prank(registry.contract_address);

    registry
}

// Deploys mock LP and USDC
fn deploy_mock_tokens(erc20_contract: ContractClass) -> (IERC20Dispatcher, IERC20Dispatcher) {
    // Deploy LP Token
    let borrower = borrower();
    let constructor_calldata = array!['lp_token', 'LPT', 1_000000000_000000000, 0, borrower.into()];
    let contract_address = erc20_contract.deploy(@constructor_calldata).unwrap();
    let lp_token = IERC20Dispatcher { contract_address };

    // Deploy stablecoin
    let lender = lender();
    let constructor_calldata = array![
        'stablecoin', 'STB', 1000_000000000_000000000, 0, lender.into()
    ];
    let contract_address = erc20_contract.deploy(@constructor_calldata).unwrap();
    let usdc = IERC20Dispatcher { contract_address };

    (lp_token, usdc)
}

// Deploy CYG token
fn deploy_cyg_token() -> ICygnusDAODispatcher {
    let contract = declare('CygnusDAO');
    let admin = admin();
    let mut constructor_calldata = array![];
    constructor_calldata.append('CygnusDAO');
    constructor_calldata.append('CYG');
    constructor_calldata.append(admin.into());

    let cyg_token = ICygnusDAODispatcher {
        contract_address: contract.deploy(@constructor_calldata).unwrap()
    };

    cyg_token
}

// Deploy Pillars
fn deploy_pillars_of_creation(
    hangar18: IHangar18Dispatcher, cyg_token: ContractAddress
) -> IPillarsOfCreationDispatcher {
    let contract = declare('PillarsOfCreation');
    let admin = admin();

    // total is 2.5 M
    // 20% for DAO = 500k
    // 10% for team = 250k
    // 70% for rewards = 1,750,000

    let _hangar18 = hangar18.contract_address;
    let constructor_calldata = array![_hangar18.into(), cyg_token.into()];
    constructor_calldata.span();

    let pillars = IPillarsOfCreationDispatcher {
        contract_address: contract.deploy(@constructor_calldata).unwrap()
    };

    pillars
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
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    let altair = IAltairDispatcher { contract_address };

    (hangar18, borrowable, collateral, lp_token, usdc, altair)
}

/// ----------------------------------------------------------------------------------
///                               SETUP WITH PILLARS
/// ----------------------------------------------------------------------------------

/// Same as above adding pillars and cyg token
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
    let (hangar18, borrowable, collateral, lp_token, usdc, altair) = setup_with_router();
    let cyg_token = deploy_cyg_token();
    let pillars = deploy_pillars_of_creation(hangar18, cyg_token.contract_address);

    (hangar18, borrowable, collateral, lp_token, usdc, altair, cyg_token, pillars)
}
