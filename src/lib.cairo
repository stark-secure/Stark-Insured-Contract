pub mod constants;
pub mod errors;
pub mod events;
pub mod interfaces;
pub mod utils;

// Re-export errors
pub use errors::{ClaimErrors, GovernanceErrors, PolicyErrors, PoolErrors, RegistryErrors};

// Re-export events
pub use events::{
    ClaimProcessed, ClaimSubmitted, PolicyCreated, PoolDeposit, ProposalCreated,
    ContractRegistered, ContractUnregistered, ContractUpdated
};

// Re-export main interfaces
pub use interfaces::{
    IClaimsProcessor, IClaimsProcessorDispatcher, IClaimsProcessorDispatcherTrait, 
    IContractRegistry, IContractRegistryDispatcher, IContractRegistryDispatcherTrait,
    IDAOGovernance, IDAOGovernanceDispatcher, IDAOGovernanceDispatcherTrait, 
    IPolicyManager, IPolicyManagerDispatcher, IPolicyManagerDispatcherTrait, 
    IRiskPool, IRiskPoolDispatcher, IRiskPoolDispatcherTrait,
};
