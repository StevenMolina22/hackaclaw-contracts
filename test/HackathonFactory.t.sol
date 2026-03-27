// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/HackathonFactory.sol";
import "../src/HackathonEscrow.sol";

contract HackathonFactoryTest is Test {
    HackathonFactory public factory;
    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    uint256 public constant DEADLINE = 1000;

    function setUp() public {
        vm.warp(100);
        vm.deal(owner, 10 ether);
        factory = new HackathonFactory();
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    function test_create_hackathon() public {
        address escrowAddr = factory.createHackathon(0, DEADLINE);

        assertEq(factory.hackathonCount(), 1);
        assertEq(factory.hackathons(0), escrowAddr);

        HackathonEscrow escrow = HackathonEscrow(payable(escrowAddr));
        assertEq(escrow.owner(), owner);
        assertEq(escrow.sponsor(), owner);
        assertEq(escrow.entryFee(), 0);
        assertEq(escrow.deadline(), DEADLINE);
    }

    function test_create_hackathon_with_funding() public {
        address escrowAddr = factory.createHackathon{value: 2 ether}(0, DEADLINE);

        assertEq(escrowAddr.balance, 2 ether);
        HackathonEscrow escrow = HackathonEscrow(payable(escrowAddr));
        assertEq(escrow.prizePool(), 2 ether);
    }

    function test_create_revert_not_owner() public {
        vm.prank(alice);
        vm.expectRevert("Not owner");
        factory.createHackathon(0, DEADLINE);
    }

    function test_multiple_hackathons() public {
        address h1 = factory.createHackathon(0, DEADLINE);
        address h2 = factory.createHackathon(0.1 ether, DEADLINE);
        address h3 = factory.createHackathon{value: 1 ether}(0, DEADLINE);

        assertEq(factory.hackathonCount(), 3);

        address[] memory all = factory.getHackathons();
        assertEq(all.length, 3);
        assertEq(all[0], h1);
        assertEq(all[1], h2);
        assertEq(all[2], h3);
    }

    function test_created_escrow_full_lifecycle() public {
        address escrowAddr = factory.createHackathon{value: 2 ether}(0, DEADLINE);
        HackathonEscrow escrow = HackathonEscrow(payable(escrowAddr));

        // Alice joins
        vm.prank(alice);
        escrow.join{value: 0}();
        assertTrue(escrow.hasJoined(alice));

        // Owner finalizes (owner == address(this))
        address[] memory winners = new address[](1);
        winners[0] = alice;
        uint256[] memory shares = new uint256[](1);
        shares[0] = 10000;
        escrow.finalize(winners, shares);
        assertTrue(escrow.finalized());
        assertEq(escrow.getWinners()[0], alice);

        // Alice claims
        uint256 balBefore = alice.balance;
        vm.prank(alice);
        escrow.claim();
        assertEq(alice.balance, balBefore + 2 ether);
    }

    receive() external payable {}
}
