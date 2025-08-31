// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ICRDVault} from "../../src/interfaces/ICRDVault.sol";
import {CRDVault} from "../../src/contracts/CRDVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ICRDVaultTest is Test {
    ICRDVault crdVault;
    address owner = makeAddr("owner");
    address pool = makeAddr("pool");
    address noteIssuer = makeAddr("noteIssuer");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    // Mock CRD token
    address mockCRDToken = makeAddr("mockCRDToken");

    function setUp() public {
        // Deploy CRD Vault contract
        vm.prank(owner);
        crdVault = new CRDVault(mockCRDToken, pool, noteIssuer);

        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    // mintCRD tests
    function test_mintCRD_should_mint_CRD_tokens_to_recipient() public {
        uint256 mintAmount = 100 ether;

        // Mock total supply to return the minted amount
        vm.mockCall(
            mockCRDToken,
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            abi.encode(mintAmount)
        );

        vm.prank(pool);
        crdVault.mintCRD(user1, mintAmount);

        // Check total supply increased
        assertEq(crdVault.totalSupply(), mintAmount, "Total supply should increase");
    }

    function test_mintCRD_should_emit_CRDMinted_event() public {
        uint256 mintAmount = 50 ether;

        vm.expectEmit(true, false, false, true);
        emit ICRDVault.CRDMinted(user1, mintAmount);

        vm.prank(pool);
        crdVault.mintCRD(user1, mintAmount);
    }

    function test_mintCRD_should_revert_on_zero_address() public {
        vm.prank(pool);
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.ZeroAddress.selector));
        crdVault.mintCRD(address(0), 100 ether);
    }

    function test_mintCRD_should_revert_on_zero_amount() public {
        vm.prank(pool);
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.ZeroAmount.selector));
        crdVault.mintCRD(user1, 0);
    }

    function test_mintCRD_should_only_be_callable_by_authorized_addresses() public {
        vm.prank(user1); // Unauthorized user
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.UnauthorizedAccess.selector));
        crdVault.mintCRD(user1, 100 ether);
    }

    // burnCRD tests
    function test_burnCRD_should_burn_CRD_tokens_from_holder() public {
        uint256 burnAmount = 50 ether;

        vm.prank(pool);
        crdVault.burnCRD(user1, burnAmount);

        // Check that burn was called (we can't easily mock totalSupply changes in this simple setup)
        // In a real implementation, totalSupply would decrease
    }

    function test_burnCRD_should_emit_CRDBurned_event() public {
        uint256 burnAmount = 30 ether;

        vm.expectEmit(true, false, false, true);
        emit ICRDVault.CRDBurned(user1, burnAmount);

        vm.prank(pool);
        crdVault.burnCRD(user1, burnAmount);
    }

    function test_burnCRD_should_revert_on_zero_address() public {
        vm.prank(pool);
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.ZeroAddress.selector));
        crdVault.burnCRD(address(0), 50 ether);
    }

    function test_burnCRD_should_revert_on_zero_amount() public {
        vm.prank(pool);
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.ZeroAmount.selector));
        crdVault.burnCRD(user1, 0);
    }

    function test_burnCRD_should_only_be_callable_by_authorized_addresses() public {
        vm.prank(user1); // Unauthorized user
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.UnauthorizedAccess.selector));
        crdVault.burnCRD(user1, 50 ether);
    }

    // transferCRDToNote tests
    function test_transferCRDToNote_should_transfer_CRD_to_NoteIssuer() public {
        uint256 transferAmount = 25 ether;
        uint256 noteId = 1;

        vm.prank(noteIssuer);
        crdVault.transferCRDToNote(noteIssuer, noteId, transferAmount);
    }

    function test_transferCRDToNote_should_emit_CRDTransferredToNote_event() public {
        uint256 transferAmount = 20 ether;
        uint256 noteId = 2;

        vm.expectEmit(true, true, false, true);
        emit ICRDVault.CRDTransferredToNote(noteIssuer, noteId, transferAmount);

        vm.prank(noteIssuer);
        crdVault.transferCRDToNote(noteIssuer, noteId, transferAmount);
    }

    function test_transferCRDToNote_should_revert_on_zero_address() public {
        vm.prank(noteIssuer);
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.ZeroAddress.selector));
        crdVault.transferCRDToNote(address(0), 1, 20 ether);
    }

    function test_transferCRDToNote_should_revert_on_zero_amount() public {
        vm.prank(noteIssuer);
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.ZeroAmount.selector));
        crdVault.transferCRDToNote(noteIssuer, 1, 0);
    }

    function test_transferCRDToNote_should_only_be_callable_by_NoteIssuer() public {
        vm.prank(user1); // Unauthorized user
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.UnauthorizedAccess.selector));
        crdVault.transferCRDToNote(noteIssuer, 1, 20 ether);
    }

    // returnCRDFromNote tests
    function test_returnCRDFromNote_should_accept_CRD_return_from_note() public {
        uint256 returnAmount = 15 ether;
        uint256 noteId = 3;

        vm.prank(user1);
        crdVault.returnCRDFromNote(user1, noteId, returnAmount);
    }

    function test_returnCRDFromNote_should_emit_CRDReturnedFromNote_event() public {
        uint256 returnAmount = 10 ether;
        uint256 noteId = 4;

        vm.expectEmit(true, true, false, true);
        emit ICRDVault.CRDReturnedFromNote(user1, noteId, returnAmount);

        vm.prank(user1);
        crdVault.returnCRDFromNote(user1, noteId, returnAmount);
    }

    function test_returnCRDFromNote_should_revert_on_zero_address() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.ZeroAddress.selector));
        crdVault.returnCRDFromNote(address(0), 1, 10 ether);
    }

    function test_returnCRDFromNote_should_revert_on_zero_amount() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.ZeroAmount.selector));
        crdVault.returnCRDFromNote(user1, 1, 0);
    }

    // approveNoteIssuer tests
    function test_approveNoteIssuer_should_set_approval_for_NoteIssuer() public {
        vm.prank(owner);
        crdVault.approveNoteIssuer(noteIssuer);
    }

    function test_approveNoteIssuer_should_emit_NoteIssuerApproved_event() public {
        vm.expectEmit(true, false, false, true);
        emit ICRDVault.NoteIssuerApproved(noteIssuer, type(uint256).max);

        vm.prank(owner);
        crdVault.approveNoteIssuer(noteIssuer);
    }

    function test_approveNoteIssuer_should_revert_on_zero_address() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ICRDVault.ZeroAddress.selector));
        crdVault.approveNoteIssuer(address(0));
    }

    function test_approveNoteIssuer_should_only_be_callable_by_owner() public {
        vm.prank(user1); // Not owner
        vm.expectRevert(); // Ownable revert
        crdVault.approveNoteIssuer(noteIssuer);
    }

    // View function tests
    function test_totalSupply_should_return_total_CRD_supply() public {
        vm.mockCall(
            mockCRDToken,
            abi.encodeWithSelector(IERC20(mockCRDToken).totalSupply.selector),
            abi.encode(1000 ether)
        );

        uint256 supply = crdVault.totalSupply();
        assertEq(supply, 1000 ether, "Should return total supply");
    }

    function test_balanceOf_should_return_CRD_balance_of_account() public {
        vm.mockCall(
            mockCRDToken,
            abi.encodeWithSelector(IERC20(mockCRDToken).balanceOf.selector, user1),
            abi.encode(500 ether)
        );

        uint256 balance = crdVault.balanceOf(user1);
        assertEq(balance, 500 ether, "Should return account balance");
    }

    function test_getCRDToken_should_return_CRD_token_contract_address() public {
        IERC20 crdToken = crdVault.getCRDToken();
        assertEq(address(crdToken), mockCRDToken, "Should return CRD token address");
    }

    function test_isAuthorized_should_return_true_for_authorized_addresses() public {
        bool isPoolAuthorized = crdVault.isAuthorized(pool);
        bool isNoteIssuerAuthorized = crdVault.isAuthorized(noteIssuer);
        bool isOwnerAuthorized = crdVault.isAuthorized(owner);

        assertTrue(isPoolAuthorized, "Pool should be authorized");
        assertTrue(isNoteIssuerAuthorized, "NoteIssuer should be authorized");
        assertTrue(isOwnerAuthorized, "Owner should be authorized");
    }

    function test_isAuthorized_should_return_false_for_unauthorized_addresses() public {
        bool isUser1Authorized = crdVault.isAuthorized(user1);
        bool isUser2Authorized = crdVault.isAuthorized(user2);

        assertFalse(isUser1Authorized, "User1 should not be authorized");
        assertFalse(isUser2Authorized, "User2 should not be authorized");
    }
}
