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

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_create_proposal_when_paused() {
    let governance = deploy_governance();

    // Pause the contract
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.pause();
    stop_prank(CheatTarget::One(governance.contract_address));

    // Try to create proposal when paused
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    governance
        .create_proposal(
            'Test Proposal',
            'Test Description',
            contract_address_const::<'target'>(),
            array![].span(),
        );
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_vote_when_paused() {
    let governance = deploy_governance();

    // Create a proposal first
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    let proposal_id = governance
        .create_proposal(
            'Test Proposal',
            'Test Description',
            contract_address_const::<'target'>(),
            array![].span(),
        );
    stop_prank(CheatTarget::One(governance.contract_address));

    // Pause the contract
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.pause();
    stop_prank(CheatTarget::One(governance.contract_address));

    // Try to vote when paused
    start_prank(CheatTarget::One(governance.contract_address), USER2());
    governance.vote(proposal_id, true);
}


#[test]
fn test_normal_to_paused_to_normal_flow() {
    let governance = deploy_governance();

    // Normal operation: create proposal
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    let proposal_id = governance
        .create_proposal(
            'Test Proposal',
            'Test Description',
            contract_address_const::<'target'>(),
            array![].span(),
        );
    stop_prank(CheatTarget::One(governance.contract_address));

    // Pause the contract
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.pause();
    stop_prank(CheatTarget::One(governance.contract_address));

    // Unpause the contract
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.unpause();
    stop_prank(CheatTarget::One(governance.contract_address));

    // Normal operation should work again: vote
    start_prank(CheatTarget::One(governance.contract_address), USER2());
    governance.vote(proposal_id, true);
    stop_prank(CheatTarget::One(governance.contract_address));
}

#[test]
fn test_proposal_creation_and_voting_when_unpaused() {
    let governance = deploy_governance();

    // Create proposal
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    let proposal_id = governance
        .create_proposal(
            'Test Proposal',
            'Test Description',
            contract_address_const::<'target'>(),
            array![].span(),
        );
    stop_prank(CheatTarget::One(governance.contract_address));

    // Vote on proposal
    start_prank(CheatTarget::One(governance.contract_address), USER2());
    governance.vote(proposal_id, true);
    stop_prank(CheatTarget::One(governance.contract_address));

    // Should work without issues when not paused
    assert(proposal_id == 1, 'Proposal ID should be 1');
}

#[test]
#[should_panic(expected: ('Already paused',))]
fn test_double_pause_attempt() {
    let governance = deploy_governance();

    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.pause();
    // Try to pause again - should fail
    governance.pause();
}

#[test]
#[should_panic(expected: ('Not paused',))]
fn test_unpause_when_not_paused() {
    let governance = deploy_governance();

    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    // Try to unpause when not paused - should fail
    governance.unpause();
}

#[test]
fn test_ownership_transfer() {
    let governance = deploy_governance();

    // Transfer ownership
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.transfer_ownership(USER1());
    stop_prank(CheatTarget::One(governance.contract_address));

    // New owner should be able to pause
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    governance.pause();
    assert(governance.is_paused(), 'Should be paused by new owner');
    stop_prank(CheatTarget::One(governance.contract_address));

    // Old owner should not be able to unpause
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    let result = std::panic::catch_unwind( || {
        governance.unpause();
    });
    assert(result.is_err(), 'Old owner should not be able to unpause');
}

#[test]
#[should_panic(expected: ('New owner cannot be zero',))]
fn test_transfer_ownership_to_zero_address() {
    let governance = deploy_governance();

    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.transfer_ownership(contract_address_const::<0>());
}


#[test]
fn test_multiple_proposals_with_pause_scenarios() {
    let governance = deploy_governance();

    // Create first proposal
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    let proposal_id_1 = governance
        .create_proposal(
            'Proposal 1', 'First proposal', contract_address_const::<'target1'>(), array![].span(),
        );
    stop_prank(CheatTarget::One(governance.contract_address));

    // Vote on first proposal
    start_prank(CheatTarget::One(governance.contract_address), USER2());
    governance.vote(proposal_id_1, true);
    stop_prank(CheatTarget::One(governance.contract_address));

    // Pause the contract
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.pause();
    stop_prank(CheatTarget::One(governance.contract_address));

    // Unpause and create second proposal
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.unpause();
    stop_prank(CheatTarget::One(governance.contract_address));

    start_prank(CheatTarget::One(governance.contract_address), USER1());
    let proposal_id_2 = governance
        .create_proposal(
            'Proposal 2', 'Second proposal', contract_address_const::<'target2'>(), array![].span(),
        );
    stop_prank(CheatTarget::One(governance.contract_address));

    // Both proposals should exist
    assert(proposal_id_1 == 1, 'First proposal ID should be 1');
    assert(proposal_id_2 == 2, 'Second proposal ID should be 2');

    // Execute first proposal (should work)
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    governance.execute_proposal(proposal_id_1);
    stop_prank(CheatTarget::One(governance.contract_address));
}


#[test]
fn test_complex_voting_scenario_with_pause() {
    let governance = deploy_governance();

    // Create proposal
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    let proposal_id = governance
        .create_proposal(
            'Complex Proposal',
            'A proposal for complex testing',
            contract_address_const::<'target'>(),
            array![].span(),
        );
    stop_prank(CheatTarget::One(governance.contract_address));

    // First user votes in favor
    start_prank(CheatTarget::One(governance.contract_address), USER2());
    governance.vote(proposal_id, true);
    stop_prank(CheatTarget::One(governance.contract_address));

    // Pause before more voting
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.pause();
    stop_prank(CheatTarget::One(governance.contract_address));

    // Unpause and continue voting
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.unpause();
    stop_prank(CheatTarget::One(governance.contract_address));

    // Additional user votes (different user from before)
    let user3 = contract_address_const::<'user3'>();
    start_prank(CheatTarget::One(governance.contract_address), user3);
    governance.vote(proposal_id, false);
    stop_prank(CheatTarget::One(governance.contract_address));

    // Proposal should still be executable since we have more votes for than against
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    governance.execute_proposal(proposal_id);
    stop_prank(CheatTarget::One(governance.contract_address));
}

#[test]
#[should_panic(expected: ('Already voted',))]
fn test_double_voting_prevention() {
    let governance = deploy_governance();

    // Create proposal
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    let proposal_id = governance
        .create_proposal(
            'Test Proposal',
            'Test Description',
            contract_address_const::<'target'>(),
            array![].span(),
        );
    stop_prank(CheatTarget::One(governance.contract_address));

    // Vote once
    start_prank(CheatTarget::One(governance.contract_address), USER2());
    governance.vote(proposal_id, true);

    // Try to vote again - should fail
    governance.vote(proposal_id, false);
}

#[test]
#[should_panic(expected: ('Proposal does not exist',))]
fn test_vote_on_nonexistent_proposal() {
    let governance = deploy_governance();

    start_prank(CheatTarget::One(governance.contract_address), USER1());
    governance.vote(999, true); // Non-existent proposal ID
}

#[test]
#[should_panic(expected: ('Proposal rejected',))]
fn test_execute_rejected_proposal() {
    let governance = deploy_governance();

    // Create proposal
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    let proposal_id = governance
        .create_proposal(
            'Rejected Proposal',
            'This will be rejected',
            contract_address_const::<'target'>(),
            array![].span(),
        );
    stop_prank(CheatTarget::One(governance.contract_address));

    // Vote against
    start_prank(CheatTarget::One(governance.contract_address), USER2());
    governance.vote(proposal_id, false);
    stop_prank(CheatTarget::One(governance.contract_address));

    // Try to execute rejected proposal
    start_prank(CheatTarget::One(governance.contract_address), USER1());
    governance.execute_proposal(proposal_id);
}

#[test]
fn test_pause_state_persistence() {
    let governance = deploy_governance();

    // Verify initial state
    assert(!governance.is_paused(), 'Should start unpaused');

    // Pause and verify
    start_prank(CheatTarget::One(governance.contract_address), OWNER());
    governance.pause();
    assert(governance.is_paused(), 'Should be paused');

    // State should persist across different function calls
    assert(governance.is_paused(), 'Should still be paused');
    assert(governance.get_owner() == OWNER(), 'Owner should be unchanged');

    // Unpause and verify
    governance.unpause();
    assert(!governance.is_paused(), 'Should be unpaused');
    stop_prank(CheatTarget::One(governance.contract_address));
}
