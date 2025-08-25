use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
use cross_chain_bridge::{ICrossChainBridgeDispatcher, ICrossChainBridgeDispatcherTrait};

fn deploy_bridge() -> ICrossChainBridgeDispatcher {
    let contract = declare("CrossChainBridge").unwrap();
    let owner = contract_address_const::<'owner'>();
    
    let mut trusted_chains = ArrayTrait::new();
    trusted_chains.append(1); // Ethereum mainnet
    trusted_chains.append(5); // Goerli testnet
    
    let (contract_address, _) = contract.deploy(@array![owner.into(), trusted_chains.span().into()]).unwrap();
    ICrossChainBridgeDispatcher { contract_address }
}

#[test]
fn test_receive_valid_message() {
    let bridge = deploy_bridge();
    
    // Prepare test data
    let source_chain = 1; // Ethereum mainnet
    let message_hash = 'test_message_hash_123';
    let policy_id = 'policy_123';
    let user_low = 0x1234567890abcdef;
    let user_high = 0x0;
    
    let mut payload = ArrayTrait::new();
    payload.append(policy_id);
    payload.append(user_low);
    payload.append(user_high);
    payload.append('claim_data_1');
    payload.append('claim_data_2');
    
    // Should succeed with valid message
    bridge.receive_message(source_chain, message_hash, payload.span());
    
    // Verify message is marked as processed
    assert(bridge.is_message_processed(message_hash), 'Message should be processed');
}

#[test]
#[should_panic(expected: ('Untrusted source chain',))]
fn test_reject_untrusted_chain() {
    let bridge = deploy_bridge();
    
    let untrusted_chain = 999; // Not in trusted chains
    let message_hash = 'test_message_hash_456';
    
    let mut payload = ArrayTrait::new();
    payload.append('policy_123');
    payload.append(0x1234567890abcdef);
    payload.append(0x0);
    
    // Should panic with untrusted chain
    bridge.receive_message(untrusted_chain, message_hash, payload.span());
}

#[test]
#[should_panic(expected: ('Message already processed',))]
fn test_replay_protection() {
    let bridge = deploy_bridge();
    
    let source_chain = 1;
    let message_hash = 'duplicate_message_hash';
    
    let mut payload = ArrayTrait::new();
    payload.append('policy_123');
    payload.append(0x1234567890abcdef);
    payload.append(0x0);
    payload.append('claim_data');
    
    // First submission should succeed
    bridge.receive_message(source_chain, message_hash, payload.span());
    
    // Second submission should panic (replay protection)
    bridge.receive_message(source_chain, message_hash, payload.span());
}

#[test]
#[should_panic(expected: ('Invalid payload length',))]
fn test_invalid_payload_length() {
    let bridge = deploy_bridge();
    
    let source_chain = 1;
    let message_hash = 'short_payload_message';
    
    // Payload too short (needs at least 3 elements)
    let mut payload = ArrayTrait::new();
    payload.append('policy_123');
    payload.append(0x1234567890abcdef);
    // Missing user_high and claim data
    
    bridge.receive_message(source_chain, message_hash, payload.span());
}

#[test]
fn test_get_trusted_chains() {
    let bridge = deploy_bridge();
    
    let chains = bridge.get_trusted_chains();
    assert(chains.len() == 2, 'Should have 2 trusted chains');
    assert(*chains.at(0) == 1, 'First chain should be Ethereum');
    assert(*chains.at(1) == 5, 'Second chain should be Goerli');
}

#[test]
fn test_message_not_processed_initially() {
    let bridge = deploy_bridge();
    
    let message_hash = 'unprocessed_message';
    assert(!bridge.is_message_processed(message_hash), 'Message should not be processed initially');
}
