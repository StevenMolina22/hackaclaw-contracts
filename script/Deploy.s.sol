// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HackathonEscrow} from "../src/HackathonEscrow.sol";
import {HackathonFactory} from "../src/HackathonFactory.sol";

contract DeployHackathonEscrow is Script {
    function run() external returns (HackathonEscrow escrow) {
        address token = vm.envAddress("USDC_ADDRESS");
        uint256 entryFee = vm.envOr("ENTRY_FEE_UNITS", uint256(0));
        uint256 deadline = vm.envUint("DEADLINE_UNIX");

        vm.startBroadcast();
        escrow = new HackathonEscrow(token, entryFee, deadline, msg.sender, msg.sender);
        vm.stopBroadcast();

        console.log("HackathonEscrow deployed at:", address(escrow));
        console.log("USDC token:", token);
        console.log("Entry fee (token units):", entryFee);
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
