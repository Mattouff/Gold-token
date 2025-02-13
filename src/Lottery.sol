// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; 
import {VRFConsumerBaseV2Plus} from "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";

/// @title Lottery Contract
/// @notice This contract manages a lottery system using Chainlink VRF for randomness.
/// @dev Inherits from VRFConsumerBaseV2Plus to integrate with Chainlink VRF.
contract Lottery is VRFConsumerBaseV2Plus {
    /// @notice The Chainlink VRF Coordinator interface.
    VRFCoordinatorV2Interface COORDINATOR;

    /// @notice The key hash used to identify the Chainlink VRF job.
    bytes32 internal keyHash;

    /// @notice The subscription ID for Chainlink VRF.
    uint64 public s_subscriptionId;

    /// @notice Number of confirmations required before fulfilling randomness.
    uint16 requestConfirmations = 3;

    /// @notice Gas limit for the callback function.
    uint32 callbackGasLimit = 100000;

    /// @notice Number of random words requested.
    uint32 numWords = 1;

    /// @notice The latest random number received.
    uint256 public randomResult;

    /// @notice List of participants in the lottery.
    address[] public participants;

    /// @notice Total amount of ETH collected in the lottery pool.
    uint256 public lotteryPool;

    /// @notice Structure to track the status of VRF requests.
    struct RequestStatus {
        uint256[] randomWords;
        bool exists;
        bool fulfilled;
    }

    /// @notice Mapping of request IDs to their statuses.
    mapping(uint256 => RequestStatus) public s_requests;

    /// @notice List of all VRF request IDs.
    uint256[] public requestIds;

    /// @notice The last VRF request ID made.
    uint256 public lastRequestId;

    /// @notice Emitted when a lottery winner is selected.
    /// @param winner The address of the lottery winner.
    /// @param amount The amount of ETH won.
    event LotteryWinner(address indexed winner, uint256 amount);

    /// @notice Emitted when a randomness request is sent to Chainlink VRF.
    /// @param requestId The ID of the randomness request.
    /// @param numWords The number of random words requested.
    event RequestSent(uint256 requestId, uint32 numWords);

    /// @notice Constructs the Lottery contract and initializes Chainlink VRF.
    /// @param subscriptionId The subscription ID for Chainlink VRF.
    constructor(uint64 subscriptionId)
        VRFConsumerBaseV2Plus(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B)
    {
        s_subscriptionId = subscriptionId;
        COORDINATOR = VRFCoordinatorV2Interface(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a48db59e5c46df3f6f2b;
    }

    /// @notice Fallback function to accept ETH deposits.
    receive() external payable {}

    /// @notice Accepts ETH fees and registers the sender as a lottery participant.
    /// @dev Triggers a randomness request when at least 10 participants are registered.
    function distributeFees() external payable {
        require(msg.value > 0, "No fees to distribute");
        lotteryPool += msg.value;
        participants.push(msg.sender);

        if (participants.length >= 10) {
            requestRandomWords();
        }
    }

    /// @notice Requests random words from Chainlink VRF.
    /// @return requestId The ID of the randomness request.
    function requestRandomWords() public returns (uint256 requestId) {
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),       
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
    }

    /// @notice Callback function used by Chainlink VRF to deliver randomness.
    /// @param requestId The ID of the fulfilled randomness request.
    /// @param randomWords The array of random words returned by Chainlink VRF.
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(s_requests[requestId].exists, "Request not found");

        s_requests[requestId].fulfilled = true;
        s_requests[requestId].randomWords = randomWords;

        uint256 winnerIndex = randomWords[0] % participants.length;
        address winner = participants[winnerIndex];

        payable(winner).transfer(lotteryPool);
        emit LotteryWinner(winner, lotteryPool);

        participants = new address[](0);
        lotteryPool = 0;
    }
}