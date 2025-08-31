#!/bin/bash

# Credora Protocol Deployment Script Runner
# This script provides an easy way to deploy the Credora protocol to different networks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check if required tools are installed
check_dependencies() {
    print_info "Checking dependencies..."

    if ! command -v forge &> /dev/null; then
        print_error "Foundry (forge) is not installed. Please install Foundry first."
        print_info "Visit: https://getfoundry.sh/"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Some features may not work properly."
    fi

    print_success "Dependencies check passed"
}

# Function to setup environment
setup_environment() {
    print_info "Setting up environment..."

    # Create deployments directory if it doesn't exist
    mkdir -p deployments

    # Check if .env file exists
    if [ ! -f .env ]; then
        print_warning ".env file not found. Creating template..."
        cat > .env << EOF
# Credora Protocol Deployment Environment Variables

# Private key for deployment (required)
# PRIVATE_KEY=your_private_key_here

# RPC URLs (optional, will use default if not set)
# MAINNET_RPC=https://mainnet.infura.io/v3/YOUR_PROJECT_ID
# SEPOLIA_RPC=https://sepolia.infura.io/v3/YOUR_PROJECT_ID

# Etherscan API keys for contract verification (optional)
# ETHERSCAN_API_KEY=your_etherscan_api_key

# Deployment configuration
# DEPLOYMENT_NETWORK=sepolia  # Options: sepolia, mainnet, local
EOF
        print_info "Please fill in the .env file with your configuration before running deployment."
        exit 1
    fi

    print_success "Environment setup complete"
}

# Function to load environment variables
load_env() {
    if [ -f .env ]; then
        set -a
        source .env
        set +a
        print_success "Environment variables loaded"
    else
        print_error ".env file not found"
        exit 1
    fi
}

# Function to deploy contracts
deploy_contracts() {
    local network=${1:-"sepolia"}
    print_info "Deploying Credora Protocol to $network..."

    # Set deployment arguments based on network
    local deploy_args=""
    case $network in
        "sepolia")
            deploy_args="--rpc-url ${SEPOLIA_RPC:-https://rpc.sepolia.org}"
            ;;
        "mainnet")
            deploy_args="--rpc-url ${MAINNET_RPC:-https://cloudflare-eth.com}"
            ;;
        "local")
            deploy_args=""
            ;;
        *)
            print_error "Unsupported network: $network"
            print_info "Supported networks: sepolia, mainnet, local"
            exit 1
            ;;
    esac

    # Add private key if available
    if [ ! -z "$PRIVATE_KEY" ]; then
        deploy_args="$deploy_args --private-key $PRIVATE_KEY"
    else
        print_warning "PRIVATE_KEY not set. Using default account..."
    fi

    # Add verification if API key is available and not local
    if [ "$network" != "local" ] && [ ! -z "$ETHERSCAN_API_KEY" ]; then
        deploy_args="$deploy_args --verify"
    fi

    print_info "Running deployment with args: $deploy_args"

    # Run the deployment script
    if forge script script/Deploy.sol $deploy_args --broadcast; then
        print_success "Deployment completed successfully"

        # Save deployment artifacts
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local artifact_file="deployments/deployment_$network_$timestamp.json"

        # Create deployment summary (this would be more sophisticated in production)
        cat > $artifact_file << EOF
{
    "network": "$network",
    "timestamp": "$timestamp",
    "deployer": "$(forge config --json | jq -r '.profile.default.libs[0]')",
    "contracts": {
        "credoraShares": "DEPLOYMENT_OUTPUT_PLACEHOLDER",
        "pool": "DEPLOYMENT_OUTPUT_PLACEHOLDER",
        "groth16Verifier": "DEPLOYMENT_OUTPUT_PLACEHOLDER",
        "verifierWrapper": "DEPLOYMENT_OUTPUT_PLACEHOLDER",
        "creditNote721": "DEPLOYMENT_OUTPUT_PLACEHOLDER",
        "crdVault": "DEPLOYMENT_OUTPUT_PLACEHOLDER",
        "noteIssuer": "DEPLOYMENT_OUTPUT_PLACEHOLDER"
    }
}
EOF

        print_info "Deployment artifacts saved to: $artifact_file"
    else
        print_error "Deployment failed"
        exit 1
    fi
}

# Function to verify deployment
verify_deployment() {
    local network=${1:-"sepolia"}
    print_info "Verifying deployment on $network..."

    # This would run the verification script
    # For now, just show a placeholder
    print_info "Verification would run here..."
    print_success "Verification completed (placeholder)"
}

# Function to show help
show_help() {
    echo "Credora Protocol Deployment Script"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  deploy [network]    Deploy contracts to specified network (default: sepolia)"
    echo "  verify [network]    Verify deployed contracts on specified network"
    echo "  setup               Setup deployment environment"
    echo "  help                Show this help message"
    echo ""
    echo "Networks:"
    echo "  sepolia             Sepolia testnet"
    echo "  mainnet             Ethereum mainnet"
    echo "  local               Local development network"
    echo ""
    echo "Examples:"
    echo "  $0 deploy sepolia   # Deploy to Sepolia testnet"
    echo "  $0 verify mainnet   # Verify contracts on mainnet"
    echo "  $0 setup            # Setup deployment environment"
    echo ""
}

# Main script logic
main() {
    local command=${1:-"help"}
    local network=${2:-"sepolia"}

    case $command in
        "deploy")
            check_dependencies
            setup_environment
            load_env
            deploy_contracts $network
            ;;
        "verify")
            check_dependencies
            load_env
            verify_deployment $network
            ;;
        "setup")
            check_dependencies
            setup_environment
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@"
