// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract HackathonEscrow is ReentrancyGuard {
    address public owner;
    address public sponsor;
    uint256 public entryFee;
    uint256 public deadline;
    bool public finalized;
    address public winner;

    mapping(address => bool) public hasJoined;
    address[] public participants;

    event Joined(address indexed participant);
    event Finalized(address indexed winner);
    event Claimed(address indexed winner, uint256 amount);
    event Funded(address indexed sponsor, uint256 amount);
    event Aborted(address indexed sponsor, uint256 amount);

    constructor(uint256 _entryFee, uint256 _deadline, address _owner, address _sponsor) payable {
        owner = _owner;
        sponsor = _sponsor;
        entryFee = _entryFee;
        deadline = _deadline;
        if (msg.value > 0) {
            emit Funded(msg.sender, msg.value);
        }
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

    function abort() external nonReentrant {
        require(msg.sender == owner, "Not owner");
        require(!finalized, "Already finalized");
        require(block.timestamp > deadline, "Hackathon not expired");

        finalized = true;
        uint256 amount = address(this).balance;

        (bool success,) = sponsor.call{value: amount}("");
        require(success, "Transfer failed");

        emit Aborted(sponsor, amount);
    }

    function prizePool() external view returns (uint256) {
        return address(this).balance;
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    receive() external payable {
        require(!finalized, "Hackathon finalized");
        emit Funded(msg.sender, msg.value);
    }
}
