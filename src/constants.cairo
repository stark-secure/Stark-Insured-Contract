// Policy Types
pub const HEALTH_INSURANCE: u8 = 1;
pub const AUTO_INSURANCE: u8 = 2;
pub const PROPERTY_INSURANCE: u8 = 3;
pub const LIFE_INSURANCE: u8 = 4;

// Claim Status
pub const CLAIM_PENDING: u8 = 0;
pub const CLAIM_APPROVED: u8 = 1;
pub const CLAIM_REJECTED: u8 = 2;

// Time Constants
pub const SECONDS_IN_DAY: u64 = 86400;
pub const CLAIM_COOLDOWN_PERIOD: u64 = 86400; // 24 hours
pub const VOTING_PERIOD: u64 = 604800; // 7 days
pub const EXECUTION_DELAY: u64 = 172800; // 2 days

// Financial Constants
pub const MAX_COVERAGE_AMOUNT: u256 = 1000000000000000000000000; // 1M tokens
pub const MIN_COVERAGE_AMOUNT: u256 = 1000000000000000000; // 1 token
pub const BASE_PREMIUM_RATE: u256 = 100; // 1% base rate
pub const RISK_MULTIPLIER: u256 = 50; // Risk adjustment factor

// Governance Constants
pub const MIN_PROPOSAL_STAKE: u256 = 10000000000000000000000; // 10K tokens
pub const QUORUM_THRESHOLD: u256 = 100000000000000000000000; // 100K tokens
pub const PROPOSAL_THRESHOLD: u256 = 51; // 51% majority
