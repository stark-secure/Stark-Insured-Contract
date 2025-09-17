use core::traits::Into;
use starknet::{ContractAddress, get_block_timestamp};

pub fn is_valid_address(address: ContractAddress) -> bool {
    address.into() != 0
}

pub fn calculate_premium_amount(coverage: u256, duration: u64, risk_score: u256) -> u256 {
    let base_premium = (coverage * crate::constants::BASE_PREMIUM_RATE) / 10000;
    let duration_factor = duration.into() / crate::constants::SECONDS_IN_DAY.into();
    let risk_adjustment = (base_premium * risk_score) / 1000;

    base_premium + risk_adjustment * duration_factor
}

pub fn is_within_cooldown(last_claim_time: u64) -> bool {
    let current_time = get_block_timestamp();
    current_time - last_claim_time < crate::constants::CLAIM_COOLDOWN_PERIOD
}

pub fn calculate_risk_score_basic(claim_history: u256, deposit_amount: u256) -> u256 {
    if claim_history == 0 {
        return 100; // Base risk score
    }

    let risk_factor = claim_history * 50;
    let deposit_factor = if deposit_amount > 0 {
        1000 / deposit_amount
    } else {
        1000
    };

    100 + risk_factor + deposit_factor
}

pub fn is_proposal_ready_for_execution(
    votes_for: u256, votes_against: u256, end_time: u64, execution_delay: u64,
) -> bool {
    let current_time = get_block_timestamp();
    let total_votes = votes_for + votes_against;

    // Check if voting period ended and execution delay passed
    current_time >= end_time
        + execution_delay
            && // Check if quorum reached
            total_votes >= crate::constants::QUORUM_THRESHOLD
            && // Check if majority achieved
            votes_for
            * 100 > total_votes
            * crate::constants::PROPOSAL_THRESHOLD.into()
}
