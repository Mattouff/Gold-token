// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*//////////////////////////////////////////////////////////////
                           IMPORTS
//////////////////////////////////////////////////////////////*/

import "@chainlink/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/VRFConsumerBase.sol";

/*//////////////////////////////////////////////////////////////
                        LOTTERY CONTRACT
//////////////////////////////////////////////////////////////*/
/// @title Lottery
/// @notice This contract manages a lottery by collecting fees and selecting a winner using Chainlink VRF.
/// @dev Inherits from VRFConsumerBase to integrate with Chainlink VRF for randomness.
contract Lottery is VRFConsumerBase {
    /*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The key hash used by the Chainlink VRF.
    bytes32 internal keyHash;

    /// @notice The fee required by the Chainlink VRF.
    uint256 internal fee;

    /// @notice The latest random number received from Chainlink VRF.
    uint256 public randomResult;

    /// @notice The list of participants in the lottery.
    address[] public participants;

    /// @notice The total amount of ETH collected for the lottery.
    uint256 public lotteryPool;

    /*//////////////////////////////////////////////////////////////
                           EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a lottery winner is selected.
    /// @param winner The address of the winner.
    /// @param amount The amount of ETH won.
    event LotteryWinner(address winner, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructs the Lottery contract.
    /// @param _vrfCoordinator The address of the Chainlink VRF coordinator.
    /// @param _linkToken The address of the LINK token.
    /// @param _keyHash The key hash for Chainlink VRF.
    /// @param _vrfFee The fee for Chainlink VRF.
    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _vrfFee
    )
        VRFConsumerBase(_vrfCoordinator, _linkToken)
    {
        keyHash = _keyHash;
        fee = _vrfFee;
    }

    /*//////////////////////////////////////////////////////////////
                        FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fallback function to accept ETH deposits.
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Accepts ETH fees and adds the sender as a lottery participant.
    /// @dev When at least 10 participants have contributed, it triggers a randomness request via Chainlink VRF.
    function distributeFees() external payable {
        require(msg.value > 0, "No fees to distribute");

        lotteryPool += msg.value;
        participants.push(msg.sender);

        if (lotteryPool > 0 && participants.length >= 10) {
            requestRandomness(keyHash, fee);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function used by Chainlink VRF to deliver randomness.
    /// @dev Selects a winner based on the randomness received, transfers the entire lottery pool to the winner, and resets the lottery.
    /// @param requestId The ID of the VRF request.
    /// @param randomness The random number provided by Chainlink VRF.
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
        uint256 winnerIndex = randomness % participants.length;
        address winner = participants[winnerIndex];

        // Transfer the entire lottery pool to the winner.
        payable(winner).transfer(lotteryPool);
        emit LotteryWinner(winner, lotteryPool);

        // Reset the lottery pool and clear the participants.
        lotteryPool = 0;
        delete participants;
    }
}
