#!/bin/bash

# Deployment script for Stark Insured contracts
# Usage: ./scripts/deploy.sh [testnet|mainnet]

NETWORK=${1:-testnet}

echo "🚀 Deploying Stark Insured to $NETWORK..."

# Check if sncast is installed
if ! command -v sncast &> /dev/null; then
    echo "❌ sncast is not installed. Please install Starknet Foundry."
    exit 1
fi

# Build contracts first
echo "🔨 Building contracts..."
./scripts/build.sh

if [ $? -ne 0 ]; then
    echo "❌ Build failed! Cannot proceed with deployment."
    exit 1
fi

# Set network configuration
if [ "$NETWORK" = "mainnet" ]; then
    RPC_URL="https://starknet-mainnet.public.blastapi.io"
    ACCOUNT="mainnet_deployer"
else
    RPC_URL="https://starknet-goerli.public.blastapi.io"
    ACCOUNT="testnet_deployer"
fi

echo "🌐 Using network: $NETWORK"
echo "🔗 RPC URL: $RPC_URL"

# Deploy contracts in order
echo "📋 Deploying PolicyManager..."
POLICY_MANAGER=$(sncast deploy \
    --class-hash $(cat target/dev/stark_insured_PolicyManager.sierra.json | jq -r '.class_hash') \
    --constructor-calldata 0x123 0x456 \
    --url $RPC_URL \
    --account $ACCOUNT \
    --wait)

echo "📋 Deploying RiskPool..."
RISK_POOL=$(sncast deploy \
    --class-hash $(cat target/dev/stark_insured_RiskPool.sierra.json | jq -r '.class_hash') \
    --constructor-calldata 0x123 0x456 \
    --url $RPC_URL \
    --account $ACCOUNT \
    --wait)

echo "📋 Deploying ClaimsProcessor..."
CLAIMS_PROCESSOR=$(sncast deploy \
    --class-hash $(cat target/dev/stark_insured_ClaimsProcessor.sierra.json | jq -r '.class_hash') \
    --constructor-calldata 0x123 $POLICY_MANAGER $RISK_POOL \
    --url $RPC_URL \
    --account $ACCOUNT \
    --wait)

echo "📋 Deploying DAOGovernance..."
DAO_GOVERNANCE=$(sncast deploy \
    --class-hash $(cat target/dev/stark_insured_DAOGovernance.sierra.json | jq -r '.class_hash') \
    --constructor-calldata 0x123 0x789 \
    --url $RPC_URL \
    --account $ACCOUNT \
    --wait)

# Save deployment addresses
DEPLOYMENT_FILE="deployments/${NETWORK}_addresses.json"
mkdir -p deployments

cat > $DEPLOYMENT_FILE << EOF
{
  "network": "$NETWORK",
  "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contracts": {
    "PolicyManager": "$POLICY_MANAGER",
    "RiskPool": "$RISK_POOL", 
    "ClaimsProcessor": "$CLAIMS_PROCESSOR",
    "DAOGovernance": "$DAO_GOVERNANCE"
  }
}
EOF

echo "✅ Deployment completed!"
echo "📄 Addresses saved to: $DEPLOYMENT_FILE"
echo "🎉 Stark Insured is now live on $NETWORK!"
