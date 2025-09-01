// SPDX-License-Identifier: MIT
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_eq, uint256_le, uint256_lt
from starkware.cairo.common.uint256 import uint256_gt
from starkware.cairo.common.uint256 import uint256_zero
from starkware.starknet.common.syscalls import get_caller_address

@storage_var
func balances(account: felt) -> (res: Uint256):
end

@storage_var
func total_supply() -> (res: Uint256):
end

@storage_var
func owner() -> (res: felt):
end


@storage_var
func allowance(owner: felt, spender: felt) -> (res: Uint256):
end

@event
func Transfer(from_: felt, to: felt, value: Uint256):
end

@event
func Mint(to: felt, value: Uint256):
end

@event
func Approval(owner: felt, spender: felt, value: Uint256):
end

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    name_: felt, symbol_: felt, decimals_: felt, initial_supply: Uint256
):
    let (caller) = get_caller_address()
    owner.write(caller)
    total_supply.write(initial_supply)
    balances.write(caller, initial_supply)
    return ()
end

@external
func mint{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(to: felt, amount: Uint256):
    let (caller) = get_caller_address()
    let (stored_owner) = owner.read()
    assert caller = stored_owner
    let (current_supply) = total_supply.read()
    let (new_supply, overflow) = uint256_add(current_supply, amount)
    assert overflow = 0
    total_supply.write(new_supply)
    let (current_balance) = balances.read(to)
    let (new_balance, overflow2) = uint256_add(current_balance, amount)
    assert overflow2 = 0
    balances.write(to, new_balance)
    Mint.emit(to, amount)
    return ()
end


@external
func transfer{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(to: felt, amount: Uint256) -> (success: felt):
    let (caller) = get_caller_address()
    let (from_balance) = balances.read(caller)
    let (enough) = uint256_le(amount, from_balance)
    assert enough = 1
    let (new_from_balance, _) = uint256_sub(from_balance, amount)
    balances.write(caller, new_from_balance)
    let (to_balance) = balances.read(to)
    let (new_to_balance, overflow) = uint256_add(to_balance, amount)
    assert overflow = 0
    balances.write(to, new_to_balance)
    Transfer.emit(caller, to, amount)
    return (1)
end

@external
func approve{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(spender: felt, amount: Uint256) -> (success: felt):
    let (caller) = get_caller_address()
    allowance.write(caller, spender, amount)
    Approval.emit(caller, spender, amount)
    return (1)
end

@external
func transferFrom{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(from_: felt, to: felt, amount: Uint256) -> (success: felt):
    let (caller) = get_caller_address()
    let (allowed) = allowance.read(from_, caller)
    let (enough_allowance) = uint256_le(amount, allowed)
    assert enough_allowance = 1
    let (from_balance) = balances.read(from_)
    let (enough_balance) = uint256_le(amount, from_balance)
    assert enough_balance = 1
    let (new_from_balance, _) = uint256_sub(from_balance, amount)
    balances.write(from_, new_from_balance)
    let (to_balance) = balances.read(to)
    let (new_to_balance, overflow) = uint256_add(to_balance, amount)
    assert overflow = 0
    balances.write(to, new_to_balance)
    let (new_allowance, _) = uint256_sub(allowed, amount)
    allowance.write(from_, caller, new_allowance)
    Transfer.emit(from_, to, amount)
    return (1)
end


@view
func balanceOf(account: felt) -> (balance: Uint256):
    let (bal) = balances.read(account)
    return (bal)
end

@view
func allowanceOf(owner_: felt, spender: felt) -> (remaining: Uint256):
    let (allowed) = allowance.read(owner_, spender)
    return (allowed)
end

@view
func totalSupply() -> (supply: Uint256):
    let (supply) = total_supply.read()
    return (supply)
end

@view
func name() -> (res: felt):
    return (0x537461726b496e7375726564546f6b656e) // "StarkInsuredToken" as felt
end

@view
func symbol() -> (res: felt):
    return (0x534954) // "SIT" as felt
end

@view
func decimals() -> (res: felt):
    return (18)
end
