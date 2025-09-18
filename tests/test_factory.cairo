use starknet::{ContractAddress, contract_address_const, deploy_syscall, ClassHash};
use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
use insurance_project::insurance_factory::{
    InsuranceFactory, IInsuranceFactoryDispatcher, IInsuranceFactoryDispatcherTrait,
};
use insurance_project::policy_manager::{
    PolicyManager, IPolicyManagerDispatcher, IPolicyManagerDispatcherTrait,
};

fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn USER1() -> ContractAddress {
    contract_address_const::<'user1'>()
}

fn USER2() -> ContractAddress {
    contract_address_const::<'user2'>()
}

fn ASSET() -> ContractAddress {
    contract_address_const::<'asset'>()
}

fn deploy_factory() -> (IInsuranceFactoryDispatcher, ClassHash) {
    // Declare and get class hash for PolicyManager
    let policy_manager_class = declare("PolicyManager");
    let policy_manager_class_hash = policy_manager_class.class_hash;

    // Declare InsuranceFactory
    let factory_class = declare("InsuranceFactory");

    // Deploy factory with policy manager class hash
    let mut constructor_calldata = array![OWNER().into(), policy_manager_class_hash.into()];
    let (factory_address, _) = factory_class.deploy(@constructor_calldata).unwrap();

    (IInsuranceFactoryDispatcher { contract_address: factory_address }, policy_manager_class_hash)
}

#[test]
fn test_factory_deployment() {
    let (factory, _) = deploy_factory();

    // Test that owner is authorized by default
    assert(factory.is_authorized(OWNER()), 'Owner should be authorized');
    assert(!factory.is_authorized(USER1()), 'User1 should not be authorized');
}

#[test]
fn test_authorize_user() {
    let (factory, _) = deploy_factory();

    // Only owner can authorize users
    start_prank(CheatTarget::One(factory.contract_address), OWNER());
    factory.add_authorized_user(USER1());
    stop_prank(CheatTarget::One(factory.contract_address));

    assert(factory.is_authorized(USER1()), 'User1 should be authorized');
}

#[test]
#[should_panic(expected: ('Only owner can authorize',))]
fn test_unauthorized_user_cannot_authorize() {
    let (factory, _) = deploy_factory();

    // Non-owner tries to authorize - should fail
    start_prank(CheatTarget::One(factory.contract_address), USER1());
    factory.add_authorized_user(USER2());
}

#[test]
fn test_create_single_policy() {
    let (factory, _) = deploy_factory();

    // Authorize user first
    start_prank(CheatTarget::One(factory.contract_address), OWNER());
    factory.add_authorized_user(USER1());
    stop_prank(CheatTarget::One(factory.contract_address));

    // Create policy as authorized user
    start_prank(CheatTarget::One(factory.contract_address), USER1());
    let policy_address = factory
        .create_policy(USER1(), 'health_insurance', 365_u64, // 1 year duration
        ASSET(), 'salt1');
    stop_prank(CheatTarget::One(factory.contract_address));

    // Verify policy was created and tracked
    assert(factory.get_policy_count(USER1()) == 1, 'Should have 1 policy');

    let user_policies = factory.get_user_policies(USER1());
    assert(user_policies.len() == 1, 'Should have 1 policy in array');
    assert(*user_policies.at(0) == policy_address, 'Policy address should match');

    // Verify the deployed policy contract
    let policy = IPolicyManagerDispatcher { contract_address: policy_address };
    assert(policy.get_owner() == USER1(), 'Policy owner should be USER1');
    assert(policy.get_coverage_type() == 'health_insurance', 'Coverage type should match');
    assert(policy.get_duration() == 365_u64, 'Duration should match');
    assert(policy.get_asset() == ASSET(), 'Asset should match');
    assert(policy.is_active(), 'Policy should be active');
}

