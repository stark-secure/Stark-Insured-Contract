/// @title Contract Registry
/// @notice Central registry for storing and retrieving protocol component addresses
/// @dev Provides a single source of truth for all contract addresses in the ecosystem
#[starknet::contract]
mod ContractRegistry {
    use openzeppelin::access::ownable::OwnableComponent;
    use stark_insured::errors::RegistryErrors;
    use stark_insured::events::{ContractRegistered, ContractUnregistered, ContractUpdated};
    use stark_insured::interfaces::IContractRegistry;
    use starknet::{ContractAddress, get_caller_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        /// @dev Maps contract names to their addresses
        registry: LegacyMap<felt252, ContractAddress>,
        /// @dev Tracks registered contract names for enumeration
        registered_names: LegacyMap<u32, felt252>,
        /// @dev Total count of registered contracts
        registered_count: u32,
        /// @dev Maps contract names to their index in registered_names
        name_to_index: LegacyMap<felt252, u32>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ContractRegistered: ContractRegistered,
        ContractUnregistered: ContractUnregistered,
        ContractUpdated: ContractUpdated,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    /// @notice Initialize the contract registry with an owner
    /// @param owner The address that will own and manage the registry
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.registered_count.write(0);
    }

    #[abi(embed_v0)]
    impl ContractRegistryImpl of IContractRegistry<ContractState> {
        /// @notice Register a contract address with a unique name identifier
        /// @param name The unique identifier for the contract (must be non-zero)
        /// @param address The contract address to register (must be non-zero)
        /// @dev Only callable by the contract owner
        /// @dev Emits ContractRegistered or ContractUpdated event
        fn register_contract(ref self: ContractState, name: felt252, address: ContractAddress) {
            // Access control
            self.ownable.assert_only_owner();
            
            // Input validation
            assert(name != 0, RegistryErrors::INVALID_CONTRACT_NAME);
            assert(!address.is_zero(), RegistryErrors::INVALID_CONTRACT_ADDRESS);
            
            let caller = get_caller_address();
            let existing_address = self.registry.read(name);
            
            if existing_address.is_zero() {
                // New registration
                self.registry.write(name, address);
                
                // Add to enumeration
                let count = self.registered_count.read();
                self.registered_names.write(count, name);
                self.name_to_index.write(name, count);
                self.registered_count.write(count + 1);
                
                self.emit(ContractRegistered { name, address, registered_by: caller });
            } else {
                // Update existing registration
                self.registry.write(name, address);
                self.emit(ContractUpdated { 
                    name, 
                    old_address: existing_address, 
                    new_address: address, 
                    updated_by: caller 
                });
            }
        }
        
        /// @notice Retrieve a contract address by its name identifier
        /// @param name The unique identifier for the contract
        /// @return The contract address associated with the name
        /// @dev Returns zero address if name is not registered
        fn get_address(self: @ContractState, name: felt252) -> ContractAddress {
            let address = self.registry.read(name);
            assert(!address.is_zero(), RegistryErrors::CONTRACT_NOT_FOUND);
            address
        }
        
        /// @notice Check if a contract name is registered
        /// @param name The unique identifier to check
        /// @return True if the name is registered, false otherwise
        fn is_registered(self: @ContractState, name: felt252) -> bool {
            !self.registry.read(name).is_zero()
        }
        
        /// @notice Get all registered contract names
        /// @return Array of all registered contract names
        fn get_all_names(self: @ContractState) -> Array<felt252> {
            let mut names = ArrayTrait::new();
            let count = self.registered_count.read();
            
            let mut i: u32 = 0;
            while i < count {
                let name = self.registered_names.read(i);
                if name != 0 { // Skip removed entries
                    names.append(name);
                }
                i += 1;
            };
            
            names
        }
        
        /// @notice Remove a contract from the registry
        /// @param name The unique identifier for the contract to remove
        /// @dev Only callable by the contract owner
        /// @dev Emits ContractUnregistered event
        fn unregister_contract(ref self: ContractState, name: felt252) {
            // Access control
            self.ownable.assert_only_owner();
            
            // Check if contract exists
            let address = self.registry.read(name);
            assert(!address.is_zero(), RegistryErrors::CONTRACT_NOT_FOUND);
            
            // Remove from registry
            self.registry.write(name, starknet::contract_address_const::<0>());
            
            // Remove from enumeration by setting to zero
            let index = self.name_to_index.read(name);
            self.registered_names.write(index, 0);
            self.name_to_index.write(name, 0);
            
            let caller = get_caller_address();
            self.emit(ContractUnregistered { name, unregistered_by: caller });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// @notice Internal helper to validate contract name
        /// @param name The name to validate
        /// @return True if valid, false otherwise
        fn is_valid_name(self: @ContractState, name: felt252) -> bool {
            name != 0
        }
        
        /// @notice Internal helper to validate contract address
        /// @param address The address to validate
        /// @return True if valid, false otherwise
        fn is_valid_address(self: @ContractState, address: ContractAddress) -> bool {
            !address.is_zero()
        }
    }
}