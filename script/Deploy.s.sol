// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HackathonEscrow} from "../src/HackathonEscrow.sol";
import {HackathonFactory} from "../src/HackathonFactory.sol";

contract DeployHackathonEscrow is Script {
    function run() external returns (HackathonEscrow escrow) {
        uint256 entryFee = vm.envOr("ENTRY_FEE_WEI", uint256(0));
        uint256 bounty = vm.envOr("BOUNTY_WEI", uint256(0));
        uint256 deadline = vm.envUint("DEADLINE_UNIX");

        vm.startBroadcast();
        escrow = new HackathonEscrow{value: bounty}(entryFee, deadline, msg.sender, msg.sender);
        vm.stopBroadcast();

        console.log("HackathonEscrow deployed at:", address(escrow));
        console.log("Entry fee (wei):", entryFee);
        console.log("Bounty (wei):", bounty);
        console.log("Deadline (unix):", deadline);
    }
}

contract DeployFactory is Script {
    function run() external returns (HackathonFactory factory) {
        vm.startBroadcast();
        factory = new HackathonFactory();
        vm.stopBroadcast();

        console.log("HackathonFactory deployed at:", address(factory));
    }
}
