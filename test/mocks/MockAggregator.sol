// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title MockAggregator
/// @notice Un mock de l'agrégateur de Chainlink pour simuler latestRoundData().
contract MockAggregator is AggregatorV3Interface {

    function testA() public {} // forge coverage ignore-file

    uint8 public override decimals;
    string public override description;
    uint256 public override version;
    uint80 public roundId;

    int256 public answer;

    constructor(int256 _answer) {
        decimals = 8; 
        description = "Mock Aggregator";
        version = 1;
        roundId = 1;
        answer = _answer;
    }

    /// @notice Permet de mettre à jour la réponse simulée.
    function setAnswer(int256 _answer) public {
        answer = _answer;
    }

    /// @notice Simule the latestRoundData() function.
    function latestRoundData()
        external
        view
        override
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (roundId, answer, 0, 0, roundId);
    }

    /// @notice Simule the getRoundData() function.
    function getRoundData(uint80 /* _roundId */)
        external
        view
        override
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (roundId, answer, 0, 0, roundId);
    }
}