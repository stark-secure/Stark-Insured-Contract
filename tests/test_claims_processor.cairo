use snforge_std::{CheatTarget, ContractClassTrait, declare, start_prank, stop_prank};
use stark_insured::constants;
use stark_insured::interfaces::{
    IClaimsProcessorDispatcher, IClaimsProcessorDispatcherTrait, IPolicyManagerDispatcher,
    IPolicyManagerDispatcherTrait,
};
use starknet::{ContractAddress, contract_address_const};

fn setup_contracts() -> (ContractAddress, IClaimsProcessorDispatcher, IPolicyManagerDispatcher) {
    let owner = contract_address_const::<'owner'>();
    let token = contract_address_const::<'token'>();

    // Deploy PolicyManager
    let policy_contract = declare("PolicyManager");
    let policy_address = policy_contract.deploy(@array![owner.into(), token.into()]).unwrap();
    let policy_manager = IPolicyManagerDispatcher { contract_address: policy_address };

    // Deploy RiskPool (mock)
    let pool_address = contract_address_const::<'pool'>();

    // Deploy ClaimsProcessor
    let claims_contract = declare("ClaimsProcessor");
    let claims_address = claims_contract
        .deploy(@array![owner.into(), policy_address.into(), pool_address.into()])
        .unwrap();
    let claims_processor = IClaimsProcessorDispatcher { contract_address: claims_address };

    (claims_address, claims_processor, policy_manager)
}

#[test]
fn test_submit_claim() {
    let (contract_address, claims_processor, policy_manager) = setup_contracts();
    let holder = contract_address_const::<'holder'>();

    // First create a policy
    start_prank(CheatTarget::One(policy_manager.contract_address), holder);
    let policy_id = policy_manager
        .create_policy(holder, 1000000000000000000000, 86400 * 365, constants::HEALTH_INSURANCE);
    stop_prank(CheatTarget::One(policy_manager.contract_address));

    // Submit claim
    start_prank(CheatTarget::One(contract_address), holder);
    let claim_id = claims_processor
        .submit_claim(policy_id, 500000000000000000000, // 500 tokens
        'evidence_hash');

    assert(claim_id == 1, 'Claim ID should be 1');

    let claim = claims_processor.get_claim(claim_id);
    assert(claim.claimant == holder, 'Wrong claimant');
    assert(claim.amount == 500000000000000000000, 'Wrong claim amount');
    assert(claim.status == constants::CLAIM_PENDING, 'Wrong claim status');

    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_cooldown_period() {
    let (contract_address, claims_processor, _) = setup_contracts();
    let holder = contract_address_const::<'holder'>();

    start_prank(CheatTarget::One(contract_address), holder);

    // First claim should be allowed
    assert(claims_processor.can_submit_claim(holder) == true, 'Should allow first claim');

    stop_prank(CheatTarget::One(contract_address));
}

#[test]
#[should_panic(expected: ('Invalid claim amount',))]
fn test_invalid_claim_amount() {
    let (contract_address, claims_processor, policy_manager) = setup_contracts();
    let holder = contract_address_const::<'holder'>();

    // Create policy
    start_prank(CheatTarget::One(policy_manager.contract_address), holder);
    let policy_id = policy_manager
        .create_policy(holder, 1000000000000000000000, 86400 * 365, constants::HEALTH_INSURANCE);
    stop_prank(CheatTarget::One(policy_manager.contract_address));

    // Submit invalid claim
    start_prank(CheatTarget::One(contract_address), holder);
    claims_processor.submit_claim(policy_id, 0, // Invalid amount
    'evidence_hash');
    stop_prank(CheatTarget::One(contract_address));
}
