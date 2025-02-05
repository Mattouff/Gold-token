// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/VRFConsumerBase.sol";

contract Lottery is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    address[] public participants;
    uint256 public lotteryPool;

    event LotteryWinner(address winner, uint256 amount);

    constructor(address _vrfCoordinator, address _linkToken, bytes32 _keyHash, uint256 _vrfFee)
        VRFConsumerBase(_vrfCoordinator, _linkToken)
    {
        keyHash = _keyHash;
        fee = _vrfFee;
    }

    function distributeFees() external payable {
        require(msg.value > 0, "No fees to distribute");
        lotteryPool += msg.value;
        participants.push(msg.sender);

        if (lotteryPool > 0 && participants.length >= 10) {
            requestRandomness(keyHash, fee);
        }
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
        uint256 winnerIndex = randomness % participants.length;
        address winner = participants[winnerIndex];

        // Distribuer le pool au gagnant
        payable(winner).transfer(lotteryPool);
        emit LotteryWinner(winner, lotteryPool);

        // Réinitialiser le pool et les participants
        lotteryPool = 0;
        delete participants;
    }
}