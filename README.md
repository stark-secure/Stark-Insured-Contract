Stark Insured Contracts
Stark Insured Contracts is the Cairo-based smart contract suite for Stark Insured — a decentralized insurance platform built on the StarkNet ecosystem. These contracts power critical components like policy issuance, claim verification, settlement processing, and DAO-based governance in a trustless and transparent manner.

🧾 Overview
Stark Insured offers next-gen decentralized insurance using smart contracts to eliminate intermediaries and bring fairness, automation, and fraud prevention to risk protection. The contract layer is built with Cairo, optimized for StarkNet’s scalability and zero-knowledge security.

📁 Project Structure
starkinsured_contracts/
├── README.md
├── Scarb.lock              # Dependency lockfile
├── Scarb.toml              # Project config
├── snfoundry.toml          # SNFoundry testing config
├── src/
│   ├── base/
│   │   └── types.cairo     # Shared type definitions
│   ├── starkinsured/
│   │   └── Policy.cairo    # Main insurance policy logic
│   ├── interfaces/
│   │   └── IPolicy.cairo   # Interface declarations
│   └── lib.cairo           # Core contract library
└── tests/
    └── test_Policy.cairo   # Unit tests for Policy contract
🧰 Prerequisites
Scarb – Cairo package manager

SNFoundry – Testing framework for StarkNet

⚙️ Installation
Clone the repository and install dependencies:

git clone https://github.com/Stark-Insured/starkinsured_contracts.git
cd starkinsured_contracts
🔐 Contract Overview
🛡️ Policy Contract
The Policy contract is the heart of Stark Insured. It handles:

Policy Creation – Issue new coverage contracts

Claim Verification – Use oracles to validate claims

Claim Settlement – Automate payouts and resolutions

Role-based Access – Insurers, claimants, verifiers

Risk Pooling – Decentralized coverage fund logic

🏗️ Building the Project
Compile all contracts using Scarb:

scarb build
🧪 Testing
Run all unit tests using SNFoundry:

snforge test
