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
    uint256 public constant DEADLINE = 1000;

    function setUp() public {
        vm.warp(100); // start before deadline
        escrow = new HackathonEscrow(ENTRY_FEE, DEADLINE, address(this), address(this));
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    // ── Paid mode (existing behavior) ──

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

contract SponsoredEscrowTest is Test {
    HackathonEscrow public escrow;
    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    uint256 public constant BOUNTY = 2 ether;
    uint256 public constant DEADLINE = 1000;

    function setUp() public {
        vm.warp(100);
        vm.deal(owner, 10 ether);
        escrow = new HackathonEscrow{value: BOUNTY}(0, DEADLINE, address(this), address(this));
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    function test_deploy_sponsored_zero_fee() public view {
        assertEq(escrow.entryFee(), 0);
        assertEq(escrow.sponsor(), owner);
        assertEq(escrow.deadline(), DEADLINE);
        assertEq(address(escrow).balance, BOUNTY);
        assertEq(escrow.prizePool(), BOUNTY);
    }

    function test_join_zero_fee() public {
        vm.prank(alice);
        escrow.join{value: 0}();

        assertTrue(escrow.hasJoined(alice));
        assertEq(address(escrow).balance, BOUNTY);
    }

    function test_join_zero_fee_revert_with_value() public {
        vm.prank(alice);
        vm.expectRevert("Wrong entry fee");
        escrow.join{value: 0.1 ether}();
    }

    function test_claim_sponsored_prize() public {
        vm.prank(alice);
        escrow.join{value: 0}();
        vm.prank(bob);
        escrow.join{value: 0}();

        escrow.finalize(alice);

        uint256 balBefore = alice.balance;
        vm.prank(alice);
        escrow.claim();

        assertEq(alice.balance, balBefore + BOUNTY);
        assertEq(address(escrow).balance, 0);
    }

    function test_receive_additional_funding() public {
        uint256 extra = 1 ether;
        (bool ok,) = address(escrow).call{value: extra}("");
        assertTrue(ok);
        assertEq(address(escrow).balance, BOUNTY + extra);
    }

    function test_receive_revert_after_finalized() public {
        vm.prank(alice);
        escrow.join{value: 0}();
        escrow.finalize(alice);

        vm.expectRevert("Hackathon finalized");
        (bool ok,) = address(escrow).call{value: 1 ether}("");
        // expectRevert consumes the revert, ok would be true in foundry test context
    }

    // ── Abort tests ──

    function test_abort_returns_funds_to_sponsor() public {
        // sponsor == owner == address(this), but test contracts can't receive ETH
        // so we check balance drained from escrow
        vm.warp(DEADLINE + 1);

        uint256 escrowBal = address(escrow).balance;
        assertEq(escrowBal, BOUNTY);

        escrow.abort();

        assertTrue(escrow.finalized());
        assertEq(address(escrow).balance, 0);
    }

    receive() external payable {}

    function test_abort_revert_not_owner() public {
        vm.warp(DEADLINE + 1);
        vm.prank(alice);
        vm.expectRevert("Not owner");
        escrow.abort();
    }

    function test_abort_revert_before_deadline() public {
        vm.expectRevert("Hackathon not expired");
        escrow.abort();
    }

    function test_abort_revert_after_finalized() public {
        vm.prank(alice);
        escrow.join{value: 0}();
        escrow.finalize(alice);

        vm.warp(DEADLINE + 1);
        vm.expectRevert("Already finalized");
        escrow.abort();
    }
}

contract SeparatedRolesEscrowTest is Test {
    HackathonEscrow public escrow;
    address public platform = address(0x10);
    address public sponsorAddr = address(0x20);
    address public alice = address(0x1);
    uint256 public constant BOUNTY = 2 ether;
    uint256 public constant DEADLINE = 1000;

    function setUp() public {
        vm.warp(100);
        vm.deal(sponsorAddr, 10 ether);
        vm.deal(alice, 1 ether);
        // Sponsor deploys with platform as owner, themselves as sponsor
        vm.prank(sponsorAddr);
        escrow = new HackathonEscrow{value: BOUNTY}(0, DEADLINE, platform, sponsorAddr);
    }

    function test_separated_roles() public view {
        assertEq(escrow.owner(), platform);
        assertEq(escrow.sponsor(), sponsorAddr);
        assertEq(escrow.prizePool(), BOUNTY);
    }

    function test_platform_can_finalize() public {
        vm.prank(alice);
        escrow.join{value: 0}();

        vm.prank(platform);
        escrow.finalize(alice);

        assertTrue(escrow.finalized());
        assertEq(escrow.winner(), alice);
    }

    function test_sponsor_cannot_finalize() public {
        vm.prank(alice);
        escrow.join{value: 0}();

        vm.prank(sponsorAddr);
        vm.expectRevert("Not owner");
        escrow.finalize(alice);
    }

    function test_abort_refunds_sponsor_not_owner() public {
        vm.warp(DEADLINE + 1);

        uint256 sponsorBalBefore = sponsorAddr.balance;
        vm.prank(platform);
        escrow.abort();

        assertEq(sponsorAddr.balance, sponsorBalBefore + BOUNTY);
        assertEq(address(escrow).balance, 0);
    }

    function test_sponsor_cannot_abort() public {
        vm.warp(DEADLINE + 1);
        vm.prank(sponsorAddr);
        vm.expectRevert("Not owner");
        escrow.abort();
    }
}
