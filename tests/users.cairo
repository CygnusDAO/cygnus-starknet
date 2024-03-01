use starknet::{ContractAddress, contract_address_const};

// For fork tests, setup borrower with LP token balance, and usdc whale

fn admin() -> ContractAddress {
    0x666.try_into().unwrap()
}

fn borrower() -> ContractAddress {
    contract_address_const::<0x06623706abf247216031b4205c1038b2b6db2026b98cad4a2823fddd2b7af055>()
}

fn lender() -> ContractAddress {
    contract_address_const::<0x00d4a8b36b0bb620f69d1901bbdb9d72d8dd77ee2055257ef1785ae705fe0cc6>()
}

fn dao_reserves_contract() -> ContractAddress {
    0xda0.try_into().unwrap()
}
