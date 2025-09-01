# Token contract tests for StarkInsuredToken
# Test minting, transfers, balances, supply, and edge/security cases

from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract
from starkware.cairo.common.uint256 import Uint256
import pytest

TOKEN_NAME = 0x537461726b496e7375726564546f6b656e  # "StarkInsuredToken"
TOKEN_SYMBOL = 0x534954  # "SIT"
TOKEN_DECIMALS = 18
INITIAL_SUPPLY = Uint256(1000, 0)
ZERO = Uint256(0, 0)
MAX_UINT256 = Uint256(2**128 - 1, 2**128 - 1)

@pytest.fixture(scope="module")
async def token_factory():
    starknet = await Starknet.empty()
    owner = 1234
    token = await starknet.deploy(
        source="contracts/token.cairo",
        constructor_calldata=[TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS, INITIAL_SUPPLY.low, INITIAL_SUPPLY.high]
    )
    return starknet, token, owner

@pytest.mark.asyncio
async def test_initial_supply(token_factory):
    _, token, _ = token_factory
    supply = await token.totalSupply().call()
    assert supply.result.supply == INITIAL_SUPPLY

@pytest.mark.asyncio
async def test_owner_can_mint(token_factory):
    _, token, _ = token_factory
    to = 5678
    amount = Uint256(100, 0)
    await token.mint(to, amount).invoke()
    bal = await token.balanceOf(to).call()
    assert bal.result.balance == amount

@pytest.mark.asyncio
async def test_non_owner_cannot_mint(token_factory):
    starknet, token, _ = token_factory
    to = 9999
    amount = Uint256(1, 0)
    # Simulate non-owner by changing context
    with pytest.raises(Exception):
        await token.mint(to, amount).invoke(caller_address=to)

@pytest.mark.asyncio
async def test_transfer(token_factory):
    _, token, _ = token_factory
    sender = 1234
    receiver = 4321
    amount = Uint256(10, 0)
    await token.transfer(receiver, amount).invoke(caller_address=sender)
    bal = await token.balanceOf(receiver).call()
    assert bal.result.balance == amount

@pytest.mark.asyncio
async def test_transfer_insufficient_balance(token_factory):
    _, token, _ = token_factory
    sender = 8888
    receiver = 7777
    amount = Uint256(1, 0)
    with pytest.raises(Exception):
        await token.transfer(receiver, amount).invoke(caller_address=sender)

@pytest.mark.asyncio
async def test_transfer_zero(token_factory):
    _, token, _ = token_factory
    sender = 1234
    receiver = 5678
    amount = ZERO
    await token.transfer(receiver, amount).invoke(caller_address=sender)
    bal = await token.balanceOf(receiver).call()
    # Should not change
    assert bal.result.balance == Uint256(100, 0)

@pytest.mark.asyncio
async def test_overflow_mint(token_factory):
    _, token, _ = token_factory
    to = 1234
    with pytest.raises(Exception):
        await token.mint(to, MAX_UINT256).invoke()


@pytest.mark.asyncio
async def test_approve_and_allowance(token_factory):
    _, token, _ = token_factory
    owner = 1234
    spender = 2222
    amount = Uint256(50, 0)
    await token.approve(spender, amount).invoke(caller_address=owner)
    allowed = await token.allowanceOf(owner, spender).call()
    assert allowed.result.remaining == amount

@pytest.mark.asyncio
async def test_transfer_from(token_factory):
    _, token, _ = token_factory
    owner = 1234
    spender = 2222
    receiver = 3333
    amount = Uint256(20, 0)
    # Approve first
    await token.approve(spender, amount).invoke(caller_address=owner)
    # Spender transfers from owner to receiver
    await token.transferFrom(owner, receiver, amount).invoke(caller_address=spender)
    bal = await token.balanceOf(receiver).call()
    assert bal.result.balance == amount
    # Allowance should be zero now
    allowed = await token.allowanceOf(owner, spender).call()
    assert allowed.result.remaining == Uint256(0, 0)

@pytest.mark.asyncio
async def test_transfer_from_insufficient_allowance(token_factory):
    _, token, _ = token_factory
    owner = 1234
    spender = 2222
    receiver = 3333
    amount = Uint256(10, 0)
    # Approve less than amount
    await token.approve(spender, Uint256(5, 0)).invoke(caller_address=owner)
    with pytest.raises(Exception):
        await token.transferFrom(owner, receiver, amount).invoke(caller_address=spender)

@pytest.mark.asyncio
async def test_transfer_from_insufficient_balance(token_factory):
    _, token, _ = token_factory
    owner = 1234
    spender = 2222
    receiver = 3333
    # Approve a large amount
    await token.approve(spender, Uint256(1000, 0)).invoke(caller_address=owner)
    # Drain owner's balance
    await token.transfer(receiver, Uint256(1000, 0)).invoke(caller_address=owner)
    # Now try transferFrom
    with pytest.raises(Exception):
        await token.transferFrom(owner, receiver, Uint256(1, 0)).invoke(caller_address=spender)

@pytest.mark.asyncio
async def test_approve_overwrite(token_factory):
    _, token, _ = token_factory
    owner = 1234
    spender = 2222
    await token.approve(spender, Uint256(10, 0)).invoke(caller_address=owner)
    await token.approve(spender, Uint256(20, 0)).invoke(caller_address=owner)
    allowed = await token.allowanceOf(owner, spender).call()
    assert allowed.result.remaining == Uint256(20, 0)

@pytest.mark.asyncio
async def test_approve_and_transfer_from_zero(token_factory):
    _, token, _ = token_factory
    owner = 1234
    spender = 2222
    receiver = 3333
    await token.approve(spender, Uint256(0, 0)).invoke(caller_address=owner)
    with pytest.raises(Exception):
        await token.transferFrom(owner, receiver, Uint256(1, 0)).invoke(caller_address=spender)

@pytest.mark.asyncio
async def test_name_symbol_decimals(token_factory):
    _, token, _ = token_factory
    name = await token.name().call()
    symbol = await token.symbol().call()
    decimals = await token.decimals().call()
    assert name.result.res == TOKEN_NAME
    assert symbol.result.res == TOKEN_SYMBOL
    assert decimals.result.res == TOKEN_DECIMALS
