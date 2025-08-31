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

    
    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.paused.write(false);
        self.proposal_count.write(0);
    }

    fn only_owner(self: @ContractState) {
        let caller = get_caller_address();
        let owner = self.owner.read();
        assert(caller == owner, 'Only owner can call this function');
    }

    fn only_unpaused(self: @ContractState) {
        let is_paused = self.paused.read();
        assert(!is_paused, 'Contract is paused');
    }

    #[abi(embed_v0)]
    impl GovernanceImpl of super::IGovernance<ContractState> {
        fn create_proposal(
            ref self: ContractState,
            title: felt252,
            description: felt252,
            target: ContractAddress,
            calldata: Span<felt252>
        ) -> u256 {
            only_unpaused(@self);
            
            let caller = get_caller_address();
            let proposal_id = self.proposal_count.read() + 1;
            let timestamp = get_block_timestamp();
            
            let proposal = Proposal {
                id: proposal_id,
                title,
                description,
                proposer: caller,
                target,
                calldata,
                created_at: timestamp,
                executed: false,
                votes_for: 0,
                votes_against: 0,
            };
            
            self.proposals.write(proposal_id, proposal);
            self.proposal_count.write(proposal_id);
            
            self.emit(ProposalCreated {
                proposal_id,
                proposer: caller,
                title,
                timestamp,
            });
            
            proposal_id
        }

        fn vote(ref self: ContractState, proposal_id: u256, support: bool) {
            only_unpaused(@self);
            
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            
            // Check if proposal exists
            let proposal = self.proposals.read(proposal_id);
            assert(proposal.id != 0, 'Proposal does not exist');
            assert(!proposal.executed, 'Proposal already executed');
            
            // Check if user has already voted
            let existing_vote = self.votes.read((proposal_id, caller));
            assert(existing_vote.voter.is_zero(), 'Already voted');
            
            // Record the vote
            let vote = Vote {
                voter: caller,
                support,
                timestamp,
            };
            self.votes.write((proposal_id, caller), vote);
            
            // Update proposal vote counts
            let mut updated_proposal = proposal;
            if support {
                updated_proposal.votes_for += 1;
            } else {
                updated_proposal.votes_against += 1;
            }
            self.proposals.write(proposal_id, updated_proposal);
            
            self.emit(VoteCast {
                proposal_id,
                voter: caller,
                support,
                timestamp,
            });
        }
