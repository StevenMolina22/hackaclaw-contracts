// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/HackathonEscrow.sol";

contract HackathonEscrowTest is Test {
    HackathonEscrow public escrow;
    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    uint256 public constant ENTRY_FEE = 0.1 ether;

    function setUp() public {
        escrow = new HackathonEscrow(ENTRY_FEE);
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    function test_join() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        assertTrue(escrow.hasJoined(alice));
        assertEq(escrow.getParticipants().length, 1);
        assertEq(address(escrow).balance, ENTRY_FEE);
    }

    function test_join_revert_wrong_fee() public {
        vm.prank(alice);
        vm.expectRevert("Wrong entry fee");
        escrow.join{value: 0.05 ether}();
    }

    function test_join_revert_already_joined() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        vm.prank(alice);
        vm.expectRevert("Already joined");
        escrow.join{value: ENTRY_FEE}();
    }

    function test_finalize() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        escrow.finalize(alice);

        assertTrue(escrow.finalized());
        assertEq(escrow.winner(), alice);
    }

    function test_finalize_revert_not_owner() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        vm.prank(alice);
        vm.expectRevert("Not owner");
        escrow.finalize(alice);
    }

    function test_finalize_revert_not_participant() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        vm.expectRevert("Winner not a participant");
        escrow.finalize(bob);
    }

    function test_claim() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();
        vm.prank(bob);
        escrow.join{value: ENTRY_FEE}();

        escrow.finalize(alice);

        uint256 balBefore = alice.balance;

        vm.prank(alice);
        escrow.claim();

        assertEq(alice.balance, balBefore + 0.2 ether);
        assertEq(address(escrow).balance, 0);
    }

    function test_claim_revert_not_winner() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        escrow.finalize(alice);

        vm.prank(bob);
        vm.expectRevert("Not winner");
        escrow.claim();
    }

    function test_claim_revert_not_finalized() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        vm.prank(alice);
        vm.expectRevert("Not finalized");
        escrow.claim();
    }

    function test_join_revert_after_finalized() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        escrow.finalize(alice);

        vm.prank(bob);
        vm.expectRevert("Hackathon finalized");
        escrow.join{value: ENTRY_FEE}();
    }
}
