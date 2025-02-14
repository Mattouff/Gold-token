// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*//////////////////////////////////////////////////////////////
//                           IMPORTS
//////////////////////////////////////////////////////////////*/
import "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; 
import {VRFConsumerBaseV2Plus} from "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

/*//////////////////////////////////////////////////////////////
//                      LOTTERY CONTRACT
//////////////////////////////////////////////////////////////*/
/**
 * @title Lottery
 * @notice This contract manages a lottery using Chainlink VRF to generate a random number.
 * @dev Only the GoldToken contract (owner) can trigger the lottery via functions marked with `onlyOwner`.
 */
contract Lottery is VRFConsumerBaseV2Plus {

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Interface for the Chainlink VRF Coordinator.
    VRFCoordinatorV2Interface public COORDINATOR;

    /// @notice The key hash used to identify the Chainlink VRF job.
    bytes32 internal keyHash;

    /// @notice The subscription ID for Chainlink VRF.
    uint256 public s_subscriptionId;

    /// @notice The number of confirmations required before fulfillment.
    uint16 public requestConfirmations = 3;

    /// @notice The gas limit for the VRF callback function.
    uint32 public callbackGasLimit = 100000;

    /// @notice The number of random words requested.
    uint32 public numWords = 1;

    /// @notice The latest random result received.
    uint256 public randomResult;

    /// @notice Array of lottery participants.
    address[] public participants;

    /// @notice Total ETH collected in the lottery pool.
    uint256 public lotteryPool;

    /// @notice Structure to track the status of a VRF request.
    struct RequestStatus {
        uint256[] randomWords;
        bool exists;
        bool fulfilled;
    }

    /// @notice Mapping from VRF request ID to its status.
    mapping(uint256 => RequestStatus) public s_requests;

    /// @notice Array of all VRF request IDs.
    uint256[] public requestIds;

    /// @notice The last VRF request ID.
    uint256 public lastRequestId;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a lottery winner is selected.
    event LotteryWinner(address indexed winner, uint256 amount);

    /// @notice Emitted when a VRF request is sent.
    event RequestSent(uint256 requestId, uint32 numWords);

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for the Lottery contract.
     * @param subscriptionId The subscription ID for Chainlink VRF.
     */
    constructor(uint256 subscriptionId)
        VRFConsumerBaseV2Plus(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B)
    {
        s_subscriptionId = subscriptionId;
        COORDINATOR = VRFCoordinatorV2Interface(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
        keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    }

    /*//////////////////////////////////////////////////////////////
                        FALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Fallback function to receive ETH.
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                      EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Collects fees and adds a participant.
     * @dev Only the GoldToken contract (owner) can call this function.
     */
    function distributeFees() external payable onlyOwner {
        require(msg.value > 0, "No ETH sent");
        lotteryPool += msg.value;
        participants.push(msg.sender);

        // Trigger the lottery when there are at least 10 participants.
        if (participants.length >= 10) {
            _requestRandomWords();
        }
    }

    /*//////////////////////////////////////////////////////////////
                      PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Requests random words from Chainlink VRF.
     * @dev Only the GoldToken contract (owner) can call this function.
     * @return requestId The VRF request ID.
     */
    function _requestRandomWords() private returns (uint256 requestId) {
        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: keyHash,
            subId: s_subscriptionId,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit,
            numWords: numWords,
            // Set nativePayment to false to pay for VRF requests with LINK instead of native ETH.
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({ nativePayment: true })
            )
        });
        requestId = s_vrfCoordinator.requestRandomWords(req);
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Callback function used by Chainlink VRF to deliver random words.
     * @param requestId The ID of the completed VRF request.
     * @param randomWords The random words returned by Chainlink VRF.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(s_requests[requestId].exists, "Request not found");

        s_requests[requestId].fulfilled = true;
        s_requests[requestId].randomWords = randomWords;

        uint256 winnerIndex = randomWords[0] % participants.length;
        address winner = participants[winnerIndex];

        payable(winner).transfer(lotteryPool);
        emit LotteryWinner(winner, lotteryPool);

        // Reset state for the next lottery round.
        participants = new address[](0);
        lotteryPool = 0;
    }
}
