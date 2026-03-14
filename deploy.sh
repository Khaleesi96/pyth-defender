#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  PythDefenderScores — Deployment Script
#  Deploys to Optimism Sepolia testnet using Foundry
# ─────────────────────────────────────────────────────────────────

set -e

echo "╔════════════════════════════════════════════════════╗"
echo "║       PYTH DEFENDER SCORES — DEPLOY SCRIPT        ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# ── STEP 1: Install dependencies ────────────────────────────────
echo "📦 Installing dependencies..."
npm init -y > /dev/null 2>&1
npm install @pythnetwork/entropy-sdk-solidity > /dev/null 2>&1
echo "✓ Dependencies installed"

# ── STEP 2: Create remappings ────────────────────────────────────
echo "@pythnetwork/entropy-sdk-solidity/=node_modules/@pythnetwork/entropy-sdk-solidity/" > remappings.txt
echo "✓ Remappings configured"

# ── STEP 3: Configure network ────────────────────────────────────
# Optimism Sepolia (testnet)
export RPC_URL="https://sepolia.optimism.io"
export ENTROPY_ADDRESS="0x4821932D0CDd71225A6d914706A621e0389D7061"
export PROVIDER_ADDRESS="0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344"

echo ""
echo "🌐 Network:  Optimism Sepolia (testnet)"
echo "📍 Entropy:  $ENTROPY_ADDRESS"
echo "👤 Provider: $PROVIDER_ADDRESS"
echo ""

# ── STEP 4: Check wallet ─────────────────────────────────────────
if [ -z "$PRIVATE_KEY" ]; then
  echo "❌ ERROR: PRIVATE_KEY environment variable not set."
  echo ""
  echo "   Run: export PRIVATE_KEY=0x<your_private_key>"
  echo "   Get testnet ETH from: https://console.optimism.io/faucet"
  echo ""
  exit 1
fi

echo "🔑 Deployer: $(cast wallet address $PRIVATE_KEY)"
BALANCE=$(cast balance $(cast wallet address $PRIVATE_KEY) --rpc-url $RPC_URL -e 2>/dev/null || echo "unknown")
echo "💰 Balance:  $BALANCE ETH"
echo ""

# ── STEP 5: Deploy ───────────────────────────────────────────────
echo "🚀 Deploying PythDefenderScores..."
echo ""

forge create PythDefenderScores.sol:PythDefenderScores \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --constructor-args $ENTROPY_ADDRESS $PROVIDER_ADDRESS \
  --broadcast \
  --verify \
  --verifier blockscout \
  --verifier-url "https://optimism-sepolia.blockscout.com/api/" 2>&1 | tee deploy_output.txt

DEPLOYED_TO=$(grep "Deployed to:" deploy_output.txt | awk '{print $3}')

if [ -z "$DEPLOYED_TO" ]; then
  echo "⚠️  Could not parse deployed address. Check deploy_output.txt"
else
  echo ""
  echo "╔════════════════════════════════════════════════════╗"
  echo "║                DEPLOYMENT SUCCESS ✓               ║"
  echo "╠════════════════════════════════════════════════════╣"
  echo "║ Contract: $DEPLOYED_TO"
  echo "║ Network:  Optimism Sepolia"
  echo "║ Explorer: https://sepolia-optimism.etherscan.io/address/$DEPLOYED_TO"
  echo "╚════════════════════════════════════════════════════╝"
  echo ""
  echo "📋 Next step: copy the contract address above into"
  echo "   the integration page (game-submit.html)"
  echo ""
  echo "export CONTRACT_ADDRESS=$DEPLOYED_TO"
fi
