use starknet::ContractAddress;

use stark_insured::interfaces::{IPolicyManager, Policy};

#[starknet::contract]
mod MockPolicyManager {
    use super::{IPolicyManager, Policy};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        policies: LegacyMap<u256, Policy>,
        policy_counter: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.policy_counter.write(0);
    }

    #[abi(embed_v0)]
    impl MockPolicyManagerImpl of IPolicyManager<ContractState> {
        fn create_policy(
            ref self: ContractState,
            policy_holder: ContractAddress,
            coverage_amount: u256,
            duration: u64,
            policy_type: u8,
        ) -> u256 {
            let new_id = self.policy_counter.read() + 1;
            self.policy_counter.write(new_id);

            let now = get_block_timestamp();
            let policy = Policy {
                id: new_id,
                holder: policy_holder,
                coverage_amount,
                premium: 0,
                start_time: now,
                end_time: now + duration,
                policy_type: policy_type,
                is_active: true,
            };
            self.policies.write(new_id, policy);
            new_id
        }

        fn get_policy(self: @ContractState, policy_id: u256) -> Policy {
            self.policies.read(policy_id)
        }

        fn pay_premium(ref self: ContractState, policy_id: u256, amount: u256) {
            let mut p = self.policies.read(policy_id);
            p.premium = p.premium + amount;
            self.policies.write(policy_id, p);
        }

        fn is_policy_active(self: @ContractState, policy_id: u256) -> bool {
            self.policies.read(policy_id).is_active
        }

        fn calculate_premium(
            self: @ContractState, coverage_amount: u256, duration: u64, policy_type: u8,
        ) -> u256 {
            // simple mock: 1% of coverage
            (coverage_amount / 100)
        }

        fn get_total_policies(self: @ContractState) -> u256 {
            self.policy_counter.read()
        }
    }

    #[abi(embed_v0)]
    impl Admin for ContractState {
        fn set_active(ref self: ContractState, policy_id: u256, active: bool) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner');
            let mut p = self.policies.read(policy_id);
            p.is_active = active;
            self.policies.write(policy_id, p);
        }
    }
}


