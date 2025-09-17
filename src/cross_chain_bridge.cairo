use starknet::ContractAddress;

#[starknet::interface]
trait ICrossChainBridge<TContractState> {
    fn receive_message(
        ref self: TContractState,
        source_chain: felt252,
        message_hash: felt252,
        payload: Span<felt252>,
    );
    fn is_message_processed(self: @TContractState, message_hash: felt252) -> bool;
    fn get_trusted_chains(self: @TContractState) -> Span<felt252>;
}

#[starknet::contract]
mod CrossChainBridge {
    use super::ICrossChainBridge;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };

    #[storage]
    struct Storage {
        // Replay protection: track processed message hashes
        processed_messages: Map<felt252, bool>,
        // Trusted source chains (e.g., Ethereum chain ID)
        trusted_chains: Map<felt252, bool>,
        // Contract owner for admin functions
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CrossChainClaimReceived: CrossChainClaimReceived,
        MessageProcessed: MessageProcessed,
        TrustedChainAdded: TrustedChainAdded,
    }

    #[derive(Drop, starknet::Event)]
    struct CrossChainClaimReceived {
        #[key]
        policy_id: felt252,
        #[key]
        user: ContractAddress,
        claim_data: Span<felt252>,
        source_chain: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct MessageProcessed {
        #[key]
        message_hash: felt252,
        source_chain: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct TrustedChainAdded {
        #[key]
        chain_id: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, trusted_chains: Span<felt252>) {
        self.owner.write(owner);

        // Initialize trusted chains (e.g., Ethereum mainnet)
        let mut i = 0;
        loop {
            if i >= trusted_chains.len() {
                break;
            }
            let chain_id = *trusted_chains.at(i);
            self.trusted_chains.entry(chain_id).write(true);
            self.emit(TrustedChainAdded { chain_id });
            i += 1;
        };
    }

    #[abi(embed_v0)]
    impl CrossChainBridgeImpl of ICrossChainBridge<ContractState> {
        /// Receives and processes cross-chain messages
        /// @param source_chain: Chain ID of the originating chain
        /// @param message_hash: Unique hash of the message for replay protection
        /// @param payload: Message payload containing claim data
        fn receive_message(
            ref self: ContractState,
            source_chain: felt252,
            message_hash: felt252,
            payload: Span<felt252>,
        ) {
            // 1. Validate source chain is trusted
            assert(self.trusted_chains.entry(source_chain).read(), 'Untrusted source chain');

            // 2. Replay protection - check if message already processed
            assert(
                !self.processed_messages.entry(message_hash).read(), 'Message already processed',
            );

            // 3. Validate message structure
            assert(payload.len() >= 3, 'Invalid payload length');

            // 4. Parse payload: [policy_id, user_address_low, user_address_high, ...claim_data]
            let policy_id = *payload.at(0);
            let user_low = *payload.at(1);
            let user_high = *payload.at(2);

            // Reconstruct user address from low and high parts
            let user_address = starknet::contract_address_from_felt252(
                user_low + user_high * 0x100000000000000000000000000000000,
            );

            // Extract claim data (remaining payload)
            let mut claim_data = ArrayTrait::new();
            let mut i = 3;
            loop {
                if i >= payload.len() {
                    break;
                }
                claim_data.append(*payload.at(i));
                i += 1;
            };

            // 5. Mark message as processed
            self.processed_messages.entry(message_hash).write(true);

            // 6. Emit events
            self.emit(MessageProcessed { message_hash, source_chain });

            self
                .emit(
                    CrossChainClaimReceived {
                        policy_id,
                        user: user_address,
                        claim_data: claim_data.span(),
                        source_chain,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Check if a message has been processed
        fn is_message_processed(self: @ContractState, message_hash: felt252) -> bool {
            self.processed_messages.entry(message_hash).read()
        }

        /// Get list of trusted chain IDs
        fn get_trusted_chains(self: @ContractState) -> Span<felt252> {
            // Note: In a real implementation, you'd store this as an array
            // For simplicity, returning common chain IDs
            let mut chains = ArrayTrait::new();
            chains.append(1); // Ethereum mainnet
            chains.append(5); // Goerli testnet
            chains.span()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Add a new trusted chain (admin only)
        fn add_trusted_chain(ref self: ContractState, chain_id: felt252) {
            assert(get_caller_address() == self.owner.read(), 'Only owner can add chains');
            self.trusted_chains.entry(chain_id).write(true);
            self.emit(TrustedChainAdded { chain_id });
        }

        /// Validate message signature/proof (stubbed for now)
        fn validate_message_proof(
            self: @ContractState, message_hash: felt252, proof: Span<felt252>,
        ) -> bool {
            // TODO: Implement actual signature/proof validation
            // For now, return true (mock validation)
            true
        }
    }
}
