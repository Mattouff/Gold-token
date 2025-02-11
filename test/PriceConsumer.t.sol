// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/PriceConsumer.sol";
import "@chainlink/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title MockAggregator
/// @notice Un mock de l'agrégateur de Chainlink pour simuler latestRoundData().
contract MockAggregator is AggregatorV3Interface {
    uint8 public override decimals;
    string public override description;
    uint256 public override version;
    uint80 public roundId;

    int256 public answer;

    constructor(int256 _answer) {
        decimals = 8; // typiquement 8 décimales pour les agrégateurs Chainlink
        description = "Mock Aggregator";
        version = 1;
        roundId = 1;
        answer = _answer;
    }

    /// @notice Permet de mettre à jour la réponse simulée.
    function setAnswer(int256 _answer) public {
        answer = _answer;
    }

    /// @notice Simule la fonction latestRoundData().
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

    /// @notice Simule la fonction getRoundData().
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

/// @title PriceConsumerTest
/// @notice Teste le contrat PriceConsumer.
contract PriceConsumerTest is Test {
    PriceConsumer public priceConsumer;
    MockAggregator public mockXAUUSD;
    MockAggregator public mockETHUSD;

    /// @notice Initialisation du test avec des valeurs permettant de retourner 1e18.
    /// Pour obtenir 1e18, nous choisissons les valeurs suivantes :
    /// - ethPrice = 1e8 (soit 1, avec 8 décimales)
    /// - xauPrice = 311035e8 (soit 311035, avec 8 décimales)
    /// Ainsi, la conversion effectuée par PriceConsumer est :
    ///    (xauUsd * 1e18) / (ethUsd * 311035)
    /// avec xauUsd = 311035e8 * 1e10 = 311035e18 et ethUsd = 1e8 * 1e10 = 1e18,
    /// d'où : (311035e18 * 1e18) / (1e18 * 311035) = 1e18.
    function setUp() public {
        int256 ethAnswer = 1e8;           // représente 1.0 avec 8 décimales
        int256 xauAnswer = 311035e8;        // représente 311035 avec 8 décimales

        mockXAUUSD = new MockAggregator(xauAnswer);
        mockETHUSD = new MockAggregator(ethAnswer);

        priceConsumer = new PriceConsumer(address(mockXAUUSD), address(mockETHUSD));
    }

    /// @notice Vérifie que getGoldPrice() retourne 1e18 avec des flux de prix valides.
    function testGetGoldPriceValid() public {
        uint256 goldPrice = priceConsumer.getGoldPrice();
        assertEq(goldPrice, 1e18, "Gold price should be 1e18");
    }

    /// @notice Vérifie que getGoldPrice() reverte si le prix XAU est zéro.
    function testGetGoldPriceRevertsOnZeroXAU() public {
        mockXAUUSD.setAnswer(0);
        vm.expectRevert("XAU price feed error");
        priceConsumer.getGoldPrice();
    }

    /// @notice Vérifie que getGoldPrice() reverte si le prix ETH est zéro.
    function testGetGoldPriceRevertsOnZeroETH() public {
        mockETHUSD.setAnswer(0);
        vm.expectRevert("ETH price feed error");
        priceConsumer.getGoldPrice();
    }

    /// @notice Vérifie que getGoldPrice() reverte si le prix XAU est négatif.
    function testGetGoldPriceRevertsOnNegativeXAU() public {
        mockXAUUSD.setAnswer(-100);
        vm.expectRevert("XAU price feed error");
        priceConsumer.getGoldPrice();
    }

    /// @notice Vérifie que getGoldPrice() reverte si le prix ETH est négatif.
    function testGetGoldPriceRevertsOnNegativeETH() public {
        mockETHUSD.setAnswer(-100);
        vm.expectRevert("ETH price feed error");
        priceConsumer.getGoldPrice();
    }
}
