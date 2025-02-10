// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @notice Contrat mock pour simuler un agrégateur Chainlink
contract MockAggregator is AggregatorV3Interface {
    int256 public price; // La valeur actuelle du prix
    uint8 public override decimals;
    string public override description;
    uint256 public override version;
    uint80 public roundId;

    function testA() public {} // forge coverage ignore-file

    constructor(int256 _price) {
        price = _price;
        decimals = 8; // Les agrégateurs Chainlink typiques utilisent 8 décimales
        description = "Mock Aggregator";
        version = 1;
        roundId = 1;
    }

    /// @notice Permet de modifier le prix retourné (pour les tests)
    function setPrice(int256 _price) external {
        price = _price;
    }

    /// @notice Renvoie les données de la dernière ronde
    function latestRoundData()
        external
        view
        override
        returns (
            uint80,    // roundId
            int256,    // answer
            uint256,   // startedAt
            uint256,   // updatedAt
            uint80     // answeredInRound
        )
    {
        return (roundId, price, 0, 0, roundId);
    }

    /// @notice Fonction supplémentaire de l'interface (non utilisée dans PriceConsumer)
    function getRoundData(uint80 /*_roundId*/)
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
        return (roundId, price, 0, 0, roundId);
    }
}