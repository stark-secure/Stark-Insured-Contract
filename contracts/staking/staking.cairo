// SPDX-License-Identifier: MIT
// @title Staking Contract for Insurance Risk Pools
// @notice Users can stake tokens, earn rewards, and withdraw with or without penalty.
// stack file

#[starknet::contract]
mod Staking {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use core::traits::Into;

    // --- Constants ---
    const APR: u128 = 10; // 10% annualized
    const SECONDS_PER_YEAR: u64 = 31536000;
    const PENALTY_PERCENT: u128 = 20; // 20% penalty for early unstake
    const LOCKUP_PERIOD: u64 = 604800; // 7 days

    // --- Storage ---
    #[storage]
    struct Storage {
        pool_token: ContractAddress,
        total_staked: u256,
        user_stake: LegacyMap<ContractAddress, u256>,
        user_stake_timestamp: LegacyMap<ContractAddress, u64>,
        user_rewards_claimed: LegacyMap<ContractAddress, u256>,
        treasury: ContractAddress,
    }

    // --- Events ---
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Staked { user: ContractAddress, amount: u256 },
        Unstaked { user: ContractAddress, amount: u256, penalty: u256 },
        RewardClaimed { user: ContractAddress, amount: u256 },
    }

    // --- Constructor ---
    #[constructor]
    fn constructor(ref self: ContractState, pool_token: ContractAddress, treasury: ContractAddress) {
        self.pool_token.write(pool_token);
        self.treasury.write(treasury);
        self.total_staked.write(0);
    }

    /// @notice Stake tokens into the pool
    /// @param amount Amount to stake
    fn stake(ref self: ContractState, amount: u256) {
        assert(amount > 0, 'Amount must be > 0');
        let caller = get_caller_address();
        let token = IERC20Dispatcher { contract_address: self.pool_token.read() };
        let success = token.transfer_from(caller, starknet::get_contract_address(), amount);
        assert(success, 'Stake transfer failed');
        let prev = self.user_stake.read(caller);
        self.user_stake.write(caller, prev + amount);
        self.user_stake_timestamp.write(caller, get_block_timestamp());
        let total = self.total_staked.read();
        self.total_staked.write(total + amount);
        self.emit(Event::Staked { user: caller, amount });
    }

    /// @notice Unstake tokens, applies penalty if before lockup ends
    fn unstake(ref self: ContractState) {
        let caller = get_caller_address();
        let amount = self.user_stake.read(caller);
        assert(amount > 0, 'Nothing to unstake');
        let staked_at = self.user_stake_timestamp.read(caller);
        let now = get_block_timestamp();
        let mut penalty = 0;
        if now < staked_at + LOCKUP_PERIOD {
            penalty = (amount * PENALTY_PERCENT.into()) / 100u128.into();
        }
        let withdraw_amount = amount - penalty;
        let token = IERC20Dispatcher { contract_address: self.pool_token.read() };
        if penalty > 0 {
            let _ = token.transfer(self.treasury.read(), penalty);
        }
        let _ = token.transfer(caller, withdraw_amount);
        self.user_stake.write(caller, 0);
        self.user_stake_timestamp.write(caller, 0);
        let total = self.total_staked.read();
        self.total_staked.write(total - amount);
        self.emit(Event::Unstaked { user: caller, amount: withdraw_amount, penalty });
    }

    /// @notice Claim staking rewards
    fn claim_rewards(ref self: ContractState) {
        let caller = get_caller_address();
        let amount = self.user_stake.read(caller);
        assert(amount > 0, 'No stake');
        let staked_at = self.user_stake_timestamp.read(caller);
        let now = get_block_timestamp();
        let elapsed = now - staked_at;
        let reward = (amount * APR.into() * elapsed.into()) / (100u128.into() * SECONDS_PER_YEAR.into());
        let claimed = self.user_rewards_claimed.read(caller);
        let claimable = reward - claimed;
        assert(claimable > 0, 'No rewards');
        let token = IERC20Dispatcher { contract_address: self.pool_token.read() };
        let _ = token.transfer(caller, claimable);
        self.user_rewards_claimed.write(caller, claimed + claimable);
        self.emit(Event::RewardClaimed { user: caller, amount: claimable });
    }
}
