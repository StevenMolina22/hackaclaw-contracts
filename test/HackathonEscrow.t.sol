// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/HackathonEscrow.sol";

contract HackathonEscrowTest is Test {
    HackathonEscrow public escrow;
    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    uint256 public constant ENTRY_FEE = 0.1 ether;
    uint256 public constant DEADLINE = 1000;

    function setUp() public {
        vm.warp(100); // start before deadline
        escrow = new HackathonEscrow(ENTRY_FEE, DEADLINE, address(this), address(this));
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        vm.deal(charlie, 1 ether);
    }

    function _toAddresses(address a) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = a;
        return arr;
    }

    function _toUints(uint256 v) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](1);
        arr[0] = v;
        return arr;
    }

    // ── Join tests (unchanged) ──

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

    // ── Single winner (array form) ──

    function test_finalize_single_winner() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        escrow.finalize(_toAddresses(alice), _toUints(10000));

        assertTrue(escrow.finalized());
        assertEq(escrow.winnerCount(), 1);
        assertEq(escrow.getWinners()[0], alice);
        assertEq(escrow.getWinnerShare(alice), 10000);
    }

    function test_claim_single_winner() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();
        vm.prank(bob);
        escrow.join{value: ENTRY_FEE}();

        escrow.finalize(_toAddresses(alice), _toUints(10000));

        uint256 balBefore = alice.balance;

        vm.prank(alice);
        escrow.claim();

        assertEq(alice.balance, balBefore + 0.2 ether);
        assertEq(address(escrow).balance, 0);
    }

    // ── Multi-winner tests ──

    function test_finalize_multi_winner() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();
        vm.prank(bob);
        escrow.join{value: ENTRY_FEE}();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 6000;
        shares[1] = 4000;

        escrow.finalize(winners, shares);

        assertTrue(escrow.finalized());
        assertEq(escrow.winnerCount(), 2);
        assertEq(escrow.getWinnerShare(alice), 6000);
        assertEq(escrow.getWinnerShare(bob), 4000);
        assertEq(escrow.totalPrizeAtFinalize(), 0.2 ether);
    }

    function test_claim_multi_winner() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();
        vm.prank(bob);
        escrow.join{value: ENTRY_FEE}();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 6000;
        shares[1] = 4000;

        escrow.finalize(winners, shares);

        uint256 aliceBefore = alice.balance;
        uint256 bobBefore = bob.balance;

        vm.prank(alice);
        escrow.claim();
        assertEq(alice.balance, aliceBefore + 0.12 ether); // 60% of 0.2

        vm.prank(bob);
        escrow.claim();
        assertEq(bob.balance, bobBefore + 0.08 ether); // 40% of 0.2
    }

    function test_claim_independent_order() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();
        vm.prank(bob);
        escrow.join{value: ENTRY_FEE}();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 7000;
        shares[1] = 3000;

        escrow.finalize(winners, shares);

        // Bob claims first
        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        escrow.claim();
        assertEq(bob.balance, bobBefore + 0.06 ether); // 30% of 0.2

        // Alice claims second
        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        escrow.claim();
        assertEq(alice.balance, aliceBefore + 0.14 ether); // 70% of 0.2
    }

    function test_claim_revert_already_claimed() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        escrow.finalize(_toAddresses(alice), _toUints(10000));

        vm.prank(alice);
        escrow.claim();

        vm.prank(alice);
        vm.expectRevert("Already claimed");
        escrow.claim();
    }

    function test_claim_revert_not_winner() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();
        vm.prank(bob);
        escrow.join{value: ENTRY_FEE}();

        escrow.finalize(_toAddresses(alice), _toUints(10000));

        vm.prank(bob);
        vm.expectRevert("Not a winner");
        escrow.claim();
    }

    function test_claim_revert_not_finalized() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        vm.prank(alice);
        vm.expectRevert("Not finalized");
        escrow.claim();
    }

    // ── Finalize revert tests ──

    function test_finalize_revert_not_owner() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        vm.prank(alice);
        vm.expectRevert("Not owner");
        escrow.finalize(_toAddresses(alice), _toUints(10000));
    }

    function test_finalize_non_participant_winner() public {
        // Bob never called join(), but owner can still finalize with bob as winner
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        escrow.finalize(_toAddresses(bob), _toUints(10000));

        assertTrue(escrow.finalized());
        assertEq(escrow.getWinners()[0], bob);
        assertEq(escrow.getWinnerShare(bob), 10000);

        // Bob can claim even though they never joined
        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        escrow.claim();
        assertEq(bob.balance, bobBefore + ENTRY_FEE);
    }

    function test_finalize_revert_shares_not_10000() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();
        vm.prank(bob);
        escrow.join{value: ENTRY_FEE}();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 5000;
        shares[1] = 4000; // only 9000

        vm.expectRevert("Shares must sum to 10000");
        escrow.finalize(winners, shares);
    }

    function test_finalize_revert_duplicate_winner() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = alice;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 5000;
        shares[1] = 5000;

        vm.expectRevert("Duplicate winner");
        escrow.finalize(winners, shares);
    }

    function test_finalize_revert_zero_share() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();
        vm.prank(bob);
        escrow.join{value: ENTRY_FEE}();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 10000;
        shares[1] = 0;

        vm.expectRevert("Zero share");
        escrow.finalize(winners, shares);
    }

    function test_finalize_revert_too_many_winners() public {
        address[] memory winners = new address[](21);
        uint256[] memory shares = new uint256[](21);
        uint256 shareEach = uint256(10000) / 21;

        for (uint256 i = 0; i < 21; i++) {
            address addr = address(uint160(100 + i));
            vm.deal(addr, 1 ether);
            vm.prank(addr);
            escrow.join{value: ENTRY_FEE}();
            winners[i] = addr;
            shares[i] = shareEach;
        }
        // Adjust last share so they sum to 10000
        shares[20] = 10000 - (shareEach * 20);

        vm.expectRevert("Too many winners");
        escrow.finalize(winners, shares);
    }

    function test_finalize_revert_length_mismatch() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        uint256[] memory shares = new uint256[](2);
        shares[0] = 5000;
        shares[1] = 5000;

        vm.expectRevert("Length mismatch");
        escrow.finalize(_toAddresses(alice), shares);
    }

    function test_finalize_revert_empty_arrays() public {
        address[] memory winners = new address[](0);
        uint256[] memory shares = new uint256[](0);

        vm.expectRevert("No winners");
        escrow.finalize(winners, shares);
    }

    function test_join_revert_after_finalized() public {
        vm.prank(alice);
        escrow.join{value: ENTRY_FEE}();

        escrow.finalize(_toAddresses(alice), _toUints(10000));

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

    function _toAddresses(address a) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = a;
        return arr;
    }

    function _toUints(uint256 v) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](1);
        arr[0] = v;
        return arr;
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

    function test_claim_sponsored_single_winner() public {
        vm.prank(alice);
        escrow.join{value: 0}();
        vm.prank(bob);
        escrow.join{value: 0}();

        escrow.finalize(_toAddresses(alice), _toUints(10000));

        uint256 balBefore = alice.balance;
        vm.prank(alice);
        escrow.claim();

        assertEq(alice.balance, balBefore + BOUNTY);
        assertEq(address(escrow).balance, 0);
    }

    function test_claim_sponsored_multi_winner() public {
        vm.prank(alice);
        escrow.join{value: 0}();
        vm.prank(bob);
        escrow.join{value: 0}();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 5000;
        shares[1] = 5000;

        escrow.finalize(winners, shares);

        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        escrow.claim();
        assertEq(alice.balance, aliceBefore + 1 ether); // 50% of 2 ETH

        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        escrow.claim();
        assertEq(bob.balance, bobBefore + 1 ether); // 50% of 2 ETH
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
        escrow.finalize(_toAddresses(alice), _toUints(10000));

        vm.expectRevert("Hackathon finalized");
        (bool ok,) = address(escrow).call{value: 1 ether}("");
        // expectRevert consumes the revert, ok would be true in foundry test context
    }

    // ── Abort tests ──

    function test_abort_returns_funds_to_sponsor() public {
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
        escrow.finalize(_toAddresses(alice), _toUints(10000));

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
    address public bob = address(0x2);
    uint256 public constant BOUNTY = 2 ether;
    uint256 public constant DEADLINE = 1000;

    function setUp() public {
        vm.warp(100);
        vm.deal(sponsorAddr, 10 ether);
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        // Sponsor deploys with platform as owner, themselves as sponsor
        vm.prank(sponsorAddr);
        escrow = new HackathonEscrow{value: BOUNTY}(0, DEADLINE, platform, sponsorAddr);
    }

    function _toAddresses(address a) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = a;
        return arr;
    }

    function _toUints(uint256 v) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](1);
        arr[0] = v;
        return arr;
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
        escrow.finalize(_toAddresses(alice), _toUints(10000));

        assertTrue(escrow.finalized());
        assertEq(escrow.winnerCount(), 1);
        assertEq(escrow.getWinners()[0], alice);
    }

    function test_platform_finalize_multi_winner() public {
        vm.prank(alice);
        escrow.join{value: 0}();
        vm.prank(bob);
        escrow.join{value: 0}();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 8000;
        shares[1] = 2000;

        vm.prank(platform);
        escrow.finalize(winners, shares);

        assertTrue(escrow.finalized());
        assertEq(escrow.getWinnerShare(alice), 8000);
        assertEq(escrow.getWinnerShare(bob), 2000);

        // Alice claims 80% of 2 ETH = 1.6 ETH
        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        escrow.claim();
        assertEq(alice.balance, aliceBefore + 1.6 ether);

        // Bob claims 20% of 2 ETH = 0.4 ETH
        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        escrow.claim();
        assertEq(bob.balance, bobBefore + 0.4 ether);
    }

    function test_sponsor_cannot_finalize() public {
        vm.prank(alice);
        escrow.join{value: 0}();

        vm.prank(sponsorAddr);
        vm.expectRevert("Not owner");
        escrow.finalize(_toAddresses(alice), _toUints(10000));
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
