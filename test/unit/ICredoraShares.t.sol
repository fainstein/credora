// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CredoraShares} from "../../src/contracts/CredoraShares.sol";
import {IPool} from "../../src/interfaces/IPool.sol";

contract ICredoraSharesTest is Test {
    CredoraShares credoraShares;
    address pool = makeAddr("pool");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    // Mock Pool contract
    address mockPool = makeAddr("mockPool");

    function setUp() public {
        // Deploy CredoraShares contract
        credoraShares = new CredoraShares(mockPool);

        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    // mint tests
    function test_mint_should_mint_CRD_shares_to_recipient() public {
        uint256 mintAmount = 100 ether;

        // Mock wstETH balance
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(IPool.getWstETHBalance.selector),
            abi.encode(mintAmount)
        );

        vm.prank(mockPool);
        credoraShares.mint(user1, mintAmount);

        assertEq(credoraShares.balanceOf(user1), mintAmount, "Should mint shares to recipient");
    }

    function test_mint_should_emit_SharesMinted_event() public {
        uint256 mintAmount = 50 ether;

        vm.expectEmit(true, false, false, true);
        emit CredoraShares.SharesMinted(user1, mintAmount, 0, 1e18); // Initial price 1:1

        vm.prank(mockPool);
        credoraShares.mint(user1, mintAmount);
    }

    function test_mint_should_revert_on_zero_address() public {
        vm.prank(mockPool);
        vm.expectRevert(abi.encodeWithSelector(CredoraShares.ZeroAddress.selector));
        credoraShares.mint(address(0), 100 ether);
    }

    function test_mint_should_revert_on_zero_amount() public {
        vm.prank(mockPool);
        vm.expectRevert(abi.encodeWithSelector(CredoraShares.ZeroAmount.selector));
        credoraShares.mint(user1, 0);
    }

    function test_mint_should_only_be_callable_by_Pool() public {
        vm.prank(user1); // Not pool
        vm.expectRevert(abi.encodeWithSelector(CredoraShares.UnauthorizedAccess.selector));
        credoraShares.mint(user1, 100 ether);
    }

    // sharePrice tests
    function test_sharePrice_should_calculate_current_share_price() public {
        // Initially should be 1:1 (no supply yet)
        uint256 price = credoraShares.sharePrice();
        assertEq(price, 1e18, "Initial price should be 1:1");

        // Mint some shares
        vm.prank(mockPool);
        credoraShares.mint(user1, 100 ether);

        // Mock wstETH balance
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(IPool.getWstETHBalance.selector),
            abi.encode(100 ether)
        );

        // Price should still be 1:1
        price = credoraShares.sharePrice();
        assertEq(price, 1e18, "Price should be 1:1 with equal wstETH and CRD");
    }

    // calculatePrice tests
    function test_calculatePrice_should_calculate_price_from_wstETH_and_CRD() public {
        uint256 wstETHBalance = 200 ether;
        uint256 crdSupply = 100 ether;

        uint256 price = credoraShares.calculatePrice(wstETHBalance, crdSupply);
        assertEq(price, 2e18, "Price should be 2 wstETH per CRD");
    }

    function test_calculatePrice_should_return_1e18_for_initial_1_to_1_ratio() public {
        uint256 wstETHBalance = 100 ether;
        uint256 crdSupply = 100 ether;

        uint256 price = credoraShares.calculatePrice(wstETHBalance, crdSupply);
        assertEq(price, 1e18, "Price should be 1 wstETH per CRD");
    }

    function test_calculatePrice_should_handle_zero_supply() public {
        uint256 wstETHBalance = 100 ether;
        uint256 crdSupply = 0;

        uint256 price = credoraShares.calculatePrice(wstETHBalance, crdSupply);
        assertEq(price, 1e18, "Should return 1e18 for zero supply");
    }

    function test_calculatePrice_should_handle_zero_balance() public {
        uint256 wstETHBalance = 0;
        uint256 crdSupply = 100 ether;

        uint256 price = credoraShares.calculatePrice(wstETHBalance, crdSupply);
        assertEq(price, 1e18, "Should return 1e18 for zero balance");
    }

    // calculateSharesForDeposit tests
    function test_calculateSharesForDeposit_should_calculate_correct_shares() public {
        uint256 wstETHAmount = 50 ether;

        // Mint some initial shares
        vm.prank(mockPool);
        credoraShares.mint(user1, 100 ether);

        // Mock wstETH balance
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(IPool.getWstETHBalance.selector),
            abi.encode(100 ether)
        );

        uint256 shares = credoraShares.calculateSharesForDeposit(wstETHAmount);
        assertEq(shares, 50 ether, "Should calculate 50 shares for 50 wstETH at 1:1 price");
    }

    function test_calculateSharesForDeposit_should_revert_on_zero_amount() public {
        vm.expectRevert(abi.encodeWithSelector(CredoraShares.ZeroAmount.selector));
        credoraShares.calculateSharesForDeposit(0);
    }

    // totalSupply tests
    function test_totalSupply_should_return_total_CRD_supply() public {
        // Mock wstETH balance to avoid issues with price calculation
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(IPool.getWstETHBalance.selector),
            abi.encode(150 ether)
        );

        vm.prank(mockPool);
        credoraShares.mint(user1, 100 ether);

        vm.prank(mockPool);
        credoraShares.mint(user2, 50 ether);

        uint256 totalSupply = credoraShares.totalSupply();
        assertEq(totalSupply, 150 ether, "Total supply should be sum of all mints");
    }

    // balanceOf tests
    function test_balanceOf_should_return_CRD_balance_for_account() public {
        vm.prank(mockPool);
        credoraShares.mint(user1, 75 ether);

        uint256 balance = credoraShares.balanceOf(user1);
        assertEq(balance, 75 ether, "Should return correct balance");
    }

    function test_balanceOf_should_return_zero_for_accounts_with_no_balance() public {
        uint256 balance = credoraShares.balanceOf(user2);
        assertEq(balance, 0, "Should return zero for accounts with no balance");
    }

    // getPool tests
    function test_getPool_should_return_pool_contract_address() public {
        address poolAddress = credoraShares.getPool();
        assertEq(poolAddress, mockPool, "Should return pool address");
    }
}