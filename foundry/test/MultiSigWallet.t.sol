// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public multiSigWallet;
    address[] public owners;
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public user4 = address(4);

    function setUp() public {
        // Initialisation avec des adresses explicites
        vm.startPrank(user1, user1);
        owners.push(user1);
        owners.push(user2);
        owners.push(user3);
        multiSigWallet = new MultiSigWallet(owners, 2); // Require 2 confirmations
        vm.deal(user1, 10 ether);
        vm.deal(address(multiSigWallet), 10 ether);
    }

    function testSubmitTransaction() public {
        multiSigWallet.submitTransaction(user4, 1 ether, "0x");
        // getTransactionCount() returns 1
        (address to, , , , ) = multiSigWallet.getTransactionByIndex(0);
        assertEq(to, user4);
    }

    function testOneConfirmation() public {
        multiSigWallet.submitTransaction(user4, 1 ether, "0x");
        multiSigWallet.confirmTransaction(0);
        // getTransactionCount() returns 1
        (, , , , uint confirmations) = multiSigWallet.getTransactionByIndex(0);
        assertEq(confirmations, 1);
    }

    function testTwoConfirmations() public {
        multiSigWallet.submitTransaction(user4, 1 ether, "0x");
        multiSigWallet.confirmTransaction(0);
        vm.startPrank(user2, user2);
        multiSigWallet.confirmTransaction(0);
        // getTransactionCount() returns 1
        // confirmation and executed
        (, , , bool executed, uint confirmation) = multiSigWallet
            .getTransactionByIndex(0);
        assertEq(confirmation, 2);
        assertTrue(executed);
    }

    function testRevokeConfirmation() public {
        multiSigWallet.submitTransaction(user4, 1 ether, "0x");
        multiSigWallet.confirmTransaction(0);
        multiSigWallet.revokeConfirmation(0);
        // getTransactionCount() returns 1
        (, , , , uint confirmations) = multiSigWallet.getTransactionByIndex(0);
        assertEq(confirmations, 0);
    }

    // New tests start here

    function testExecuteTransaction() public {
        // Submit a transaction

        multiSigWallet.submitTransaction(user4, 1 ether, "0x");

        // First confirmation by user1
        multiSigWallet.confirmTransaction(0);

        // Second confirmation by user2
        vm.startPrank(user2);
        multiSigWallet.confirmTransaction(0);

        // Check if the transaction was executed
        (, , , bool executed, ) = multiSigWallet.getTransactionByIndex(0);
        assertTrue(executed, "Transaction should be executed");

        // Check recipient balance
        assertEq(user4.balance, 1 ether, "Recipient should receive 1 ether");
    }

    function testInvalidConfirmation() public {
        multiSigWallet.submitTransaction(user4, 1 ether, "0x");
        vm.startPrank(user4); // user4 is not an owner
        vm.expectRevert("Not owner");
        multiSigWallet.confirmTransaction(0);
    }

    function testOutOfBoundsTransaction() public {
        vm.expectRevert("Transaction index out of bounds");
        multiSigWallet.getTransactionByIndex(999); // Non-existent transaction
    }

    // Test submitOwnerChange for adding an owner
    function testSubmitOwnerChange_Add() public {
        multiSigWallet.submitOwnerChange(user4, true); // Propose adding user4 as an owner

        (
            address proposedOwner,
            bool isAdd,
            bool executed,
            uint confirmations
        ) = multiSigWallet.ownerChanges(0);

        assertEq(proposedOwner, user4, "Owner should match proposed owner");
        assertTrue(isAdd, "Should be a proposal to add an owner");
        assertFalse(executed, "Owner change should not be executed");
        assertEq(
            confirmations,
            0,
            "Owner change should have 0 confirmations initially"
        );
    }

    // Test submitOwnerChange for removing an owner
    function testSubmitOwnerChange_Remove() public {
        multiSigWallet.submitOwnerChange(user2, false); // Propose removing user2 as an owner

        (
            address proposedOwner,
            bool isAdd,
            bool executed,
            uint confirmations
        ) = multiSigWallet.ownerChanges(0);

        assertEq(
            proposedOwner,
            user2,
            "Owner should match proposed owner for removal"
        );
        assertFalse(isAdd, "Should be a proposal to remove an owner");
        assertFalse(executed, "Owner change should not be executed");
        assertEq(
            confirmations,
            0,
            "Owner change should have 0 confirmations initially"
        );
    }

    // Test confirmOwnerChange
    function testConfirmOwnerChange() public {
        multiSigWallet.submitOwnerChange(user4, true); // Propose adding user4 as an owner
        multiSigWallet.confirmOwnerChange(0); // Confirm the owner change

        (, , , uint confirmations) = multiSigWallet.ownerChanges(0);
        assertEq(confirmations, 1, "Owner change should have 1 confirmation");
    }

    // Test executeOwnerChange for adding an owner

    // Test confirmOwnerChange for already executed change
    function testConfirmOwnerChange_Executed() public {
        multiSigWallet.submitOwnerChange(user4, true); // Propose adding user4
        multiSigWallet.confirmOwnerChange(0);

        vm.startPrank(user2);
        multiSigWallet.confirmOwnerChange(0); // Confirm again to trigger execution

        vm.expectRevert("Owner change already executed");
        multiSigWallet.confirmOwnerChange(0); // Try to confirm after execution
    }

    // Test invalid owner change confirmation
    function testInvalidOwnerChangeConfirmation() public {
        multiSigWallet.submitOwnerChange(user4, true); // Propose adding user4

        vm.startPrank(user4); // Non-owner trying to confirm
        vm.expectRevert("Not owner");
        multiSigWallet.confirmOwnerChange(0);
    }

    // Test invalid owner change index
    function testInvalidOwnerChangeIndex() public {
        multiSigWallet.submitOwnerChange(user4, true); // Propose adding user4

        vm.expectRevert("Owner change does not exist");
        multiSigWallet.confirmOwnerChange(999); // Confirming a non-existent owner change
    }

    function testSubmitTransactionZeroValue() public {
        multiSigWallet.submitTransaction(user4, 0, "0x");
        (address to, uint value, , , ) = multiSigWallet.getTransactionByIndex(
            0
        );
        assertEq(to, user4, "Recipient should be user4");
        assertEq(value, 0, "Value should be zero");
    }
    // function testTransactionAlreadyExecuted() public {
    //     multiSigWallet.submitTransaction(user4, 1 ether, "0x");
    //     multiSigWallet.confirmTransaction(0);
    //     vm.startPrank(user2);
    //     multiSigWallet.confirmTransaction(0); // Triggers execution

    //     vm.expectRevert("Transaction already executed");
    //     multiSigWallet.executeTransaction(0);
    // }
    // function testAddDuplicateOwner() public {
    //     vm.expectRevert("Already an owner");
    //     multiSigWallet.submitOwnerChange(user1, true); // user1 is already an owner
    // }
    // function testRemoveNonOwner() public {
    //     vm.expectRevert("Not an owner");
    //     multiSigWallet.submitOwnerChange(user4, false); // user4 is not an owner
    // }
    function testConfirmationByNonOwner() public {
        multiSigWallet.submitTransaction(user4, 1 ether, "0x");

        vm.startPrank(user4); // user4 is not an owner
        vm.expectRevert("Not owner");
        multiSigWallet.confirmTransaction(0);
    }
    function testRevokeTwice() public {
        multiSigWallet.submitTransaction(user4, 1 ether, "0x");
        multiSigWallet.confirmTransaction(0);

        multiSigWallet.revokeConfirmation(0);

        vm.expectRevert("Transaction not confirmed");
        multiSigWallet.revokeConfirmation(0); // Attempt to revoke again
    }
    function testMinimumOwners() public {
        multiSigWallet.submitOwnerChange(user2, false); // Propose removing user2

        multiSigWallet.confirmOwnerChange(0);
        vm.startPrank(user3);
        multiSigWallet.confirmOwnerChange(0); // Attempt to confirm removal
    }
}
