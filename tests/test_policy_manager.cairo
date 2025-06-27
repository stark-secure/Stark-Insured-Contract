use snforge_std::{CheatTarget, ContractClassTrait, declare, start_prank, stop_prank};
use stark_insured::constants;
use stark_insured::interfaces::{IPolicyManagerDispatcher, IPolicyManagerDispatcherTrait};
use starknet::{ContractAddress, contract_address_const};

fn deploy_policy_manager() -> (ContractAddress, IPolicyManagerDispatcher) {
    let contract = declare("PolicyManager");
    let owner = contract_address_const::<'owner'>();
    let token = contract_address_const::<'token'>();

    let contract_address = contract.deploy(@array![owner.into(), token.into()]).unwrap();
    let dispatcher = IPolicyManagerDispatcher { contract_address };

    (contract_address, dispatcher)
}

#[test]
fn test_create_policy() {
    let (contract_address, policy_manager) = deploy_policy_manager();
    let holder = contract_address_const::<'holder'>();

    start_prank(CheatTarget::One(contract_address), holder);

    let policy_id = policy_manager
        .create_policy(
            holder,
            1000000000000000000000, // 1000 tokens
            86400 * 365, // 1 year
            constants::HEALTH_INSURANCE,
        );

    assert(policy_id == 1, 'Policy ID should be 1');

    let policy = policy_manager.get_policy(policy_id);
    assert(policy.holder == holder, 'Wrong policy holder');
    assert(policy.coverage_amount == 1000000000000000000000, 'Wrong coverage amount');
    assert(policy.policy_type == constants::HEALTH_INSURANCE, 'Wrong policy type');
    assert(policy.is_active == true, 'Policy should be active');

    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_calculate_premium() {
    let (_, policy_manager) = deploy_policy_manager();

    let premium = policy_manager
        .calculate_premium(
            1000000000000000000000, // 1000 tokens
            86400 * 365, // 1 year
            constants::HEALTH_INSURANCE,
        );

    assert(premium > 0, 'Premium should be greater than 0');
}

#[test]
fn test_policy_counter() {
    let (contract_address, policy_manager) = deploy_policy_manager();
    let holder = contract_address_const::<'holder'>();

    start_prank(CheatTarget::One(contract_address), holder);

    assert(policy_manager.get_total_policies() == 0, 'Initial count should be 0');

    policy_manager
        .create_policy(holder, 1000000000000000000000, 86400 * 365, constants::HEALTH_INSURANCE);

    assert(policy_manager.get_total_policies() == 1, 'Count should be 1 after creation');

    stop_prank(CheatTarget::One(contract_address));
}

#[test]
#[should_panic(expected: ('Invalid coverage amount',))]
fn test_invalid_coverage_amount() {
    let (contract_address, policy_manager) = deploy_policy_manager();
    let holder = contract_address_const::<'holder'>();

    start_prank(CheatTarget::One(contract_address), holder);

    policy_manager
        .create_policy(holder, 0, // Invalid amount
        86400 * 365, constants::HEALTH_INSURANCE);

    stop_prank(CheatTarget::One(contract_address));
}
