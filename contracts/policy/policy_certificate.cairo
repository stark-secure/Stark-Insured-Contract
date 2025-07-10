// SPDX-License-Identifier: MIT
// @title Policy Certificate Contract
// @notice Pure registry/validator for policy certificates

#[starknet::contract]
mod PolicyCertificate {
    use starknet::{ContractAddress, get_block_timestamp};
    use core::traits::Into;

    #[storage]
    struct Storage {
        user_policy_id: LegacyMap<ContractAddress, u256>,
        user_policy_expiry: LegacyMap<ContractAddress, u64>,
        user_policy_revoked: LegacyMap<ContractAddress, bool>,
        user_policy_owner: LegacyMap<u256, ContractAddress>,
    }

    /// @notice Returns true if the user holds a valid, non-expired, non-revoked certificate
    #[view]
    fn is_valid_certificate(self: @ContractState, user: ContractAddress) -> bool {
        let policy_id = self.user_policy_id.read(user);
        if policy_id == 0 {
            return false;
        }
        let expiry = self.user_policy_expiry.read(user);
        let revoked = self.user_policy_revoked.read(user);
        let now = get_block_timestamp();
        policy_id != 0 && !revoked && now <= expiry
    }

    /// @notice Returns certificate details for a user
    #[view]
    fn get_certificate_details(self: @ContractState, user: ContractAddress) -> (policy_id: u256, expiry: u64, owner: ContractAddress, revoked: bool) {
        let policy_id = self.user_policy_id.read(user);
        let expiry = self.user_policy_expiry.read(user);
        let owner = self.user_policy_owner.read(policy_id);
        let revoked = self.user_policy_revoked.read(user);
        (policy_id, expiry, owner, revoked)
    }
}
