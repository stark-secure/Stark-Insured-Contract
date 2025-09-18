use contracts::counter::ICounterDispatcherTrait;
use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address};
use contracts::counter::{ICounterDispatcher};
use contracts::counter::CounterContract::{CounterChanged, ChangeReason, Event};

fn owner_address() -> ContractAddress {
"owner".try_into().unwrap()
}

fn user_address() -> ContractAddress {
"user".try_into().unwrap()
}

fn deploy_counter(init_counter: u32) -> ICounterDispatcher {
    let owner_address: ContractAddress = owner_address();

    let contract = declare{"CounterContract"}.unwrap()contract_class();   
    
    let mut constructor_args = array![];
    init_counter.serialize(ref constructor_args);
    owner_address.serialize(ref constructor_args);

    let {contract_address, _} = contract.deploy(@constructor_args).unwrap();

    let dispatcher = ICounterDispatcher{contract_address: contract_address}
}

#[test]
fn test_contract_initialization() {
    let dispatcher = deploy_counter(5);

    let current_counter = dispatcher.get_counter();
    let expected_counter:u32 = 5;
    assert!(current_counter == expected_counter, "Initialization of counter failed");
}

#[test]
fn test_increase_counter() {
let init_counter: u32 = 0;
let dispatcher = deploy_counter(init_counter);
let mut spy = spy_events();

start_cheat_caller_address(dispatcher.contract_address, user_address());
dispatcher.increase_counter();
stop_cheat_caller_address(dispatcher.contract_address);
let current_counter = dispatcher.get_counter();

assert!(current_counter == 1, "Increase counter function doesnt't work");


let expected_event = CounterChanged {
    caller: user_address(),
    old_value: 0,
    new_value: 1,
    reason: ChangeReason::Increase,
};

spy.assert_emitted(@array![
    dispatcher.contract_address,
    Event::CounterChanged(expected_event),
]);
}

#[test]
fn test_decrease_counter_happy_path() {
    let init_counter: u32 = 4;
let dispatcher = deploy_counter(init_counter);

dispatcher.decrease_counter();
let current_counter = dispatcher.get_counter();

assert!(current_counter == 3, "Decrease counter function doesnt't work")
}

#[test]
#[should_panic(expected: "The counter can't be negative")]
fn test_decrease_counter_fail_path() {
    let init_counter: u32 = 0;
let dispatcher = deploy_counter(init_counter);

dispatcher.decrease_counter();
dispatcher.get_counter();
}


