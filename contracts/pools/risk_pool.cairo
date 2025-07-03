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

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, pool_token: ContractAddress) {
        self.ownable.initializer(owner);
        self.pool_token.write(pool_token);
        self.total_balance.write(0);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl RiskPoolImpl of IRiskPool<ContractState> {
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

        fn get_balance(self: @ContractState) -> u256 {
            self.total_balance.read()
        }

        fn get_user_balance(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_balances.read(user)
        }

        fn calculate_risk_score(self: @ContractState, user: ContractAddress) -> u256 {
            let claim_history = self.user_claim_history.read(user);
            let deposit_amount = self.user_balances.read(user);

            utils::calculate_risk_score_basic(claim_history, deposit_amount)
        }

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

        fn authorize_processor(ref self: ContractState, processor: ContractAddress) {
            self.ownable.assert_only_owner();
            self.authorized_processors.write(processor, true);
        }

        fn revoke_processor(ref self: ContractState, processor: ContractAddress) {
            self.ownable.assert_only_owner();
            self.authorized_processors.write(processor, false);
        }
    }
}
