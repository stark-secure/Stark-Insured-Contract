# Oracle Integration Documentation

## Overview

The Oracle Integration system provides secure, reliable data feeds for the Starknet insurance protocol. It enables trusted oracles to submit real-world data that can trigger insurance claims automatically.

## Core Features

### Data Submission

- **Secure Oracle Whitelisting**: Only trusted oracles can submit data
- **Timestamp Validation**: Prevents future timestamps and stale data
- **Replay Protection**: Nonce-based system prevents duplicate submissions
- **Data Freshness**: Configurable validity window ensures recent data

### Claim Processing

- **Automated Validation**: Real-time data verification for claims
- **Trigger Protection**: Prevents duplicate claim triggering
- **Event Logging**: Comprehensive audit trail for all operations

## Contract Interface

### Core Functions

#### `submit_data(oracle_id, payload, timestamp)`

Submits data from a trusted oracle with security validations.

**Parameters:**

- `oracle_id`: Address of the submitting oracle
- `payload`: Data payload (felt252 format)
- `timestamp`: Unix timestamp of the data

**Security Checks:**

- Oracle must be in trusted list
- Timestamp cannot be in the future
- Data must be within validity window
- Prevents replay attacks

#### `validate_data(oracle_id, claim_id) -> bool`

Validates if oracle data is suitable for claim processing.

**Returns:** Boolean indicating data validity

#### `trigger_claim(claim_id)`

Triggers an insurance claim based on oracle data.

**Authorization:** Only trusted oracles or contract owner

### Management Functions

#### `add_trusted_oracle(oracle_address)`

Adds an oracle to the trusted list (owner only).

#### `remove_trusted_oracle(oracle_address)`

Removes an oracle from the trusted list (owner only).

#### `set_data_validity_window(window_seconds)`

Sets the data freshness window (owner only).

## Events

### `OracleUpdated`

Emitted when oracle submits new data.

```cairo
struct OracleUpdated {
    oracle_id: ContractAddress,
    payload: felt252,
    timestamp: u64,
}
```
