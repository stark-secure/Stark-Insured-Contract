# Policy Certificates & Manager Architecture

## Overview
This document describes the architecture and lifecycle of insurance policies managed by `policy_manager.cairo` and validated by `policy_certificate.cairo` on StarkNet.

## Roles
- **Policy Manager:** Handles issuance, validation, expiration, and revocation of policies. Stores metadata and enforces admin controls.
- **Policy Certificate:** Pure registry/validator. Verifies policy ownership and state, exposes certificate details, and is used for on-chain checks (e.g., claims, DAO voting).

## Lifecycle Flow
| Action         | Manager | Certificate | State Change |
| --------------|---------|-------------|--------------|
| Issue Policy  |   ✔     |     ✔       | Active       |
| Validate      |   ✔     |     ✔       | Check valid  |
| Expire        |   ✔     |     ✔       | Expired      |
| Revoke        |   ✔     |     ✔       | Revoked      |

- **Issue:** Admin/user requests issuance. Manager creates policy, certificate records ownership.
- **Validate:** Anyone can check if a user holds a valid, non-expired, non-revoked policy.
- **Expire:** Policy auto-expires if current block timestamp > start + duration.
- **Revoke:** Only admin can revoke early. Reason can be stored.

## Usage Patterns
- **On-claim check:** Validate policy before processing claim.
- **DAO participation:** Only valid policy holders can vote.

## State Diagram
```
[Issued] --(time passes)--> [Expired]
   |                           ^
   |--(admin revoke)--------->|
```

## View Functions
- `validate_policy(user: felt) -> bool` (Manager)
- `is_valid_certificate(user: felt) -> bool` (Certificate)
- `get_certificate_details(user: felt)` (Certificate)

---
