use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct Policy {
    pub id: u256,
    pub holder: ContractAddress,
    pub coverage_amount: u256,
    pub premium: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub policy_type: u8,
    pub is_active: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Claim {
    pub id: u256,
    pub policy_id: u256,
    pub claimant: ContractAddress,
    pub amount: u256,
    pub evidence_hash: felt252,
    pub timestamp: u64,
    pub status: u8 // 0: Pending, 1: Approved, 2: Rejected
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Proposal {
    pub id: u256,
    pub proposer: ContractAddress,
    pub title: felt252,
    pub description: felt252,
    pub votes_for: u256,
    pub votes_against: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub executed: bool,
}

#[starknet::interface]
pub trait IPolicyManager<TContractState> {
    fn create_policy(
        ref self: TContractState,
        policy_holder: ContractAddress,
        coverage_amount: u256,
        duration: u64,
        policy_type: u8,
    ) -> u256;
    fn get_policy(self: @TContractState, policy_id: u256) -> Policy;
    fn pay_premium(ref self: TContractState, policy_id: u256, amount: u256);
    fn is_policy_active(self: @TContractState, policy_id: u256) -> bool;
    fn calculate_premium(
        self: @TContractState, coverage_amount: u256, duration: u64, policy_type: u8,
    ) -> u256;
    fn get_total_policies(self: @TContractState) -> u256;
}

#[starknet::interface]
pub trait IClaimsProcessor<TContractState> {
    fn submit_claim(
        ref self: TContractState, policy_id: u256, claim_amount: u256, evidence_hash: felt252,
    ) -> u256;
    fn process_claim(ref self: TContractState, claim_id: u256, approved: bool);
    fn get_claim(self: @TContractState, claim_id: u256) -> Claim;
    fn get_claims_by_policy(self: @TContractState, policy_id: u256) -> Array<u256>;
    fn can_submit_claim(self: @TContractState, claimant: ContractAddress) -> bool;
}

#[starknet::interface]
pub trait IRiskPool<TContractState> {
    fn deposit(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, amount: u256);
    fn get_balance(self: @TContractState) -> u256;
    fn get_user_balance(self: @TContractState, user: ContractAddress) -> u256;
    fn calculate_risk_score(self: @TContractState, user: ContractAddress) -> u256;
    fn process_payout(ref self: TContractState, recipient: ContractAddress, amount: u256);
}

#[starknet::interface]
pub trait IDAOGovernance<TContractState> {
    fn create_proposal(
        ref self: TContractState,
        title: felt252,
        description: felt252,
        execution_data: Span<felt252>,
    ) -> u256;
    fn vote(ref self: TContractState, proposal_id: u256, support: bool, voting_power: u256);
    fn execute_proposal(ref self: TContractState, proposal_id: u256);
    fn get_proposal(self: @TContractState, proposal_id: u256) -> Proposal;
    fn get_voting_power(self: @TContractState, user: ContractAddress) -> u256;
}

#[starknet::interface]
pub trait IPauseable<TContractState> {
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
}


/// @title Contract Registry Interface
/// @notice Interface for the central contract registry that stores and retrieves protocol component addresses
#[starknet::interface]
pub trait IContractRegistry<TContractState> {
    /// @notice Register a contract address with a unique name identifier
    /// @param name The unique identifier for the contract
    /// @param address The contract address to register
    /// @dev Only callable by the contract owner
    fn register_contract(ref self: TContractState, name: felt252, address: ContractAddress);
    
    /// @notice Retrieve a contract address by its name identifier
    /// @param name The unique identifier for the contract
    /// @return The contract address associated with the name
    fn get_address(self: @TContractState, name: felt252) -> ContractAddress;
    
    /// @notice Check if a contract name is registered
    /// @param name The unique identifier to check
    /// @return True if the name is registered, false otherwise
    fn is_registered(self: @TContractState, name: felt252) -> bool;
    
    /// @notice Get all registered contract names
    /// @return Array of all registered contract names
    fn get_all_names(self: @TContractState) -> Array<felt252>;
    
    /// @notice Remove a contract from the registry
    /// @param name The unique identifier for the contract to remove
    /// @dev Only callable by the contract owner
    fn unregister_contract(ref self: TContractState, name: felt252);
}
