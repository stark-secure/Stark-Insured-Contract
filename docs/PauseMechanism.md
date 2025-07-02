# Pause Mechanism Documentation

## Overview

The Stark Insured protocol implements a comprehensive pause/unpause mechanism across all critical contracts to protect against attacks, bugs, or emergency situations. This allows administrators to temporarily halt sensitive operations while maintaining read-only functionality.

## Contracts with Pause Functionality

### 1. PolicyManager

**Paused Functions:**

- `create_policy()` - Policy creation
- `pay_premium()` - Premium payments

**Unaffected Functions:**

- `get_policy()` - Policy queries
- `is_policy_active()` - Policy status checks
- `calculate_premium()` - Premium calculations

### 2. ClaimsProcessor

**Paused Functions:**

- `submit_claim()` - Claim submissions
- `process_claim()` - Claim processing

**Unaffected Functions:**

- `get_claim()` - Claim queries
- `get_claims_by_policy()` - Claim lookups
- `can_submit_claim()` - Eligibility checks

### 3. RiskPool

**Paused Functions:**

- `deposit()` - Pool deposits
- `withdraw()` - Pool withdrawals
- `process_payout()` - Claim payouts

**Unaffected Functions:**

- `get_balance()` - Balance queries
- `get_user_balance()` - User balance checks
- `calculate_risk_score()` - Risk calculations

### 4. DAOGovernance

**Paused Functions:**

- `create_proposal()` - Proposal creation
- `vote()` - Voting on proposals
- `execute_proposal()` - Proposal execution

**Unaffected Functions:**

- `get_proposal()` - Proposal queries
- `get_voting_power()` - Voting power checks

## Access Control

- **Who can pause/unpause:** Only contract owners (admin addresses)
- **Pause functions:** `pause()` and `unpause()` are restricted to owners
- **Emergency use:** Should be used for suspicious activity, critical bugs, or system upgrades

## Usage Examples

### CLI Commands (using Starknet CLI)

```bash
# Pause PolicyManager
starknet invoke --address POLICY_MANAGER_ADDRESS --abi policy_manager.json --function pause

# Unpause PolicyManager
starknet invoke --address POLICY_MANAGER_ADDRESS --abi policy_manager.json --function unpause

# Check pause status
starknet call --address POLICY_MANAGER_ADDRESS --abi policy_manager.json --function is_paused
```