#[test]
fn test_create_multiple_policies() {
    let (factory, _) = deploy_factory();

    // Authorize user
    start_prank(CheatTarget::One(factory.contract_address), OWNER());
    factory.add_authorized_user(USER1());
    stop_prank(CheatTarget::One(factory.contract_address));

    // Create multiple policies
    start_prank(CheatTarget::One(factory.contract_address), USER1());

    let policy1 = factory.create_policy(USER1(), 'health_insurance', 365_u64, ASSET(), 'salt1');

    let policy2 = factory.create_policy(USER1(), 'car_insurance', 180_u64, ASSET(), 'salt2');

    let policy3 = factory.create_policy(USER1(), 'home_insurance', 730_u64, ASSET(), 'salt3');

    stop_prank(CheatTarget::One(factory.contract_address));

    // Verify all policies were tracked
    assert(factory.get_policy_count(USER1()) == 3, 'Should have 3 policies');

    let user_policies = factory.get_user_policies(USER1());
    assert(user_policies.len() == 3, 'Should have 3 policies in array');

    // Verify each policy is different and correctly configured
    let policy1_contract = IPolicyManagerDispatcher { contract_address: policy1 };
    let policy2_contract = IPolicyManagerDispatcher { contract_address: policy2 };
    let policy3_contract = IPolicyManagerDispatcher { contract_address: policy3 };

    assert(policy1_contract.get_coverage_type() == 'health_insurance', 'Policy1 type should match');
    assert(policy2_contract.get_coverage_type() == 'car_insurance', 'Policy2 type should match');
    assert(policy3_contract.get_coverage_type() == 'home_insurance', 'Policy3 type should match');

    assert(policy1_contract.get_duration() == 365_u64, 'Policy1 duration should match');
    assert(policy2_contract.get_duration() == 180_u64, 'Policy2 duration should match');
    assert(policy3_contract.get_duration() == 730_u64, 'Policy3 duration should match');
}

#[test]
#[should_panic(expected: ('Unauthorized user',))]
fn test_unauthorized_user_cannot_create_policy() {
    let (factory, _) = deploy_factory();

    // Try to create policy without authorization - should fail
    start_prank(CheatTarget::One(factory.contract_address), USER1());
    factory.create_policy(USER1(), 'health_insurance', 365_u64, ASSET(), 'salt1');
}

#[test]
fn test_multiple_users_create_policies() {
    let (factory, _) = deploy_factory();

    // Authorize both users
    start_prank(CheatTarget::One(factory.contract_address), OWNER());
    factory.add_authorized_user(USER1());
    factory.add_authorized_user(USER2());
    stop_prank(CheatTarget::One(factory.contract_address));

    // USER1 creates policies
    start_prank(CheatTarget::One(factory.contract_address), USER1());
    factory.create_policy(USER1(), 'health_insurance', 365_u64, ASSET(), 'user1_salt1');
    factory.create_policy(USER1(), 'car_insurance', 180_u64, ASSET(), 'user1_salt2');
    stop_prank(CheatTarget::One(factory.contract_address));

    // USER2 creates policies
    start_prank(CheatTarget::One(factory.contract_address), USER2());
    factory.create_policy(USER2(), 'home_insurance', 730_u64, ASSET(), 'user2_salt1');
    stop_prank(CheatTarget::One(factory.contract_address));

    // Verify each user's policies are tracked separately
    assert(factory.get_policy_count(USER1()) == 2, 'USER1 should have 2 policies');
    assert(factory.get_policy_count(USER2()) == 1, 'USER2 should have 1 policy');

    let user1_policies = factory.get_user_policies(USER1());
    let user2_policies = factory.get_user_policies(USER2());

    assert(user1_policies.len() == 2, 'USER1 should have 2 policies in array');
    assert(user2_policies.len() == 1, 'USER2 should have 1 policy in array');
}

#[test]
fn test_deauthorize_user() {
    let (factory, _) = deploy_factory();

    // Authorize user first
    start_prank(CheatTarget::One(factory.contract_address), OWNER());
    factory.add_authorized_user(USER1());
    assert(factory.is_authorized(USER1()), 'User1 should be authorized');

    // Deauthorize user
    factory.remove_authorized_user(USER1());
    stop_prank(CheatTarget::One(factory.contract_address));

    assert(!factory.is_authorized(USER1()), 'User1 should not be authorized');
}

#[test]
#[should_panic(expected: ('Unauthorized user',))]
fn test_deauthorized_user_cannot_create_policy() {
    let (factory, _) = deploy_factory();

    // Authorize then deauthorize user
    start_prank(CheatTarget::One(factory.contract_address), OWNER());
    factory.add_authorized_user(USER1());
    factory.remove_authorized_user(USER1());
    stop_prank(CheatTarget::One(factory.contract_address));

    // Try to create policy after deauthorization - should fail
    start_prank(CheatTarget::One(factory.contract_address), USER1());
    factory.create_policy(USER1(), 'health_insurance', 365_u64, ASSET(), 'salt1');
}
