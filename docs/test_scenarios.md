### Test Scenarios

This suite introduces realistic, end-to-end insurance simulations using a mock policy manager and mock risk pool to focus on system logic:

- **Flight Delay Insurance**: Simulates an oracle event for a flight delay greater than 3 hours, followed by claim submission and payout.
- **Crop Insurance (Drought)**: Simulates severe drought via oracle data, then executes claim and payout.

Lifecycle covered in each scenario:
- Policy issuance (mock `MockPolicyManager::create_policy`)
- Oracle event emission via `OracleIntegration::submit_data` and validation with `validate_data`
- Claim submission through `ClaimsProcessor::submit_claim`
- Claim processing and payout via `ClaimsProcessor::process_claim`

Expected results and assertions:
- Correct association between claimant and policy holder
- Oracle data accepted only from trusted oracles and within validity window
- `ClaimSubmitted` and `ClaimProcessed` events emitted
- Risk pool balance reduced by payout and recipient balance increased

Edge cases to consider (not fully covered yet):
- Oracle data outside the validity window should be rejected
- Untrusted oracle submissions should revert
- Claim amounts exceeding policy coverage should revert
- Pool with insufficient balance should cause processing to revert

Run locally:
```
scarb test
```


