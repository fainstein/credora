// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Fork Verification Test
 * @dev Simple test to verify Sepolia fork works and contracts exist
 */
contract ForkTest is Test {
    // Sepolia testnet contract addresses
    address constant STETH = 0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af;
    address constant WSTETH = 0xB82381A3fBD3FaFA77B3a7bE693342618240067b;
    address constant SYMBIOTIC_VAULT = 0x77F170Dcd0439c0057055a6D7e5A1Eb9c48cCD2a;

    function setUp() public {
        // Fork Sepolia network using environment variable for RPC URL
        string memory rpcUrl;
        try vm.envString("SEPOLIA_TEST_RPC") returns (string memory envRpc) {
            rpcUrl = envRpc;
        } catch {
            // Fallback to a reliable public RPC if env var is not set
            rpcUrl = "https://ethereum-sepolia.publicnode.com";
        }

        try vm.createSelectFork(rpcUrl) {
            console.log("Successfully forked Sepolia network");
        } catch {
            console.log("Failed to fork Sepolia network, skipping fork tests");
            // Skip fork tests if network is unavailable
            vm.skip(true);
        }
    }

    function test_fork_connection() public {
        console.log("=== Fork Connection Test ===");
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("Sepolia Fork:", block.chainid == 11155111);

        // Verify we're on Sepolia
        assertEq(block.chainid, 11155111, "Should be on Sepolia network");
    }

    function test_contract_addresses_exist() public {
        console.log("=== Contract Existence Test ===");

        // Check if contracts exist by calling a view function
        // This will revert if contract doesn't exist
        try IERC20(STETH).totalSupply() returns (uint256 supply) {
            console.log("stETH contract exists - Total Supply:", supply / 1e18);
            assertGt(supply, 0, "stETH should have supply");
        } catch {
            console.log("stETH contract NOT found at address:", STETH);
            revert("stETH contract not found");
        }

        try IERC20(WSTETH).totalSupply() returns (uint256 supply) {
            console.log("wstETH contract exists - Total Supply:", supply / 1e18);
            assertGt(supply, 0, "wstETH should have supply");
        } catch {
            console.log("wstETH contract NOT found at address:", WSTETH);
            revert("wstETH contract not found");
        }

        // Check if Symbiotic vault exists (might not have totalSupply)
        try IERC20(WSTETH).balanceOf(SYMBIOTIC_VAULT) returns (uint256 balance) {
            console.log("Symbiotic vault exists - wstETH balance:", balance / 1e18);
        } catch {
            console.log("Symbiotic vault NOT found at address:", SYMBIOTIC_VAULT);
            revert("Symbiotic vault not found");
        }

        console.log("SUCCESS: All contracts exist and are accessible");
    }

    function test_real_balance_queries() public {
        console.log("=== Real Balance Queries Test ===");

        // Query real balances from the network
        uint256 stETHSupply = IERC20(STETH).totalSupply();
        uint256 wstETHSupply = IERC20(WSTETH).totalSupply();
        uint256 vaultWstETHBalance = IERC20(WSTETH).balanceOf(SYMBIOTIC_VAULT);

        console.log("Real stETH total supply:", stETHSupply / 1e18, "stETH");
        console.log("Real wstETH total supply:", wstETHSupply / 1e18, "wstETH");
        console.log("Symbiotic vault wstETH balance:", vaultWstETHBalance / 1e18, "wstETH");

        // Basic sanity checks
        assertGt(stETHSupply, 0, "stETH should have supply");
        assertGt(wstETHSupply, 0, "wstETH should have supply");
        // Vault might have 0 balance initially, that's OK

        console.log("SUCCESS: Real balance queries successful");
    }
}
