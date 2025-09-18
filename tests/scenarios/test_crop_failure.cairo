use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};

use oracle_integration::oracle_integration::{
    IOracleIntegrationDispatcher, IOracleIntegrationDispatcherTrait,
};

use claims_processor::claims_processor::{
    IClaimsProcessorDispatcher, IClaimsProcessorDispatcherTrait,
};

fn OWNER() -> ContractAddress { contract_address_const::<'owner2'>() }
fn FARMER() -> ContractAddress { contract_address_const::<'farmer'>() }
fn ORACLE() -> ContractAddress { contract_address_const::<'weather_oracle'>() }

fn deploy_oracle() -> IOracleIntegrationDispatcher {
    let contract = declare("OracleIntegration").unwrap().contract_class();
    let (addr, _) = contract.deploy(@array![OWNER().into()]).unwrap();
    IOracleIntegrationDispatcher { contract_address: addr }
}

#[test]
fn test_crop_failure_drought_payout() {
    let oracle = deploy_oracle();

    // Add trusted weather oracle and submit drought event
    start_cheat_caller_address(oracle.contract_address, OWNER());
    oracle.add_trusted_oracle(ORACLE());
    stop_cheat_caller_address(oracle.contract_address);

    let ts = get_block_timestamp() - 120;
    start_cheat_caller_address(oracle.contract_address, ORACLE());
    oracle.submit_data(ORACLE(), 'CROP_DROUGHT_SEVERE', ts);
    stop_cheat_caller_address(oracle.contract_address);

    assert(oracle.validate_data(ORACLE(), 77), 'Weather event should be valid');

    // Deploy mocks and claims processor
    let policy_mgr = declare("MockPolicyManager").unwrap().contract_class().deploy(@array![OWNER().into()]).unwrap().0;
    let pool = declare("MockRiskPool").unwrap().contract_class().deploy(@array![OWNER().into()]).unwrap().0;
    let claims = declare("ClaimsProcessor").unwrap().contract_class().deploy(@array![OWNER().into(), policy_mgr.into(), pool.into()]).unwrap().0;

    // Seed pool with sufficient funds
    start_cheat_caller_address(pool, OWNER());
    mock_risk_pool::mock_risk_pool::IAdminDispatcher { contract_address: pool }.seed_balance(800000000000000000000);
    stop_cheat_caller_address(pool);

    // Create a crop policy for FARMER
    let policy = mock_policy_manager::mock_policy_manager::IPolicyManagerDispatcher { contract_address: policy_mgr };
    let policy_id = policy.create_policy(FARMER(), 600000000000000000000, 86400 * 90, 9_u8);

    // Farmer submits claim due to drought
    start_cheat_caller_address(claims, FARMER());
    let claim_id = IClaimsProcessorDispatcher { contract_address: claims }.submit_claim(policy_id, 500000000000000000000, 'EV_CROP_JSON');
    stop_cheat_caller_address(claims);

    // Owner approves claim
    start_cheat_caller_address(claims, OWNER());
    IClaimsProcessorDispatcher { contract_address: claims }.process_claim(claim_id, true);
    stop_cheat_caller_address(claims);

    // Check pool decreased and farmer credited in mock balance
    let pool_after = mock_risk_pool::mock_risk_pool::IRiskPoolDispatcher { contract_address: pool }.get_balance();
    assert(pool_after == 300000000000000000000, 'Pool decreased by 500e18');
    let farmer_credit = mock_risk_pool::mock_risk_pool::IRiskPoolDispatcher { contract_address: pool }.get_user_balance(FARMER());
    assert(farmer_credit == 500000000000000000000, 'Farmer credited');
}


