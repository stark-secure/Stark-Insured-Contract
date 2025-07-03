use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct PolicyCreated {
    #[key]
    pub policy_id: u256,
    #[key]
    pub holder: ContractAddress,
    pub coverage_amount: u256,
    pub premium: u256,
    pub policy_type: u8,
}

#[derive(Drop, starknet::Event)]
pub struct PremiumPaid {
    #[key]
    pub policy_id: u256,
    #[key]
    pub payer: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct ClaimSubmitted {
    #[key]
    pub claim_id: u256,
    #[key]
    pub policy_id: u256,
    #[key]
    pub claimant: ContractAddress,
    pub amount: u256,
    pub evidence_hash: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct ClaimProcessed {
    #[key]
    pub claim_id: u256,
    #[key]
    pub claimant: ContractAddress,
    pub approved: bool,
    pub payout_amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct PoolDeposit {
    #[key]
    pub depositor: ContractAddress,
    pub amount: u256,
    pub new_balance: u256,
}

#[derive(Drop, starknet::Event)]
pub struct PoolWithdrawal {
    #[key]
    pub withdrawer: ContractAddress,
    pub amount: u256,
    pub new_balance: u256,
}

#[derive(Drop, starknet::Event)]
pub struct ProposalCreated {
    #[key]
    pub proposal_id: u256,
    #[key]
    pub proposer: ContractAddress,
    pub title: felt252,
    pub description: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct VoteCast {
    #[key]
    pub proposal_id: u256,
    #[key]
    pub voter: ContractAddress,
    pub support: bool,
    pub voting_power: u256,
}

#[derive(Drop, starknet::Event)]
pub struct ProposalExecuted {
    #[key]
    pub proposal_id: u256,
    pub success: bool,
}

#[derive(Drop, starknet::Event)]
pub struct ContractRegistered {
    #[key]
    pub name: felt252,
    #[key]
    pub address: ContractAddress,
    pub registered_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ContractUnregistered {
    #[key]
    pub name: felt252,
    pub unregistered_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ContractUpdated {
    #[key]
    pub name: felt252,
    pub old_address: ContractAddress,
    pub new_address: ContractAddress,
    pub updated_by: ContractAddress,
}

// Remove the duplicate events at the end of the file
#[derive(Drop, starknet::Event)]
pub struct ContractRegistered {
    #[key]
    pub name: felt252,
    #[key]
    pub address: ContractAddress,
    pub registered_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ContractUnregistered {
    #[key]
    pub name: felt252,
    pub unregistered_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ContractUpdated {
    #[key]
    pub name: felt252,
    pub old_address: ContractAddress,
    pub new_address: ContractAddress,
    pub updated_by: ContractAddress,
}
