use starknet::{ContractAddress, contract_address_const};

fn admin() -> ContractAddress {
    0x333.try_into().unwrap()
}

fn borrower() -> ContractAddress {
    0x666.try_into().unwrap()
}

fn lender() -> ContractAddress {
    0x999.try_into().unwrap()
}

fn second_borrower() -> ContractAddress {
    0x1332.try_into().unwrap()
}

fn second_lender() -> ContractAddress {
    0x1665.try_into().unwrap()
}

fn dao_reserves_contract() -> ContractAddress {
    0xda0.try_into().unwrap()
}
