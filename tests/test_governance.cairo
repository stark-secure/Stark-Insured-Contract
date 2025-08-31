use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
use governance_contract::{IGovernanceDispatcher, IGovernanceDispatcherTrait};

fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn USER1() -> ContractAddress {
    contract_address_const::<'user1'>()
}

fn USER2() -> ContractAddress {
    contract_address_const::<'user2'>()
}

fn deploy_governance() -> IGovernanceDispatcher {
    let contract = declare("Governance");
    let constructor_calldata = array![OWNER().into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    IGovernanceDispatcher { contract_address }
}

#[test]
fn test_pause_unpause_functionality() {
    let governance = deploy_governance();
    
    // Initially not paused
    assert(!governance.is_paused(), 'Should not be paused initially');
    
    // Only owner can pause
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.pause();
    assert(governance.is_paused(), 'Should be paused');
    
    // Unpause
    governance.unpause();
    assert(!governance.is_paused(), 'Should be unpaused');
    stop_prank(CheatTarget::One(governance.contract_address));
}

#[test]
#[should_panic(expected: ('Only owner can call this function',))]
fn test_pause_only_owner() {
    let governance = deploy_governance();
    
    // Non-owner tries to pause
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    governance.pause();
}
