// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract HackathonEscrow is ReentrancyGuard {
    address public owner;
    uint256 public entryFee;
    bool public finalized;
    address public winner;

    mapping(address => bool) public hasJoined;
    address[] public participants;

    event Joined(address participant);
    event Finalized(address winner);
    event Claimed(address winner, uint256 amount);

    constructor(uint256 _entryFee) {
        require(_entryFee > 0, "Entry fee must be > 0");
        owner = msg.sender;
        entryFee = _entryFee;
    }

    function join() external payable {
        require(!finalized, "Hackathon finalized");
        require(!hasJoined[msg.sender], "Already joined");
        require(msg.value == entryFee, "Wrong entry fee");

        hasJoined[msg.sender] = true;
        participants.push(msg.sender);

        emit Joined(msg.sender);
    }

    function finalize(address _winner) external {
        require(msg.sender == owner, "Not owner");
        require(!finalized, "Already finalized");
        require(hasJoined[_winner], "Winner not a participant");

        winner = _winner;
        finalized = true;

        emit Finalized(_winner);
    }

    function claim() external nonReentrant {
        require(finalized, "Not finalized");
        require(msg.sender == winner, "Not winner");

        uint256 amount = address(this).balance;
        winner = address(0);

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Claimed(msg.sender, amount);
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }
}
