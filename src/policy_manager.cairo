use starknet::ContractAddress;

#[starknet::interface]
trait IPolicyManager<TContractState> {
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_coverage_type(self: @TContractState) -> felt252;
    fn get_duration(self: @TContractState) -> u64;
    fn get_asset(self: @TContractState) -> ContractAddress;
    fn is_active(self: @TContractState) -> bool;
    fn activate_policy(ref self: TContractState);
    fn deactivate_policy(ref self: TContractState);
}

#[starknet::contract]
mod PolicyManager {
    use super::IPolicyManager;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        coverage_type: felt252,
        duration: u64,
        asset: ContractAddress,
        active: bool,
        created_at: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PolicyActivated: PolicyActivated,
        PolicyDeactivated: PolicyDeactivated,
    }

    #[derive(Drop, starknet::Event)]
    struct PolicyActivated {
        #[key]
        owner: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct PolicyDeactivated {
        #[key]
        owner: ContractAddress,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        coverage_type: felt252,
        duration: u64,
        asset: ContractAddress,
    ) {
        self.owner.write(owner);
        self.coverage_type.write(coverage_type);
        self.duration.write(duration);
        self.asset.write(asset);
        self.active.write(true); // Policies are active by default
        self.created_at.write(get_block_timestamp());
    }

    #[abi(embed_v0)]
    impl PolicyManagerImpl of IPolicyManager<ContractState> {
        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn get_coverage_type(self: @ContractState) -> felt252 {
            self.coverage_type.read()
        }

        fn get_duration(self: @ContractState) -> u64 {
            self.duration.read()
        }

        fn get_asset(self: @ContractState) -> ContractAddress {
            self.asset.read()
        }

        fn is_active(self: @ContractState) -> bool {
            self.active.read()
        }

        fn activate_policy(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can activate');

            self.active.write(true);

            self.emit(PolicyActivated { owner: caller, timestamp: get_block_timestamp() });
        }

        fn deactivate_policy(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can deactivate');

            self.active.write(false);

            self.emit(PolicyDeactivated { owner: caller, timestamp: get_block_timestamp() });
        }
    }
}
