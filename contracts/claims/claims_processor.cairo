#[starknet::contract]
mod ClaimsProcessor {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use stark_insured::errors::ClaimErrors;
    use stark_insured::events::{ClaimProcessed, ClaimSubmitted};
    use stark_insured::interfaces::{
        Claim, IClaimsProcessor, IPolicyManagerDispatcher, IPolicyManagerDispatcherTrait,
        IRiskPoolDispatcher, IRiskPoolDispatcherTrait, IPauseable,
    };
    use stark_insured::{constants, utils};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        claims: LegacyMap<u256, Claim>,
        claim_counter: u256,
        policy_claims: LegacyMap<u256, Array<u256>>,
        last_claim_time: LegacyMap<ContractAddress, u64>,
        policy_manager: ContractAddress,
        risk_pool: ContractAddress,
        paused: bool,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ClaimSubmitted: ClaimSubmitted,
        ClaimProcessed: ClaimProcessed,
        Paused: Paused,
        Unpaused: Unpaused,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct Paused {}

    #[derive(Drop, starknet::Event)]
    struct Unpaused {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        policy_manager: ContractAddress,
        risk_pool: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.policy_manager.write(policy_manager);
        self.risk_pool.write(risk_pool);
        self.claim_counter.write(0);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl ClaimsProcessorImpl of IClaimsProcessor<ContractState> {
        fn submit_claim(
            ref self: ContractState, policy_id: u256, claim_amount: u256, evidence_hash: felt252,
        ) -> u256 {
            self.only_unpaused();

            let caller = get_caller_address();

            assert(self.can_submit_claim(caller), ClaimErrors::CLAIM_COOLDOWN_ACTIVE);

            let policy_manager = IPolicyManagerDispatcher {
                contract_address: self.policy_manager.read(),
            };
            let policy = policy_manager.get_policy(policy_id);
            assert(policy.holder == caller, ClaimErrors::CLAIM_NOT_FOUND);
            assert(policy_manager.is_policy_active(policy_id), ClaimErrors::CLAIM_NOT_FOUND);

            assert(
                claim_amount > 0 && claim_amount <= policy.coverage_amount,
                ClaimErrors::INVALID_CLAIM_AMOUNT,
            );
            assert(evidence_hash != 0, ClaimErrors::INVALID_EVIDENCE);

            let claim_id = self.claim_counter.read() + 1;
            self.claim_counter.write(claim_id);

            let claim = Claim {
                id: claim_id,
                policy_id,
                claimant: caller,
                amount: claim_amount,
                evidence_hash,
                timestamp: get_block_timestamp(),
                status: constants::CLAIM_PENDING,
            };

            self.claims.write(claim_id, claim);
            self.last_claim_time.write(caller, get_block_timestamp());

            let mut policy_claims = self.policy_claims.read(policy_id);
            policy_claims.append(claim_id);
            self.policy_claims.write(policy_id, policy_claims);

            self
                .emit(
                    ClaimSubmitted {
                        claim_id, policy_id, claimant: caller, amount: claim_amount, evidence_hash,
                    },
                );

            claim_id
        }

        fn process_claim(ref self: ContractState, claim_id: u256, approved: bool) {
            self.only_unpaused();
            self.ownable.assert_only_owner();
            self.reentrancy_guard.start();

            let mut claim = self.get_claim(claim_id);
            assert(claim.status == constants::CLAIM_PENDING, ClaimErrors::CLAIM_ALREADY_PROCESSED);

            let payout_amount = if approved {
                claim.amount
            } else {
                0
            };

            if approved {
                let risk_pool = IRiskPoolDispatcher { contract_address: self.risk_pool.read() };

                assert(
                    risk_pool.get_balance() >= claim.amount, ClaimErrors::INSUFFICIENT_POOL_BALANCE,
                );

                risk_pool.process_payout(claim.claimant, claim.amount);
                claim.status = constants::CLAIM_APPROVED;
            } else {
                claim.status = constants::CLAIM_REJECTED;
            }

            self.claims.write(claim_id, claim);

            self
                .emit(
                    ClaimProcessed { claim_id, claimant: claim.claimant, approved, payout_amount },
                );

            self.reentrancy_guard.end();
        }

        fn get_claim(self: @ContractState, claim_id: u256) -> Claim {
            let claim = self.claims.read(claim_id);
            assert(claim.id != 0, ClaimErrors::CLAIM_NOT_FOUND);
            claim
        }

        fn get_claims_by_policy(self: @ContractState, policy_id: u256) -> Array<u256> {
            self.policy_claims.read(policy_id)
        }

        fn can_submit_claim(self: @ContractState, claimant: ContractAddress) -> bool {
            let last_claim = self.last_claim_time.read(claimant);
            if last_claim == 0 {
                return true;
            }
            !utils::is_within_cooldown(last_claim)
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

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn only_unpaused(self: @ContractState) {
            assert(!self.paused.read(), 'Contract is paused');
        }
    }
}
