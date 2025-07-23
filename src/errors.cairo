pub mod PolicyErrors {
    pub const INVALID_COVERAGE_AMOUNT: felt252 = 'Invalid coverage amount';
    pub const INVALID_DURATION: felt252 = 'Invalid duration';
    pub const POLICY_NOT_FOUND: felt252 = 'Policy not found';
    pub const POLICY_EXPIRED: felt252 = 'Policy expired';
    pub const POLICY_NOT_ACTIVE: felt252 = 'Policy not active';
    pub const INSUFFICIENT_PREMIUM: felt252 = 'Insufficient premium';
    pub const UNAUTHORIZED_ACCESS: felt252 = 'Unauthorized access';
}

pub mod ClaimErrors {
    pub const CLAIM_NOT_FOUND: felt252 = 'Claim not found';
    pub const INVALID_CLAIM_AMOUNT: felt252 = 'Invalid claim amount';
    pub const CLAIM_COOLDOWN_ACTIVE: felt252 = 'Claim cooldown active';
    pub const CLAIM_ALREADY_PROCESSED: felt252 = 'Claim already processed';
    pub const INSUFFICIENT_POOL_BALANCE: felt252 = 'Insufficient pool balance';
    pub const INVALID_EVIDENCE: felt252 = 'Invalid evidence';
}

pub mod PoolErrors {
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
    pub const WITHDRAWAL_FAILED: felt252 = 'Withdrawal failed';
    pub const DEPOSIT_FAILED: felt252 = 'Deposit failed';
}

pub mod GovernanceErrors {
    pub const PROPOSAL_NOT_FOUND: felt252 = 'Proposal not found';
    pub const INSUFFICIENT_STAKE: felt252 = 'Insufficient stake';
    pub const VOTING_PERIOD_ENDED: felt252 = 'Voting period ended';
    pub const PROPOSAL_NOT_READY: felt252 = 'Proposal not ready';
    pub const ALREADY_EXECUTED: felt252 = 'Already executed';
    pub const INSUFFICIENT_VOTES: felt252 = 'Insufficient votes';
}

pub mod RegistryErrors {
    pub const CONTRACT_NOT_FOUND: felt252 = 'Contract not found';
    pub const CONTRACT_ALREADY_REGISTERED: felt252 = 'Contract already registered';
    pub const INVALID_CONTRACT_NAME: felt252 = 'Invalid contract name';
    pub const INVALID_CONTRACT_ADDRESS: felt252 = 'Invalid contract address';
    pub const UNAUTHORIZED_ACCESS: felt252 = 'Unauthorized access';
}

pub mod RegistryErrors {
    pub const CONTRACT_NOT_FOUND: felt252 = 'Contract not found';
    pub const INVALID_CONTRACT_NAME: felt252 = 'Invalid contract name';
    pub const INVALID_CONTRACT_ADDRESS: felt252 = 'Invalid contract address';
    pub const UNAUTHORIZED_ACCESS: felt252 = 'Unauthorized access';
}

// Remove the duplicate RegistryErrors module at the end
