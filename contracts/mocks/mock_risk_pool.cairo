use starknet::ContractAddress;

use stark_insured::interfaces::IRiskPool;

#[starknet::contract]
mod MockRiskPool {
    use super::IRiskPool;
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        total_balance: u256,
        user_balances: LegacyMap<ContractAddress, u256>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.total_balance.write(0);
    }

    #[abi(embed_v0)]
    impl MockRiskPoolImpl of IRiskPool<ContractState> {
        fn deposit(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            assert(amount > 0, 'INVALID_AMOUNT');
            let current = self.user_balances.read(caller);
            self.user_balances.write(caller, current + amount);
            self.total_balance.write(self.total_balance.read() + amount);
        }

        fn withdraw(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let bal = self.user_balances.read(caller);
            assert(bal >= amount, 'INSUFFICIENT_BALANCE');
            self.user_balances.write(caller, bal - amount);
            self.total_balance.write(self.total_balance.read() - amount);
        }

        fn get_balance(self: @ContractState) -> u256 {
            self.total_balance.read()
        }

        fn get_user_balance(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_balances.read(user)
        }

        fn calculate_risk_score(self: @ContractState, user: ContractAddress) -> u256 {
            // trivial mock
            1
        }

        fn process_payout(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can payout');
            assert(self.total_balance.read() >= amount, 'INSUFFICIENT_POOL');
            // In a mock, just decrease pool total and increase recipient balance
            self.total_balance.write(self.total_balance.read() - amount);
            let rb = self.user_balances.read(recipient);
            self.user_balances.write(recipient, rb + amount);
        }

        #[view]
        fn claimable_amount(self: @ContractState, user: ContractAddress) -> u256 {
            // not used in scenarios
            0
        }
    }

    #[abi(embed_v0)]
    impl Admin for ContractState {
        fn seed_balance(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner');
            self.total_balance.write(self.total_balance.read() + amount);
        }
    }
}


