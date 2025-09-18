#[starknet::contract]
mod PolicyManager {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use stark_insured::errors::PolicyErrors;
    use stark_insured::events::{PolicyCreated, PremiumPaid};
    use stark_insured::interfaces::{IPolicyManager, Policy, IPauseable};
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
        policies: LegacyMap<u256, Policy>,
        policy_counter: u256,
        premium_token: ContractAddress,
        paused: bool,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PolicyCreated: PolicyCreated,
        PremiumPaid: PremiumPaid,
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

    /// @notice Initializes the policy manager contract
    /// @dev Sets up ownable component and initializes storage variables
    /// @param owner The address that will own this contract
    /// @param premium_token The ERC20 token address used for premium payments
    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, premium_token: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.premium_token.write(premium_token);
        self.policy_counter.write(0);
        self.paused.write(false);
    }

    // --- Policy Lifecycle Extensions ---
    /// @notice Issues a new policy for a user
    /// @dev Only owner can issue. Records metadata and emits event.
    /// @param user The address of the policy holder
    /// @param policy_type The type of policy (1=Health, 2=Auto, 3=Property, 4=Life)
    /// @param duration The duration of the policy in seconds
    fn issue_policy(
        ref self: ContractState, user: ContractAddress, policy_type: u8, duration: u64,
    ) {
        self.ownable.assert_only_owner();
        let now = get_block_timestamp();
        let policy_id = self.policy_counter.read() + 1;
        self.policy_counter.write(policy_id);
        let premium = self.calculate_premium(constants::MIN_COVERAGE_AMOUNT, duration, policy_type);
        let policy = Policy {
            id: policy_id,
            holder: user,
            coverage_amount: constants::MIN_COVERAGE_AMOUNT,
            premium,
            start_time: now,
            end_time: now + duration,
            policy_type,
            is_active: true,
        };
        self.policies.write(policy_id, policy);
        self
            .emit(
                PolicyCreated {
                    policy_id,
                    holder: user,
                    coverage_amount: constants::MIN_COVERAGE_AMOUNT,
                    premium,
                    policy_type,
                },
            );
    }

    /// @notice Returns true if the user holds a valid, non-expired, non-revoked policy
    /// @param user The address of the user to validate
    /// @return True if the user has a valid policy, false otherwise
    #[view]
    fn validate_policy(self: @ContractState, user: ContractAddress) -> bool {
        // Find policy by user
        let mut found = false;
        let mut valid = false;
        let total = self.policy_counter.read();
        let now = get_block_timestamp();
        let mut i = 1;
        while i <= total {
            let policy = self.policies.read(i);
            if policy.holder == user {
                found = true;
                valid = policy.is_active && now <= policy.end_time;
                break;
            }
            i = i + 1;
        }
        found && valid
    }

    /// @notice Revokes a user's policy (only owner)
    /// @dev Sets the policy's is_active flag to false
    /// @param user The address of the user whose policy to revoke
    fn revoke_policy(ref self: ContractState, user: ContractAddress) {
        self.ownable.assert_only_owner();
        let total = self.policy_counter.read();
        let mut i = 1;
        while i <= total {
            let mut policy = self.policies.read(i);
            if policy.holder == user && policy.is_active {
                policy.is_active = false;
                self.policies.write(i, policy);
                break;
            }
            i = i + 1;
        }
    }

    #[abi(embed_v0)]
    impl PolicyManagerImpl of IPolicyManager<ContractState> {
        /// @notice Creates a new insurance policy
        /// @dev Validates input parameters and calculates premium based on coverage and duration
        /// @param policy_holder The address that will hold the policy
        /// @param coverage_amount The amount covered by the policy (must be within min/max limits)
        /// @param duration The duration of the policy in seconds
        /// @param policy_type The type of policy (1=Health, 2=Auto, 3=Property, 4=Life)
        /// @return The ID of the newly created policy
        fn create_policy(
            ref self: ContractState,
            policy_holder: ContractAddress,
            coverage_amount: u256,
            duration: u64,
            policy_type: u8,
        ) -> u256 {
            self.only_unpaused();

            // Validation
            assert(utils::is_valid_address(policy_holder), PolicyErrors::UNAUTHORIZED_ACCESS);
            assert(
                coverage_amount >= constants::MIN_COVERAGE_AMOUNT
                    && coverage_amount <= constants::MAX_COVERAGE_AMOUNT,
                PolicyErrors::INVALID_COVERAGE_AMOUNT,
            );
            assert(duration > 0, PolicyErrors::INVALID_DURATION);

            let policy_id = self.policy_counter.read() + 1;
            self.policy_counter.write(policy_id);

            let current_time = get_block_timestamp();
            let premium = self.calculate_premium(coverage_amount, duration, policy_type);

            let policy = Policy {
                id: policy_id,
                holder: policy_holder,
                coverage_amount,
                premium,
                start_time: current_time,
                end_time: current_time + duration,
                policy_type,
                is_active: true,
            };

            self.policies.write(policy_id, policy);

            self
                .emit(
                    PolicyCreated {
                        policy_id, holder: policy_holder, coverage_amount, premium, policy_type,
                    },
                );

            policy_id
        }

        /// @notice Retrieves policy details by ID
        /// @dev Reverts if policy doesn't exist
        /// @param policy_id The ID of the policy to retrieve
        /// @return The Policy struct containing all policy details
        fn get_policy(self: @ContractState, policy_id: u256) -> Policy {
            let policy = self.policies.read(policy_id);
            assert(policy.id != 0, PolicyErrors::POLICY_NOT_FOUND);
            policy
        }

        /// @notice Allows policy holders to pay their premium
        /// @dev Uses reentrancy protection and transfers tokens from caller to contract
        /// @param policy_id The ID of the policy to pay premium for
        /// @param amount The amount of tokens to pay (must be >= policy premium)
        fn pay_premium(ref self: ContractState, policy_id: u256, amount: u256) {
            self.only_unpaused();
            self.reentrancy_guard.start();

            let policy = self.get_policy(policy_id);
            let caller = get_caller_address();

            assert(policy.holder == caller, PolicyErrors::UNAUTHORIZED_ACCESS);
            assert(amount >= policy.premium, PolicyErrors::INSUFFICIENT_PREMIUM);

            let token = IERC20Dispatcher { contract_address: self.premium_token.read() };
            token.transfer_from(caller, starknet::get_contract_address(), amount);

            self.emit(PremiumPaid { policy_id, payer: caller, amount });

            self.reentrancy_guard.end();
        }

        /// @notice Checks if a policy is currently active
        /// @dev A policy is active if it exists, is_active flag is true, and hasn't expired
        /// @param policy_id The ID of the policy to check
        /// @return True if policy is active, false otherwise
        fn is_policy_active(self: @ContractState, policy_id: u256) -> bool {
            let policy = self.policies.read(policy_id);
            if policy.id == 0 {
                return false;
            }

            let current_time = get_block_timestamp();
            policy.is_active && current_time <= policy.end_time
        }

        /// @notice Calculates premium based on coverage amount, duration, and policy type
        /// @dev Uses different multipliers for different policy types
        /// @param coverage_amount The amount to be covered
        /// @param duration The duration of the policy in seconds
        /// @param policy_type The type of policy (affects premium multiplier)
        /// @return The calculated premium amount
        fn calculate_premium(
            self: @ContractState, coverage_amount: u256, duration: u64, policy_type: u8,
        ) -> u256 {
            let base_premium = (coverage_amount * constants::BASE_PREMIUM_RATE) / 10000;
            let duration_factor = duration.into() / constants::SECONDS_IN_DAY.into();

            // Type-specific multipliers
            let type_multiplier = match policy_type {
                1 => 120, // Health: 20% higher
                2 => 150, // Auto: 50% higher
                3 => 110, // Property: 10% higher
                4 => 200, // Life: 100% higher
                _ => 100 // Default
            };

            (base_premium * duration_factor * type_multiplier.into()) / 100
        }

        /// @notice Returns the total number of policies created
        /// @return The total count of policies ever created
        fn get_total_policies(self: @ContractState) -> u256 {
            self.policy_counter.read()
        }
    }

    #[abi(embed_v0)]
    impl PauseableImpl of IPauseable<ContractState> {
        /// @notice Pauses the contract, preventing most operations
        /// @dev Only owner can pause, contract must not already be paused
        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            assert(!self.paused.read(), 'Already paused');
            self.paused.write(true);
            self.emit(Paused {});
        }

        /// @notice Unpauses the contract, allowing normal operations
        /// @dev Only owner can unpause, contract must be paused
        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            assert(self.paused.read(), 'Not paused');
            self.paused.write(false);
            self.emit(Unpaused {});
        }

        /// @notice Checks if the contract is currently paused
        /// @return True if paused, false otherwise
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// @notice Internal function to ensure contract is not paused
        /// @dev Reverts with error message if contract is paused
        fn only_unpaused(self: @ContractState) {
            assert(!self.paused.read(), 'Contract is paused');
        }
    }
}
