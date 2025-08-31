use starknet::ContractAddress;

#[starknet::interface]
trait IGovernance<TContractState> {
    // Core governance functions
    fn create_proposal(ref self: TContractState, title: felt252, description: felt252, target: ContractAddress, calldata: Span<felt252>) -> u256;
    fn vote(ref self: TContractState, proposal_id: u256, support: bool);
    fn execute_proposal(ref self: TContractState, proposal_id: u256);
    
    // Pause mechanism functions
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
    
    // Admin functions
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}

#[starknet::contract]
mod Governance {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        paused: bool,
        proposal_count: u256,
        proposals: LegacyMap<u256, Proposal>,
        votes: LegacyMap<(u256, ContractAddress), Vote>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Proposal {
        id: u256,
        title: felt252,
        description: felt252,
        proposer: ContractAddress,
        target: ContractAddress,
        calldata: Span<felt252>,
        created_at: u64,
        executed: bool,
        votes_for: u256,
        votes_against: u256,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Vote {
        voter: ContractAddress,
        support: bool,
        timestamp: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProposalCreated: ProposalCreated,
        VoteCast: VoteCast,
        ProposalExecuted: ProposalExecuted,
        Paused: Paused,
        Unpaused: Unpaused,
        OwnershipTransferred: OwnershipTransferred,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalCreated {
        #[key]
        proposal_id: u256,
        proposer: ContractAddress,
        title: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct VoteCast {
        #[key]
        proposal_id: u256,
        #[key]
        voter: ContractAddress,
        support: bool,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalExecuted {
        #[key]
        proposal_id: u256,
        executor: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Paused {
        admin: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Unpaused {
        admin: ContractAddress,
        timestamp: u64,
    }
