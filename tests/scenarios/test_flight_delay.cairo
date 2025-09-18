use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, spy_events, EventSpyAssertionsTrait,
};

use oracle_integration::oracle_integration::{
    IOracleIntegrationDispatcher, IOracleIntegrationDispatcherTrait,
};

use claims_processor::claims_processor::{
    IClaimsProcessorDispatcher, IClaimsProcessorDispatcherTrait,
};

fn OWNER() -> ContractAddress { contract_address_const::<'owner'>() }
fn USER() -> ContractAddress { contract_address_const::<'user'>() }
fn ORACLE() -> ContractAddress { contract_address_const::<'oracle'>() }

fn deploy_oracle() -> IOracleIntegrationDispatcher {
    let contract = declare("OracleIntegration").unwrap().contract_class();
    let (addr, _) = contract.deploy(@array![OWNER().into()]).unwrap();
    IOracleIntegrationDispatcher { contract_address: addr }
}

fn deploy_mock_policy() -> ContractAddress {
    let contract = declare("MockPolicyManager").unwrap().contract_class();
    let (addr, _) = contract.deploy(@array![OWNER().into()]).unwrap();
    addr
}

fn deploy_mock_pool() -> ContractAddress {
    let contract = declare("MockRiskPool").unwrap().contract_class();
    let (addr, _) = contract.deploy(@array![OWNER().into()]).unwrap();
    addr
}

fn deploy_claims(policy_mgr: ContractAddress, pool: ContractAddress) -> IClaimsProcessorDispatcher {
    let contract = declare("ClaimsProcessor").unwrap().contract_class();
    let (addr, _) = contract.deploy(@array![OWNER().into(), policy_mgr.into(), pool.into()]).unwrap();
    IClaimsProcessorDispatcher { contract_address: addr }
}

#[test]
fn test_flight_delay_claim_flow() {
    // Deploy components
    let oracle = deploy_oracle();
    let policy_mgr = deploy_mock_policy();
    let pool = deploy_mock_pool();

    // Seed pool balance
    start_cheat_caller_address(pool, OWNER());
    mock_risk_pool::mock_risk_pool::IAdminDispatcher { contract_address: pool }.seed_balance(1000000000000000000000);
    stop_cheat_caller_address(pool);

    // Create a policy for USER
    let policy = mock_policy_manager::mock_policy_manager::IPolicyManagerDispatcher { contract_address: policy_mgr };
    let policy_id = policy.create_policy(USER(), 500000000000000000000, 86400 * 30, 7_u8);

    // Oracle: add trusted and submit flight delay event
    start_cheat_caller_address(oracle.contract_address, OWNER());
    oracle.add_trusted_oracle(ORACLE());
    stop_cheat_caller_address(oracle.contract_address);

    let timestamp = get_block_timestamp() - 60;
    start_cheat_caller_address(oracle.contract_address, ORACLE());
    oracle.submit_data(ORACLE(), 'FLIGHT_DELAY_4H', timestamp);
    stop_cheat_caller_address(oracle.contract_address);

    // Validate oracle data is fresh and trusted
    assert(oracle.validate_data(ORACLE(), 1), 'Oracle data should validate');

    // Deploy claims processor
    let claims = deploy_claims(policy_mgr, pool);

    // User submits claim with evidence hash representing JSON-equivalent
    start_cheat_caller_address(claims.contract_address, USER());
    let claim_id = claims.submit_claim(policy_id, 400000000000000000000, 'EV_FLIGHT_JSON');
    stop_cheat_caller_address(claims.contract_address);

    // Owner processes claim based on oracle validation
    let event_spy = spy_events(claims.contract_address);
    start_cheat_caller_address(claims.contract_address, OWNER());
    claims.process_claim(claim_id, true);
    stop_cheat_caller_address(claims.contract_address);

    // Assert event emitted and pool balance reduced
    let events = event_spy.get_events();
    events.assert_count(1);

    // Pool should have decreased by payout amount
    let pool_balance_after = mock_risk_pool::mock_risk_pool::IRiskPoolDispatcher { contract_address: pool }.get_balance();
    assert(pool_balance_after == 600000000000000000000, 'Pool should decrease by 400e18');

    // Recipient (USER) received payout in mock pool balance
    let user_pool_balance = mock_risk_pool::mock_risk_pool::IRiskPoolDispatcher { contract_address: pool }.get_user_balance(USER());
    assert(user_pool_balance == 400000000000000000000, 'User payout credited');
}


