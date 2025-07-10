# Risk Pool Contract

## claimable_amount View Function

### Description
The `claimable_amount(user: felt) -> (amount: felt)` view function allows users to check how much they are eligible to claim before submitting a claim. This improves UX and transparency for users and frontends.

### Usage Guide
- **Function Call:**
  ```cairo
  let (amount) = risk_pool_contract.claimable_amount(user_address);
  ```
- **Returns:**
  - The eligible payout amount (as `felt`).
  - Returns `0` if the user is not eligible or no payout is possible.

### Claimable Amount Logic
- Checks if the user's policy is active and eligible.
- Confirms an oracle event has occurred (e.g., via integration module or flag).
- Computes payout based on:
  - Policy terms (e.g., coverage %)
  - Risk pool liquidity
  - Cap per user or global limits
- Returns the eligible payout amount (capped if pool balance is insufficient).

### Example
```cairo
let (amount) = risk_pool_contract.claimable_amount(user_address);
if amount > 0 {
    // User can claim this amount
} else {
    // No claimable amount
}
```

### Claimable Conditions
- Policy must be active and not expired.
- Oracle event must be triggered.
- Pool must have sufficient liquidity.
- Payout is capped by policy and pool limits.

---
