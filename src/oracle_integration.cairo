use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

#[starknet::interface]
trait IOracleIntegration<TContractState> {
    fn submit_data(
        ref self: TContractState, oracle_id: ContractAddress, payload: felt252, timestamp: u64,
    );
    fn validate_data(self: @TContractState, oracle_id: ContractAddress, claim_id: felt252) -> bool;
    fn trigger_claim(ref self: TContractState, claim_id: felt252);
    fn add_trusted_oracle(ref self: TContractState, oracle_address: ContractAddress);
    fn remove_trusted_oracle(ref self: TContractState, oracle_address: ContractAddress);
    fn is_trusted_oracle(self: @TContractState, oracle_address: ContractAddress) -> bool;
    fn get_oracle_data(self: @TContractState, oracle_id: ContractAddress) -> (felt252, u64);
    fn set_data_validity_window(ref self: TContractState, window_seconds: u64);
}

#[starknet::contract]
mod OracleIntegration {
    use super::IOracleIntegration;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        trusted_oracles: Map<ContractAddress, bool>,
        oracle_data: Map<ContractAddress, (felt252, u64)>, // (payload, timestamp)
        oracle_nonces: Map<ContractAddress, u64>, // For replay protection
        data_validity_window: u64, // Seconds
        claim_triggers: Map<felt252, bool> // Track triggered claims
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OracleUpdated: OracleUpdated,
        ClaimTriggered: ClaimTriggered,
        TrustedOracleAdded: TrustedOracleAdded,
        TrustedOracleRemoved: TrustedOracleRemoved,
    }

    #[derive(Drop, starknet::Event)]
    struct OracleUpdated {
        oracle_id: ContractAddress,
        payload: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ClaimTriggered {
        claim_id: felt252,
        triggered_by_oracle_id: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TrustedOracleAdded {
        oracle_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TrustedOracleRemoved {
        oracle_address: ContractAddress,
    }

    /// @notice Initializes the oracle integration contract
    /// @dev Sets the owner and default data validity window to 1 hour
    /// @param owner The address that will own this contract
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.data_validity_window.write(3600); // Default: 1 hour
    }

    #[abi(embed_v0)]
    impl OracleIntegrationImpl of IOracleIntegration<ContractState> {
        /// @notice Allows trusted oracles to submit data with security checks
        /// @dev Validates oracle trust, timestamp freshness, and prevents replay attacks
        /// @param oracle_id The address of the oracle submitting data
        /// @param payload The data payload being submitted
        /// @param timestamp The timestamp when the data was created
        fn submit_data(
            ref self: ContractState, oracle_id: ContractAddress, payload: felt252, timestamp: u64,
        ) {
            // Security checks
            assert(self.is_trusted_oracle(oracle_id), 'Oracle not trusted');

            let current_time = get_block_timestamp();
            assert(timestamp <= current_time, 'Future timestamp not allowed');

            // Check data freshness
            let validity_window = self.data_validity_window.read();
            assert(current_time - timestamp <= validity_window, 'Data too old');

            // Replay protection
            let last_nonce = self.oracle_nonces.entry(oracle_id).read();
            assert(timestamp > last_nonce, 'Replay attack detected');

            // Store data and update nonce
            self.oracle_data.entry(oracle_id).write((payload, timestamp));
            self.oracle_nonces.entry(oracle_id).write(timestamp);

            // Emit event
            self.emit(OracleUpdated { oracle_id, payload, timestamp });
        }

        /// @notice Validates oracle data for claim processing
        /// @dev Checks oracle trust, data existence, and freshness
        /// @param oracle_id The address of the oracle to validate data from
        /// @param claim_id The claim ID being validated (currently unused in logic)
        /// @return True if data is valid, false otherwise
        fn validate_data(
            self: @ContractState, oracle_id: ContractAddress, claim_id: felt252,
        ) -> bool {
            // Check if oracle is trusted
            if !self.is_trusted_oracle(oracle_id) {
                return false;
            }

            // Get oracle data
            let (payload, timestamp) = self.oracle_data.entry(oracle_id).read();

            // Check if data exists
            if timestamp == 0 {
                return false;
            }

            // Check data freshness
            let current_time = get_block_timestamp();
            let validity_window = self.data_validity_window.read();
            if current_time - timestamp > validity_window {
                return false;
            }

            // Additional validation logic can be added here
            // For now, we assume any fresh data from trusted oracle is valid
            true
        }

        /// @notice Triggers a claim based on oracle validation
        /// @dev Only trusted oracles or owner can trigger claims, prevents double triggering
        /// @param claim_id The unique identifier for the claim being triggered
        fn trigger_claim(ref self: ContractState, claim_id: felt252) {
            let caller = get_caller_address();

            // Check if caller is trusted oracle or owner
            let is_authorized = self.is_trusted_oracle(caller) || caller == self.owner.read();
            assert(is_authorized, 'Unauthorized caller');

            // Prevent double triggering
            assert(!self.claim_triggers.entry(claim_id).read(), 'Claim already triggered');

            // Mark claim as triggered
            self.claim_triggers.entry(claim_id).write(true);

            // Emit event
            self.emit(ClaimTriggered { claim_id, triggered_by_oracle_id: caller });
        }

        /// @notice Adds an oracle to the trusted list
        /// @dev Only owner can add trusted oracles
        /// @param oracle_address The address of the oracle to trust
        fn add_trusted_oracle(ref self: ContractState, oracle_address: ContractAddress) {
            self._only_owner();
            self.trusted_oracles.entry(oracle_address).write(true);
            self.emit(TrustedOracleAdded { oracle_address });
        }

        /// @notice Removes an oracle from the trusted list
        /// @dev Only owner can remove trusted oracles
        /// @param oracle_address The address of the oracle to remove from trusted list
        fn remove_trusted_oracle(ref self: ContractState, oracle_address: ContractAddress) {
            self._only_owner();
            self.trusted_oracles.entry(oracle_address).write(false);
            self.emit(TrustedOracleRemoved { oracle_address });
        }

        /// @notice Checks if an oracle is in the trusted list
        /// @param oracle_address The address to check
        /// @return True if the oracle is trusted, false otherwise
        fn is_trusted_oracle(self: @ContractState, oracle_address: ContractAddress) -> bool {
            self.trusted_oracles.entry(oracle_address).read()
        }

        /// @notice Retrieves stored oracle data
        /// @param oracle_id The address of the oracle to get data from
        /// @return A tuple containing (payload, timestamp) of the oracle data
        fn get_oracle_data(self: @ContractState, oracle_id: ContractAddress) -> (felt252, u64) {
            self.oracle_data.entry(oracle_id).read()
        }

        /// @notice Sets the time window for data validity
        /// @dev Only owner can set the validity window, must be > 0
        /// @param window_seconds The number of seconds data remains valid
        fn set_data_validity_window(ref self: ContractState, window_seconds: u64) {
            self._only_owner();
            assert(window_seconds > 0, 'Invalid validity window');
            self.data_validity_window.write(window_seconds);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// @notice Internal function to restrict access to owner only
        /// @dev Reverts with error message if caller is not the owner
        fn _only_owner(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner allowed');
        }
    }
}
