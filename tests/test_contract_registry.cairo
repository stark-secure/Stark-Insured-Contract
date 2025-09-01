use snforge_std::{CheatTarget, ContractClassTrait, declare, start_prank, stop_prank};
use stark_insured::interfaces::{IContractRegistryDispatcher, IContractRegistryDispatcherTrait};
use starknet::{ContractAddress, contract_address_const};

/// @notice Test successful contract registration
#[test]
fn test_register_contract_success() {
    let contract = declare("ContractRegistry");
    let owner = contract_address_const::<'owner'>();
    let contract_address = contract.deploy(@array![owner.into()]).unwrap();
    let registry = IContractRegistryDispatcher { contract_address };
    
    let policy_manager_addr = contract_address_const::<'policy_manager'>();
    let name = 'POLICY_MANAGER';
    
    start_prank(CheatTarget::One(contract_address), owner);
    registry.register_contract(name, policy_manager_addr);
    stop_prank(CheatTarget::One(contract_address));
    
    // Verify registration
    assert!(registry.is_registered(name));
    assert_eq!(registry.get_address(name), policy_manager_addr);
}

/// @notice Test contract re-registration (update)
#[test]
fn test_register_contract_update() {
    let contract = declare("ContractRegistry");
    let owner = contract_address_const::<'owner'>();
    let contract_address = contract.deploy(@array![owner.into()]).unwrap();
    let registry = IContractRegistryDispatcher { contract_address };
    
    let old_addr = contract_address_const::<'old_policy_manager'>();
    let new_addr = contract_address_const::<'new_policy_manager'>();
    let name = 'POLICY_MANAGER';
    
    start_prank(CheatTarget::One(contract_address), owner);
    
    // Initial registration
    registry.register_contract(name, old_addr);
    assert_eq!(registry.get_address(name), old_addr);
    
    // Update registration
    registry.register_contract(name, new_addr);
    assert_eq!(registry.get_address(name), new_addr);
    
    stop_prank(CheatTarget::One(contract_address));
}

/// @notice Test unauthorized registration attempt
#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_register_contract_unauthorized() {
    let contract = declare("ContractRegistry");
    let owner = contract_address_const::<'owner'>();
    let unauthorized = contract_address_const::<'unauthorized'>();
    let contract_address = contract.deploy(@array![owner.into()]).unwrap();
    let registry = IContractRegistryDispatcher { contract_address };
    
    let policy_manager_addr = contract_address_const::<'policy_manager'>();
    let name = 'POLICY_MANAGER';
    
    start_prank(CheatTarget::One(contract_address), unauthorized);
    registry.register_contract(name, policy_manager_addr);
}

/// @notice Test registration with invalid name
#[test]
#[should_panic(expected: ('Invalid contract name',))]
fn test_register_contract_invalid_name() {
    let contract = declare("ContractRegistry");
    let owner = contract_address_const::<'owner'>();
    let contract_address = contract.deploy(@array![owner.into()]).unwrap();
    let registry = IContractRegistryDispatcher { contract_address };
    
    let policy_manager_addr = contract_address_const::<'policy_manager'>();
    
    start_prank(CheatTarget::One(contract_address), owner);
    registry.register_contract(0, policy_manager_addr); // Invalid name
}

/// @notice Test registration with invalid address
#[test]
#[should_panic(expected: ('Invalid contract address',))]
fn test_register_contract_invalid_address() {
    let contract = declare("ContractRegistry");
    let owner = contract_address_const::<'owner'>();
    let contract_address = contract.deploy(@array![owner.into()]).unwrap();
    let registry = IContractRegistryDispatcher { contract_address };
    
    let name = 'POLICY_MANAGER';
    
    start_prank(CheatTarget::One(contract_address), owner);
    registry.register_contract(name, contract_address_const::<0>()); // Invalid address
}

/// @notice Test getting address for unregistered contract
#[test]
#[should_panic(expected: ('Contract not found',))]
fn test_get_address_not_found() {
    let contract = declare("ContractRegistry");
    let owner = contract_address_const::<'owner'>();
    let contract_address = contract.deploy(@array![owner.into()]).unwrap();
    let registry = IContractRegistryDispatcher { contract_address };
    
    registry.get_address('NONEXISTENT');
}

/// @notice Test contract unregistration
#[test]
fn test_unregister_contract() {
    let contract = declare("ContractRegistry");
    let owner = contract_address_const::<'owner'>();
    let contract_address = contract.deploy(@array![owner.into()]).unwrap();
    let registry = IContractRegistryDispatcher { contract_address };
    
    let policy_manager_addr = contract_address_const::<'policy_manager'>();
    let name = 'POLICY_MANAGER';
    
    start_prank(CheatTarget::One(contract_address), owner);
    
    // Register first
    registry.register_contract(name, policy_manager_addr);
    assert!(registry.is_registered(name));
    
    // Unregister
    registry.unregister_contract(name);
    assert!(!registry.is_registered(name));
    
    stop_prank(CheatTarget::One(contract_address));
}

/// @notice Test getting all registered names
#[test]
fn test_get_all_names() {
    let contract = declare("ContractRegistry");
    let owner = contract_address_const::<'owner'>();
    let contract_address = contract.deploy(@array![owner.into()]).unwrap();
    let registry = IContractRegistryDispatcher { contract_address };
    
    start_prank(CheatTarget::One(contract_address), owner);
    
    // Register multiple contracts
    registry.register_contract('POLICY_MANAGER', contract_address_const::<'pm'>());
    registry.register_contract('CLAIMS_PROCESSOR', contract_address_const::<'cp'>());
    registry.register_contract('RISK_POOL', contract_address_const::<'rp'>());
    
    let names = registry.get_all_names();
    assert_eq!(names.len(), 3);
    
    stop_prank(CheatTarget::One(contract_address));
}

/// @notice Tests comprehensive registry workflows
#[test]
fn test_registry_workflow() {
    let contract = declare("ContractRegistry");
    let owner = contract_address_const::<'owner'>();
    let contract_address = contract.deploy(@array![owner.into()]).unwrap();
    let registry = IContractRegistryDispatcher { contract_address };
    
    start_prank(CheatTarget::One(contract_address), owner);
    
    // Register core protocol contracts
    registry.register_contract('POLICY_MANAGER', contract_address_const::<'pm'>());
    registry.register_contract('CLAIMS_PROCESSOR', contract_address_const::<'cp'>());
    registry.register_contract('RISK_POOL', contract_address_const::<'rp'>());
    registry.register_contract('DAO_GOVERNANCE', contract_address_const::<'dao'>());
    
    // Verify all registrations
    assert!(registry.is_registered('POLICY_MANAGER'));
    assert!(registry.is_registered('CLAIMS_PROCESSOR'));
    assert!(registry.is_registered('RISK_POOL'));
    assert!(registry.is_registered('DAO_GOVERNANCE'));
    
    // Test address retrieval
    assert_eq!(registry.get_address('POLICY_MANAGER'), contract_address_const::<'pm'>());
    assert_eq!(registry.get_address('CLAIMS_PROCESSOR'), contract_address_const::<'cp'>());
    
    // Test enumeration
    let names = registry.get_all_names();
    assert_eq!(names.len(), 4);
    
    stop_prank(CheatTarget::One(contract_address));
}