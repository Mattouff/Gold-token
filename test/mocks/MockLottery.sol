// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@contracts/Lottery.sol";

/// @dev Testable version of the Lottery contract that exposes fulfillRandomWords publicly.
contract MockLottery is Lottery {
    constructor(uint256 subscriptionId) Lottery(subscriptionId) {}

    /// @dev Allows calling the internal fulfillRandomWords function from tests.
    function externalFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        fulfillRandomWords(requestId, randomWords);
    }
}