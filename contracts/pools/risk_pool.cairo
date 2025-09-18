#[starknet::contract]
mod RiskPool {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use stark_insured::errors::PoolErrors;
    use stark_insured::events::{PoolDeposit, PoolWithdrawal};
    use stark_insured::interfaces::{IRiskPool, IPauseable};
    use stark_insured::utils;
    use starknet::{ContractAddress, get_caller_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        pool_token: ContractAddress,
        total_balance: u256,
        user_balances: LegacyMap<ContractAddress, u256>,
        user_claim_history: LegacyMap<ContractAddress, u256>,
        authorized_processors: LegacyMap<ContractAddress, bool>,
        paused: bool,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PoolDeposit: PoolDeposit,
        PoolWithdrawal: PoolWithdrawal,
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

    /// @notice Initializes the risk pool contract with owner and pool token
    /// @dev Sets up ownable component and initializes storage variables
    /// @param owner The address that will own this contract
    /// @param pool_token The ERC20 token address used for pool operations
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, pool_token: ContractAddress) {
        self.ownable.initializer(owner);
        self.pool_token.write(pool_token);
        self.total_balance.write(0);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl RiskPoolImpl of IRiskPool<ContractState> {
        /// @notice Calculates the claimable amount for a user based on policy status and pool
        /// liquidity @dev Checks policy activity, oracle events, and applies pool balance caps
        /// @param user The address of the user to check claimable amount for
        /// @return The amount that can be claimed by the user
        #[view]
        fn claimable_amount(self: @ContractState, user: ContractAddress) -> u256 {
            // --- 1. Check if user has an active policy ---
            // For demo: Assume policy_id == 1 for user (in real, would map user to policy_id)
            let policy_manager_addr =
                0; // TODO: Set actual PolicyManager address or fetch from registry
            if policy_manager_addr == 0 {
                return 0;
            }
            let policy_manager = stark_insured::interfaces::IPolicyManagerDispatcher {
                contract_address: policy_manager_addr,
            };
            let policy_id = 1; // TODO: Replace with actual lookup
            let is_active = policy_manager.is_policy_active(policy_id);
            if !is_active {
                return 0;
            }

            // --- 2. Check if oracle event has occurred ---
            // For demo: Assume oracle event flag is true (replace with actual oracle check)
            let oracle_event_triggered = true;
            if !oracle_event_triggered {
                return 0;
            }

            // --- 3. Compute payout based on policy terms and pool liquidity ---
            let policy = policy_manager.get_policy(policy_id);
            let coverage_amount = policy.coverage_amount;
            let coverage_percent = 80; // e.g., 80% payout, replace with policy field if available
            let payout = (coverage_amount * coverage_percent.into()) / 100;

            // --- 4. Cap payout by pool balance ---
            let pool_balance = self.total_balance.read();
            let claimable = if payout > pool_balance {
                pool_balance
            } else {
                payout
            };

            // --- 5. Cap per user/global limits (optional, add logic as needed) ---
            claimable
        }

        /// @notice Allows users to deposit tokens into the risk pool
        /// @dev Requires contract to be unpaused and uses reentrancy protection
        /// @param amount The amount of tokens to deposit (must be > 0)
        fn deposit(ref self: ContractState, amount: u256) {
            self.only_unpaused();
            assert(amount > 0, PoolErrors::INVALID_AMOUNT);
            self.reentrancy_guard.start();

            let caller = get_caller_address();
            let token = IERC20Dispatcher { contract_address: self.pool_token.read() };

            let success = token.transfer_from(caller, starknet::get_contract_address(), amount);
            assert(success, PoolErrors::DEPOSIT_FAILED);

            let current_balance = self.user_balances.read(caller);
            let new_balance = current_balance + amount;
            self.user_balances.write(caller, new_balance);

            let total = self.total_balance.read();
            self.total_balance.write(total + amount);

            self.emit(PoolDeposit { depositor: caller, amount, new_balance });

            self.reentrancy_guard.end();
        }

        /// @notice Allows users to withdraw their deposited tokens from the pool
        /// @dev Requires contract to be unpaused and sufficient user balance
        /// @param amount The amount of tokens to withdraw (must be > 0)
        fn withdraw(ref self: ContractState, amount: u256) {
            self.only_unpaused();
            assert(amount > 0, PoolErrors::INVALID_AMOUNT);
            self.reentrancy_guard.start();

            let caller = get_caller_address();
            let current_balance = self.user_balances.read(caller);
            assert(current_balance >= amount, PoolErrors::INSUFFICIENT_BALANCE);

            let token = IERC20Dispatcher { contract_address: self.pool_token.read() };

            let new_balance = current_balance - amount;
            self.user_balances.write(caller, new_balance);

            let total = self.total_balance.read();
            self.total_balance.write(total - amount);

            let success = token.transfer(caller, amount);
            assert(success, PoolErrors::WITHDRAWAL_FAILED);

            self.emit(PoolWithdrawal { withdrawer: caller, amount, new_balance });

            self.reentrancy_guard.end();
        }

        /// @notice Returns the total balance of tokens in the pool
        /// @return The total amount of tokens held by the pool
        fn get_balance(self: @ContractState) -> u256 {
            self.total_balance.read()
        }

        /// @notice Returns the balance of a specific user in the pool
        /// @param user The address to check the balance for
        /// @return The amount of tokens deposited by the user
        fn get_user_balance(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_balances.read(user)
        }

        /// @notice Calculates a basic risk score for a user
        /// @dev Uses claim history and deposit amount to determine risk
        /// @param user The address to calculate risk score for
        /// @return The calculated risk score as a u256 value
        fn calculate_risk_score(self: @ContractState, user: ContractAddress) -> u256 {
            let claim_history = self.user_claim_history.read(user);
            let deposit_amount = self.user_balances.read(user);

            utils::calculate_risk_score_basic(claim_history, deposit_amount)
        }

        /// @notice Processes insurance payouts to recipients
        /// @dev Only authorized processors or owner can call this function
        /// @param recipient The address to receive the payout
        /// @param amount The amount to pay out (must not exceed pool balance)
        fn process_payout(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.only_unpaused();

            let caller = get_caller_address();
            assert(
                self.authorized_processors.read(caller) || caller == self.ownable.owner(),
                PoolErrors::INSUFFICIENT_BALANCE,
            );

            assert(self.total_balance.read() >= amount, PoolErrors::INSUFFICIENT_BALANCE);
            self.reentrancy_guard.start();

            let token = IERC20Dispatcher { contract_address: self.pool_token.read() };

            let total = self.total_balance.read();
            self.total_balance.write(total - amount);

            let current_claims = self.user_claim_history.read(recipient);
            self.user_claim_history.write(recipient, current_claims + 1);

            let success = token.transfer(recipient, amount);
            assert(success, PoolErrors::WITHDRAWAL_FAILED);

            self.reentrancy_guard.end();
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

        /// @notice Authorizes a processor to handle payouts
        /// @dev Only owner can authorize processors
        /// @param processor The address to authorize
        fn authorize_processor(ref self: ContractState, processor: ContractAddress) {
            self.ownable.assert_only_owner();
            self.authorized_processors.write(processor, true);
        }

        /// @notice Revokes processor authorization
        /// @dev Only owner can revoke processor authorization
        /// @param processor The address to revoke authorization from
        fn revoke_processor(ref self: ContractState, processor: ContractAddress) {
            self.ownable.assert_only_owner();
            self.authorized_processors.write(processor, false);
        }
    }
}
