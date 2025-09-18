use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_block_timestamp,
    stop_cheat_block_timestamp, spy_events, EventSpyAssertionsTrait,
};

use oracle_integration::oracle_integration::{
    IOracleIntegrationDispatcher, IOracleIntegrationDispatcherTrait,
};

fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn ORACLE_1() -> ContractAddress {
    contract_address_const::<'oracle1'>()
}

fn ORACLE_2() -> ContractAddress {
    contract_address_const::<'oracle2'>()
}

fn deploy_contract() -> IOracleIntegrationDispatcher {
    let contract = declare("OracleIntegration").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![OWNER().into()]).unwrap();
    IOracleIntegrationDispatcher { contract_address }
}

#[test]
fn test_submit_valid_data() {
    let contract = deploy_contract();

    // Add trusted oracle
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.add_trusted_oracle(ORACLE_1());
    stop_cheat_caller_address(contract.contract_address);

    // Submit data
    let timestamp = get_block_timestamp() - 300; // 5 minutes ago
    let payload = 'HURRICANE_CATEGORY_2';

    start_cheat_caller_address(contract.contract_address, ORACLE_1());
    contract.submit_data(ORACLE_1(), payload, timestamp);
    stop_cheat_caller_address(contract.contract_address);

    // Verify data was stored
    let (stored_payload, stored_timestamp) = contract.get_oracle_data(ORACLE_1());
    assert(stored_payload == payload, 'Payload mismatch');
    assert(stored_timestamp == timestamp, 'Timestamp mismatch');
}

#[test]
#[should_panic(expected: ('Oracle not trusted',))]
fn test_submit_data_untrusted_oracle() {
    let contract = deploy_contract();

    let timestamp = get_block_timestamp() - 300;
    let payload = 'TEST_DATA';

    // Try to submit data from untrusted oracle
    start_cheat_caller_address(contract.contract_address, ORACLE_1());
    contract.submit_data(ORACLE_1(), payload, timestamp);
}

#[test]
#[should_panic(expected: ('Future timestamp not allowed',))]
fn test_submit_future_timestamp() {
    let contract = deploy_contract();

    // Add trusted oracle
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.add_trusted_oracle(ORACLE_1());
    stop_cheat_caller_address(contract.contract_address);

    // Try to submit data with future timestamp
    let future_timestamp = get_block_timestamp() + 3600; // 1 hour in future
    let payload = 'TEST_DATA';

    start_cheat_caller_address(contract.contract_address, ORACLE_1());
    contract.submit_data(ORACLE_1(), payload, future_timestamp);
}

#[test]
#[should_panic(expected: ('Data too old',))]
fn test_submit_stale_data() {
    let contract = deploy_contract();

    // Add trusted oracle
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.add_trusted_oracle(ORACLE_1());
    stop_cheat_caller_address(contract.contract_address);

    // Try to submit very old data (2 hours ago, beyond default 1 hour window)
    let old_timestamp = get_block_timestamp() - 7200;
    let payload = 'OLD_DATA';

    start_cheat_caller_address(contract.contract_address, ORACLE_1());
    contract.submit_data(ORACLE_1(), payload, old_timestamp);
}

#[test]
#[should_panic(expected: ('Replay attack detected',))]
fn test_replay_protection() {
    let contract = deploy_contract();

    // Add trusted oracle
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.add_trusted_oracle(ORACLE_1());
    stop_cheat_caller_address(contract.contract_address);

    let timestamp = get_block_timestamp() - 300;
    let payload = 'TEST_DATA';

    start_cheat_caller_address(contract.contract_address, ORACLE_1());

    // Submit data first time (should succeed)
    contract.submit_data(ORACLE_1(), payload, timestamp);

    // Try to submit same timestamp again (should fail)
    contract.submit_data(ORACLE_1(), payload, timestamp);
}

#[test]
fn test_validate_data_success() {
    let contract = deploy_contract();

    // Add trusted oracle
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.add_trusted_oracle(ORACLE_1());
    stop_cheat_caller_address(contract.contract_address);

    // Submit fresh data
    let timestamp = get_block_timestamp() - 300;
    let payload = 'VALID_DATA';

    start_cheat_caller_address(contract.contract_address, ORACLE_1());
    contract.submit_data(ORACLE_1(), payload, timestamp);
    stop_cheat_caller_address(contract.contract_address);

    // Validate data
    let claim_id = 'test_claim_123';
    let is_valid = contract.validate_data(ORACLE_1(), claim_id);
    assert(is_valid, 'Data should be valid');
}

#[test]
fn test_validate_data_untrusted_oracle() {
    let contract = deploy_contract();

    let claim_id = 'test_claim_123';
    let is_valid = contract.validate_data(ORACLE_1(), claim_id);
    assert(!is_valid, 'Untrusted oracle should be invalid');
}

#[test]
fn test_trigger_claim_success() {
    let contract = deploy_contract();

    // Add trusted oracle
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.add_trusted_oracle(ORACLE_1());
    stop_cheat_caller_address(contract.contract_address);

    let claim_id = 'test_claim_456';

    // Trigger claim as trusted oracle
    start_cheat_caller_address(contract.contract_address, ORACLE_1());
    contract.trigger_claim(claim_id);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Claim already triggered',))]
fn test_prevent_double_trigger() {
    let contract = deploy_contract();

    // Add trusted oracle
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.add_trusted_oracle(ORACLE_1());
    stop_cheat_caller_address(contract.contract_address);

    let claim_id = 'test_claim_789';

    start_cheat_caller_address(contract.contract_address, ORACLE_1());

    // Trigger claim first time (should succeed)
    contract.trigger_claim(claim_id);

    // Try to trigger same claim again (should fail)
    contract.trigger_claim(claim_id);
}

#[test]
fn test_event_emissions() {
    let contract = deploy_contract();
    let mut spy = spy_events();

    // Add trusted oracle
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.add_trusted_oracle(ORACLE_1());
    stop_cheat_caller_address(contract.contract_address);

    // Submit data and check event
    let timestamp = get_block_timestamp() - 300;
    let payload = 'EVENT_TEST_DATA';

    start_cheat_caller_address(contract.contract_address, ORACLE_1());
    contract.submit_data(ORACLE_1(), payload, timestamp);
    stop_cheat_caller_address(contract.contract_address);

    // Check OracleUpdated event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    oracle_integration::oracle_integration::Event::OracleUpdated(
                        oracle_integration::oracle_integration::OracleUpdated {
                            oracle_id: ORACLE_1(), payload: payload, timestamp: timestamp,
                        },
                    ),
                ),
            ],
        );
}

// Helper functions for testing
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
