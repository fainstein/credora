# 🚀 Credora Protocol Deployment Guide

## Prerequisites

1. **Foundry** installed: https://getfoundry.sh/
2. **Private key** for deployment
3. **Sepolia ETH** for gas fees
4. **Etherscan API key** for contract verification

## Quick Setup

### 1. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values
nano .env
```

### 2. Import Deployment Account

```bash
# Import your private key to Foundry's keystore
cast wallet import sepolia-deployer --interactive

# When prompted, enter your private key (without 0x prefix)
```

### 3. Deploy to Sepolia

```bash
# Deploy using yarn/npm
yarn deploy:sepolia

# Or directly with forge
source .env && forge script script/SimpleDeploy.s.sol \
  --rpc-url $SEPOLIA_RPC \
  --account $SEPOLIA_DEPLOYER_NAME \
  --broadcast \
  --verify \
  --chain sepolia \
  -vvvvv
```

## Environment Variables

### Required

```bash
# Your deployment account name in Foundry keystore
SEPOLIA_DEPLOYER_NAME=sepolia-deployer

# RPC endpoint
SEPOLIA_RPC=https://rpc.sepolia.org

# Etherscan API key for verification
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

### Optional

```bash
# Custom initial owner (defaults to deployer)
INITIAL_OWNER=0xYourAddressHere
```

## Deployment Scripts

### Available Scripts

- `yarn deploy:sepolia` - Deploy to Sepolia testnet
- `yarn deploy:mainnet` - Deploy to Ethereum mainnet
- `yarn deploy:local` - Deploy to local network

### Manual Deployment

```bash
# Sepolia
forge script script/SimpleDeploy.s.sol \
  --rpc-url https://rpc.sepolia.org \
  --account sepolia-deployer \
  --broadcast \
  --verify \
  --chain sepolia

# Mainnet
forge script script/SimpleDeploy.s.sol \
  --rpc-url https://mainnet.infura.io/v3/YOUR_PROJECT_ID \
  --account mainnet-deployer \
  --broadcast \
  --verify \
  --chain mainnet
```

## Contract Deployment Order

The script deploys contracts in this order to handle dependencies:

1. **CredoraShares** - CRD token contract
2. **Pool** - Main liquidity pool
3. **Groth16Verifier** - ZK proof verifier
4. **Groth16VerifierWrapper** - Verifier wrapper
5. **CreditNote721** - ERC721 credit notes
6. **CRDVault** - CRD token vault
7. **NoteIssuer** - Credit note factory

## Post-Deployment

### Contract Addresses

After deployment, addresses are saved to:
```
deployments/sepolia_[timestamp].json
```

Example output:
```json
{
  "chainId": 11155111,
  "timestamp": "1703123456",
  "deployer": "0x123...",
  "contracts": {
    "credoraShares": "0x456...",
    "pool": "0x789...",
    "noteIssuer": "0xabc..."
  }
}
```

### Verification

Contracts are automatically verified on Etherscan if:
- `ETHERSCAN_API_KEY` is set
- `--verify` flag is used

## Troubleshooting

### Common Issues

**"Account not found"**
```bash
# Check if account exists
cast wallet list

# Re-import if needed
cast wallet import sepolia-deployer --interactive
```

**"Insufficient funds"**
```bash
# Check account balance
cast balance $(cast wallet address sepolia-deployer) --rpc-url https://rpc.sepolia.org
```

**"Verification failed"**
```bash
# Check Etherscan API key
echo $ETHERSCAN_API_KEY

# Manual verification
forge verify-contract <contract_address> <contract_path> \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain sepolia
```

### Gas Optimization

For production deployment, use optimized builds:

```bash
# Build optimized contracts
yarn build:optimized

# Deploy with custom gas settings
forge script script/SimpleDeploy.s.sol \
  --rpc-url $SEPOLIA_RPC \
  --account $SEPOLIA_DEPLOYER_NAME \
  --broadcast \
  --verify \
  --chain sepolia \
  --gas-limit 8000000 \
  --gas-price 20000000000
```

## Security Notes

- ✅ Never commit private keys to version control
- ✅ Use hardware wallets for mainnet deployments
- ✅ Test deployments on testnets first
- ✅ Verify contracts on Etherscan
- ✅ Save deployment addresses securely

## Need Help?

Check the [main README](../README.md) for protocol documentation or open an issue.
