# Credora Protocol Deployment Scripts

This directory contains deployment scripts for the Credora Protocol, a decentralized lending protocol built with Foundry.

## Overview

The deployment system consists of several components:

- `Deploy.sol` - Main deployment script that handles the complete protocol deployment
- `Verify.sol` - Post-deployment verification script
- `Config.sol` - Network-specific configuration library
- `run-deployment.sh` - Bash script for easy deployment execution

## Quick Start

### 1. Setup Environment

```bash
# Make the deployment script executable
chmod +x script/run-deployment.sh

# Setup deployment environment (creates .env template if needed)
./script/run-deployment.sh setup
```

### 2. Configure Environment

Edit the `.env` file in the project root with your deployment configuration:

```bash
# Private key for deployment (required)
PRIVATE_KEY=your_private_key_here

# RPC URLs (optional, will use default if not set)
MAINNET_RPC=https://mainnet.infura.io/v3/YOUR_PROJECT_ID
SEPOLIA_RPC=https://sepolia.infura.io/v3/YOUR_PROJECT_ID

# Etherscan API keys for contract verification (optional)
ETHERSCAN_API_KEY=your_etherscan_api_key

# Deployment configuration
DEPLOYMENT_NETWORK=sepolia  # Options: sepolia, mainnet, local
```

### 3. Deploy to Network

```bash
# Deploy to Sepolia testnet
./script/run-deployment.sh deploy sepolia

# Deploy to mainnet
./script/run-deployment.sh deploy mainnet

# Deploy to local network
./script/run-deployment.sh deploy local
```

### 4. Verify Deployment

```bash
# Verify contracts on Sepolia
./script/run-deployment.sh verify sepolia

# Verify contracts on mainnet
./script/run-deployment.sh verify mainnet
```

## Contract Deployment Order

The deployment script handles the following deployment order to resolve circular dependencies:

1. **CredoraShares** (CRD Token) - ERC20 token representing pool shares
2. **Pool** - Main liquidity pool for wstETH deposits
3. **Groth16Verifier** - Generated verifier contract
4. **Groth16VerifierWrapper** - Wrapper with IVerifier interface
5. **CreditNote721** - ERC721 contract for credit notes (temporary CRDVault address)
6. **CRDVault** - Vault managing CRD tokens (temporary NoteIssuer address)
7. **NoteIssuer** - Factory for creating credit notes (temporary addresses)
8. **Redeployment** - Redeploy contracts with correct addresses to resolve circular dependencies

## Network Configuration

### Sepolia Testnet
- **stETH**: `0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af`
- **wstETH**: `0xB82381A3fBD3FaFA77B3a7bE693342618240067b`
- **Symbiotic Vault**: `0x77F170Dcd0439c0057055a6D7e5A1Eb9c48cCD2a`

### Mainnet
- **stETH**: `0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84`
- **wstETH**: `0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0`
- **Symbiotic Vault**: *TODO - Set mainnet address*

### Local Development
- Uses mock addresses for testing

## Advanced Usage

### Manual Deployment with Forge

```bash
# Deploy to Sepolia with custom private key
forge script script/Deploy.sol \
  --rpc-url https://rpc.sepolia.org \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

# Deploy to local network
forge script script/Deploy.sol --broadcast

# Deploy with specific gas settings
forge script script/Deploy.sol \
  --rpc-url $SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --gas-limit 8000000 \
  --gas-price 20000000000
```

### Manual Verification

```bash
# Run verification script
forge script script/Verify.sol \
  --rpc-url $SEPOLIA_RPC \
  --broadcast
```

## Deployment Artifacts

After successful deployment, artifacts are saved in the `deployments/` directory:

```
deployments/
├── deployment_sepolia_20231201_120000.json
├── deployment_mainnet_20231201_130000.json
└── ...
```

Each artifact contains:
- Network information
- Deployment timestamp
- Deployer address
- Contract addresses
- Deployment configuration

## Troubleshooting

### Common Issues

1. **Private Key Not Set**
   ```bash
   Error: Private key not set
   Solution: Set PRIVATE_KEY in .env file
   ```

2. **RPC URL Issues**
   ```bash
   Error: Connection refused
   Solution: Check RPC URL and network connectivity
   ```

3. **Insufficient Funds**
   ```bash
   Error: Insufficient funds
   Solution: Ensure deployer account has sufficient ETH
   ```

4. **Contract Verification Fails**
   ```bash
   Error: Verification failed
   Solution: Check ETHERSCAN_API_KEY and contract code
   ```

### Gas Estimation

For complex deployments, you may need to adjust gas settings:

```bash
# Increase gas limit for deployment
forge script script/Deploy.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --gas-limit 10000000 \
  --gas-price 30000000000
```

## Security Considerations

- **Private Keys**: Never commit private keys to version control
- **Environment Variables**: Use secure methods to manage sensitive data
- **Multi-sig**: Consider using a multi-signature wallet for mainnet deployments
- **Testing**: Always test deployments on testnets before mainnet

## Support

For issues or questions:
1. Check the main project README.md
2. Review the contract interfaces in `src/interfaces/`
3. Test locally before deploying to testnets
4. Use the verification scripts to validate deployments

## Contract Addresses (Post-Deployment)

After deployment, you'll receive output similar to:

```
=== Credora Protocol Deployment Summary ===
CredoraShares (CRD Token): 0x1234...
Pool: 0x5678...
Groth16Verifier: 0x9abc...
Groth16VerifierWrapper: 0xdef0...
CreditNote721: 0x1111...
CRDVault: 0x2222...
NoteIssuer: 0x3333...
===========================================
```

Save these addresses for frontend integration and documentation.
