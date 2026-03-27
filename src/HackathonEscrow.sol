// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract HackathonEscrow is ReentrancyGuard {
    address public owner;
    address public sponsor;
    uint256 public entryFee;
    uint256 public deadline;
    bool public finalized;

    address[] public winners;
    mapping(address => uint256) public winnerShareBps; // basis points (10000 = 100%)
    mapping(address => bool) public hasClaimed;
    uint256 public totalPrizeAtFinalize;

    mapping(address => bool) public hasJoined;
    address[] public participants;

    event Joined(address indexed participant);
    event Finalized(address[] winners, uint256[] sharesBps);
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

    function finalize(address[] calldata _winners, uint256[] calldata _sharesBps) external {
        require(msg.sender == owner, "Not owner");
        require(!finalized, "Already finalized");
        require(_winners.length > 0, "No winners");
        require(_winners.length <= 20, "Too many winners");
        require(_winners.length == _sharesBps.length, "Length mismatch");

        uint256 totalBps;
        for (uint256 i = 0; i < _winners.length; i++) {
            require(winnerShareBps[_winners[i]] == 0, "Duplicate winner");
            require(_sharesBps[i] > 0, "Zero share");
            winnerShareBps[_winners[i]] = _sharesBps[i];
            totalBps += _sharesBps[i];
        }
        require(totalBps == 10000, "Shares must sum to 10000");

        winners = _winners;
        totalPrizeAtFinalize = address(this).balance;
        finalized = true;

        emit Finalized(_winners, _sharesBps);
    }

    function claim() external nonReentrant {
        require(finalized, "Not finalized");
        uint256 shareBps = winnerShareBps[msg.sender];
        require(shareBps > 0, "Not a winner");
        require(!hasClaimed[msg.sender], "Already claimed");

        hasClaimed[msg.sender] = true;
        uint256 amount = (totalPrizeAtFinalize * shareBps) / 10000;

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

    function getWinners() external view returns (address[] memory) {
        return winners;
    }

    function getWinnerShare(address _winner) external view returns (uint256) {
        return winnerShareBps[_winner];
    }

    function winnerCount() external view returns (uint256) {
        return winners.length;
    }

    receive() external payable {
        require(!finalized, "Hackathon finalized");
        emit Funded(msg.sender, msg.value);
    }
}
