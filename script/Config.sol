// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Credora Protocol Deployment Configuration
 * @notice Configuration constants and network-specific addresses for deployment
 */
library Config {
    // Network-specific contract addresses
    struct NetworkConfig {
        address stETH;
        address wstETH;
        address symbioticVault;
        address deployer;
        address initialOwner;
        uint256 maxLoanAmount;
    }

    // Sepolia testnet configuration
    function getSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            stETH: 0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af,
            wstETH: 0xB82381A3fBD3FaFA77B3a7bE693342618240067b,
            symbioticVault: 0x77F170Dcd0439c0057055a6D7e5A1Eb9c48cCD2a,
            deployer: address(0), // Set by deployer
            initialOwner: address(0), // Set by deployer
            maxLoanAmount: 5 ether
        });
    }

    // Mainnet configuration
    function getMainnetConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            stETH: 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84,
            wstETH: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
            symbioticVault: address(0), // TODO: Set mainnet symbiotic vault address
            deployer: address(0), // Set by deployer
            initialOwner: address(0), // Set by deployer
            maxLoanAmount: 5 ether
        });
    }

    // Local development configuration
    function getLocalConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            stETH: address(0), // Mock addresses for local development
            wstETH: address(0),
            symbioticVault: address(0),
            deployer: address(0), // Set by deployer
            initialOwner: address(0), // Set by deployer
            maxLoanAmount: 5 ether
        });
    }

    /**
     * @notice Get network configuration based on chain ID
     * @param chainId The chain ID of the network
     * @return config The network configuration
     */
    function getNetworkConfig(uint256 chainId) internal view returns (NetworkConfig memory config) {
        if (chainId == 11155111) { // Sepolia
            config = getSepoliaConfig();
        } else if (chainId == 1) { // Mainnet
            config = getMainnetConfig();
        } else { // Local development or testnets
            config = getLocalConfig();
        }

        // Set deployer and initial owner to msg.sender if not set
        if (config.deployer == address(0)) {
            config.deployer = msg.sender;
        }
        if (config.initialOwner == address(0)) {
            config.initialOwner = msg.sender;
        }
    }

    /**
     * @notice Get current chain ID
     */
    function getChainId() internal view returns (uint256) {
        return block.chainid;
    }

    /**
     * @notice Protocol constants
     */
    uint256 public constant ADVANCE_RATIO = 2000; // 20% advance payment required (basis points)
    uint256 public constant INTEREST_RATE = 500; // 5% fixed interest rate (basis points)
    uint256 public constant MATURITY_PERIOD = 365 days; // 1 year maturity
}
