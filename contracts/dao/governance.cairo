#[starknet::contract]
mod DAOGovernance {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use stark_insured::errors::GovernanceErrors;
    use stark_insured::events::{ProposalCreated, ProposalExecuted, VoteCast};
    use stark_insured::interfaces::{IDAOGovernance, Proposal, IPauseable};
    use stark_insured::{constants, utils};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        proposals: LegacyMap<u256, Proposal>,
        proposal_counter: u256,
        governance_token: ContractAddress,
        user_votes: LegacyMap<(u256, ContractAddress), bool>,
        user_voting_power: LegacyMap<(u256, ContractAddress), u256>,
        paused: bool,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProposalCreated: ProposalCreated,
        VoteCast: VoteCast,
        ProposalExecuted: ProposalExecuted,
        Paused: Paused,
        Unpaused: Unpaused,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct Paused {}

    #[derive(Drop, starknet::Event)]
    struct Unpaused {}

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, governance_token: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.governance_token.write(governance_token);
        self.proposal_counter.write(0);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl DAOGovernanceImpl of IDAOGovernance<ContractState> {
        fn create_proposal(
            ref self: ContractState,
            title: felt252,
            description: felt252,
            execution_data: Span<felt252>,
        ) -> u256 {
            self.only_unpaused();

            let caller = get_caller_address();
            let voting_power = self.get_voting_power(caller);

            assert(
                voting_power >= constants::MIN_PROPOSAL_STAKE, GovernanceErrors::INSUFFICIENT_STAKE,
            );

            let proposal_id = self.proposal_counter.read() + 1;
            self.proposal_counter.write(proposal_id);

            let current_time = get_block_timestamp();
            let proposal = Proposal {
                id: proposal_id,
                proposer: caller,
                title,
                description,
                votes_for: 0,
                votes_against: 0,
                start_time: current_time,
                end_time: current_time + constants::VOTING_PERIOD,
                executed: false,
            };

            self.proposals.write(proposal_id, proposal);

            self.emit(ProposalCreated { proposal_id, proposer: caller, title, description });

            proposal_id
        }

        fn vote(ref self: ContractState, proposal_id: u256, support: bool, voting_power: u256) {
            self.only_unpaused();

            let caller = get_caller_address();
            let proposal = self.get_proposal(proposal_id);

            let current_time = get_block_timestamp();
            assert(current_time <= proposal.end_time, GovernanceErrors::VOTING_PERIOD_ENDED);

            assert(!self.user_votes.read((proposal_id, caller)), 'Already voted');

            let max_voting_power = self.get_voting_power(caller);
            assert(voting_power <= max_voting_power, 'Invalid voting power');

            self.user_votes.write((proposal_id, caller), true);
            self.user_voting_power.write((proposal_id, caller), voting_power);

            let mut updated_proposal = proposal;
            if support {
                updated_proposal.votes_for += voting_power;
            } else {
                updated_proposal.votes_against += voting_power;
            }
            self.proposals.write(proposal_id, updated_proposal);

            self.emit(VoteCast { proposal_id, voter: caller, support, voting_power });
        }

        fn execute_proposal(ref self: ContractState, proposal_id: u256) {
            self.only_unpaused();

            let proposal = self.get_proposal(proposal_id);
            assert(!proposal.executed, GovernanceErrors::ALREADY_EXECUTED);

            assert(
                utils::is_proposal_ready_for_execution(
                    proposal.votes_for,
                    proposal.votes_against,
                    proposal.end_time,
                    constants::EXECUTION_DELAY,
                ),
                GovernanceErrors::PROPOSAL_NOT_READY,
            );

            let mut updated_proposal = proposal;
            updated_proposal.executed = true;
            self.proposals.write(proposal_id, updated_proposal);

            self.emit(ProposalExecuted { proposal_id, success: true });
        }

        fn get_proposal(self: @ContractState, proposal_id: u256) -> Proposal {
            let proposal = self.proposals.read(proposal_id);
            assert(proposal.id != 0, GovernanceErrors::PROPOSAL_NOT_FOUND);
            proposal
        }

        fn get_voting_power(self: @ContractState, user: ContractAddress) -> u256 {
            let token = IERC20Dispatcher { contract_address: self.governance_token.read() };
            token.balance_of(user)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn only_unpaused(self: @ContractState) {
            assert(!self.paused.read(), 'Contract is paused');
        }

        fn has_voted(self: @ContractState, proposal_id: u256, voter: ContractAddress) -> bool {
            self.user_votes.read((proposal_id, voter))
        }

        fn get_user_voting_power_for_proposal(
            self: @ContractState, proposal_id: u256, voter: ContractAddress,
        ) -> u256 {
            self.user_voting_power.read((proposal_id, voter))
        }
    }
}

#[abi(embed_v0)]
impl PauseableImpl of IPauseable<ContractState> {
    fn pause(ref self: ContractState) {
        self.ownable.assert_only_owner();
        assert(!self.paused.read(), 'Already paused');
        self.paused.write(true);
        self.emit(Paused {});
    }

    fn unpause(ref self: ContractState) {
        self.ownable.assert_only_owner();
        assert(self.paused.read(), 'Not paused');
        self.paused.write(false);
        self.emit(Unpaused {});
    }

    fn is_paused(self: @ContractState) -> bool {
        self.paused.read()
    }
}
