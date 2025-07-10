
# Unit tests for claimable_amount view function in RiskPool
from starkware.starknet.testing.starknet import Starknet
import asyncio
import pytest

@pytest.mark.asyncio
async def test_claimable_amount_valid():
    # Setup: deploy contracts, set active policy, set oracle event, set pool balance
    # Call claimable_amount for user with valid claim
    # Assert correct amount is returned
    pass

@pytest.mark.asyncio
async def test_claimable_amount_no_policy():
    # Setup: deploy contracts, user has no active policy
    # Call claimable_amount for user
    # Assert 0 is returned
    pass

@pytest.mark.asyncio
async def test_claimable_amount_pool_cap():
    # Setup: deploy contracts, active policy, oracle event, pool balance < payout
    # Call claimable_amount for user
    # Assert returned amount is capped at pool balance
    pass
