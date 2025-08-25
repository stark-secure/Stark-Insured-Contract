use starknet::ContractAddress;

#[starknet::interface]
trait IInsuranceFactory<TContractState> {
    fn create_policy(
        ref self: TContractState,
        owner: ContractAddress,
        coverage_type: felt252,
        duration: u64,
        asset: ContractAddress,
        salt: felt252
    ) -> ContractAddress;
    
    fn get_user_policies(self: @TContractState, user: ContractAddress) -> Array<ContractAddress>;
    fn get_policy_count(self: @TContractState, user: ContractAddress) -> u32;
    fn is_authorized(self: @TContractState, user: ContractAddress) -> bool;
    fn add_authorized_user(ref self: TContractState, user: ContractAddress);
    fn remove_authorized_user(ref self: TContractState, user: ContractAddress);
}

#[starknet::contract]
mod InsuranceFactory {
    use super::IInsuranceFactory;
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, deploy_syscall,
        ClassHash, get_contract_address
    };
    use core::array::ArrayTrait;
    use core::traits::Into;

    #[storage]
    struct Storage {
        // Track policies created by each user
        user_policies: LegacyMap<ContractAddress, Array<ContractAddress>>,
        user_policy_count: LegacyMap<ContractAddress, u32>,
        // Authorization control
        authorized_users: LegacyMap<ContractAddress, bool>,
        owner: ContractAddress,
        // Policy manager class hash for deployment
        policy_manager_class_hash: ClassHash,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewPolicyCreated: NewPolicyCreated,
        UserAuthorized: UserAuthorized,
        UserDeauthorized: UserDeauthorized,
    }

    #[derive(Drop, starknet::Event)]
    struct NewPolicyCreated {
        #[key]
        policy_address: ContractAddress,
        #[key]
        owner: ContractAddress,
        coverage_type: felt252,
        duration: u64,
        asset: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct UserAuthorized {
        #[key]
        user: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct UserDeauthorized {
        #[key]
        user: ContractAddress,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        policy_manager_class_hash: ClassHash
    ) {
        self.owner.write(owner);
        self.policy_manager_class_hash.write(policy_manager_class_hash);
        // Owner is automatically authorized
        self.authorized_users.write(owner, true);
    }

    #[abi(embed_v0)]
    impl InsuranceFactoryImpl of IInsuranceFactory<ContractState> {
        fn create_policy(
            ref self: ContractState,
            owner: ContractAddress,
            coverage_type: felt252,
            duration: u64,
            asset: ContractAddress,
            salt: felt252
        ) -> ContractAddress {
            let caller = get_caller_address();
            
            // Security check: only authorized users can create policies
            assert(self.is_authorized(caller), 'Unauthorized user');
            
            // Prepare constructor calldata for policy manager
            let mut constructor_calldata = ArrayTrait::new();
            constructor_calldata.append(owner.into());
            constructor_calldata.append(coverage_type);
            constructor_calldata.append(duration.into());
            constructor_calldata.append(asset.into());
            
            // Deploy the policy manager contract
            let (policy_address, _) = deploy_syscall(
                self.policy_manager_class_hash.read(),
                salt,
                constructor_calldata.span(),
                false
            ).expect('Failed to deploy policy');

            // Track the created policy
            let current_count = self.user_policy_count.read(owner);
            self.user_policy_count.write(owner, current_count + 1);
            
            // Add to user's policy list (simplified storage pattern)
            let mut user_policies = self.user_policies.read(owner);
            user_policies.append(policy_address);
            self.user_policies.write(owner, user_policies);

            // Emit event
            self.emit(NewPolicyCreated {
                policy_address,
                owner,
                coverage_type,
                duration,
                asset,
                timestamp: get_block_timestamp(),
            });

            policy_address
        }

        fn get_user_policies(self: @ContractState, user: ContractAddress) -> Array<ContractAddress> {
            self.user_policies.read(user)
        }

        fn get_policy_count(self: @ContractState, user: ContractAddress) -> u32 {
            self.user_policy_count.read(user)
        }

        fn is_authorized(self: @ContractState, user: ContractAddress) -> bool {
            self.authorized_users.read(user)
        }

        fn add_authorized_user(ref self: ContractState, user: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can authorize');
            
            self.authorized_users.write(user, true);
            
            self.emit(UserAuthorized {
                user,
                timestamp: get_block_timestamp(),
            });
        }

        fn remove_authorized_user(ref self: ContractState, user: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can deauthorize');
            
            self.authorized_users.write(user, false);
            
            self.emit(UserDeauthorized {
                user,
                timestamp: get_block_timestamp(),
            });
        }
    }
}
