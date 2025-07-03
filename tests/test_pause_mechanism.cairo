use snforge_std::{CheatTarget, ContractClassTrait, declare, start_prank, stop_prank};
use stark_insured::interfaces::{IPauseableDispatcher, IPauseableDispatcherTrait};
use starknet::{ContractAddress, contract_address_const};

#[test]
fn test_pause_unpause_policy_manager() {
    let contract = declare("PolicyManager");
    let owner = contract_address_const::<'owner'>();
    let token = contract_address_const::<'token'>();
    
    let contract_address = contract.deploy(@array![owner.into(), token.into()]).unwrap();
    let pauseable = IPauseableDispatcher { contract_address };
    
    // Test initial state
    assert!(!pauseable.is_paused());
    
    // Test pause as owner
    start_prank(CheatTarget::One(contract_address), owner);
    pauseable.pause();
    assert!(pauseable.is_paused());
    
    // Test unpause as owner
    pauseable.unpause();
    assert!(!pauseable.is_paused());
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_paused_functions_fail() {
    // Test that sensitive functions fail when paused
    // Implementation specific to each contract
}