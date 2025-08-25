# Cross-Chain Bridge Specification

## Overview

The Cross-Chain Bridge enables policy claims to be submitted from external chains (e.g., Ethereum L1) to StarkNet. It provides secure message validation, replay protection, and event emission for downstream processing.

## Message Format

### Payload Structure

\`\`\`json
{
"source_chain": "1", // Chain ID (1 = Ethereum mainnet, 5 = Goerli)
"message_hash": "0x...", // Unique message identifier for replay protection
"payload": [
"policy_id", // felt252: Policy identifier
"user_low", // felt252: Lower 128 bits of user address
"user_high", // felt252: Upper 128 bits of user address
 "claim_data_1", // felt252: First piece of claim data
"claim_data_2", // felt252: Additional claim data...
"..."
]
}
\`\`\`

### Cairo Function Call

```cairo
bridge.receive_message(
    source_chain: felt252,    // e.g., 1 for Ethereum
    message_hash: felt252,    // Unique message hash
    payload: Span<felt252>    // [policy_id, user_low, user_high, ...claim_data]
);
```
