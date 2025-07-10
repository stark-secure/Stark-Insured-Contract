# Staking Contract for Insurance Risk Pools

## Description
This contract enables users to stake tokens into insurance risk pools, earn yield based on pool performance, and withdraw with or without penalty depending on the lockup period. It supports decentralized liquidity provisioning for claims.

## Core Functions
- `stake(amount: Uint256)`: Stake tokens, records amount and timestamp.
- `unstake()`: Withdraw stake after lockup, applies penalty if early.
- `claim_rewards()`: Claim accrued rewards based on time staked and APR.

## Storage
- Tracks total staked, user stakes, timestamps, and rewards.
- Efficient storage with @storage_var for user and global data.

## Rewards Model
- Fixed APR (e.g., 10% annualized).
- Rewards: `rewards = stake_amount * apr * (elapsed_time / seconds_per_year)`

## Events
- `Staked`, `Unstaked`, `RewardClaimed`

## Penalty Logic
- Early unstake incurs penalty, sent to treasury or redistributed.

## Tests
- Stake/unstake flows, early withdrawal, reward accrual, edge cases.

---
