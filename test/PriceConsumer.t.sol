// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@contracts/PriceConsumer.sol";
import "@chainlink/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@mocks/MockAggregator.sol";

/// @notice Test du contrat PriceConsumer
contract PriceConsumerTest is Test {
    MockAggregator public mockAggregator;
    PriceConsumer public priceConsumer;

    function setUp() public {
        // Pour un test simple, on initialise le mock avec un prix positif.
        // Par exemple, un prix de 2000 avec 8 décimales : 2000 * 1e8.
        int256 initialPrice = 2000 * int256(10**8);
        mockAggregator = new MockAggregator(initialPrice);
        priceConsumer = new PriceConsumer(address(mockAggregator));
    }

    /// @notice Vérifie que getGoldPrice() renvoie le prix converti correctement.
    /// Avec un prix initial de 2000 * 1e8, la conversion est : 2000e8 * 1e10 = 2000e18.
    function testGetGoldPriceValid() public {
        uint256 expectedPrice = uint256(2000 * 10**8) * 10**10; // 2000 * 1e18
        uint256 goldPrice = priceConsumer.getGoldPrice();
        assertEq(goldPrice, expectedPrice);
    }

    /// @notice Vérifie que getGoldPrice() reverte si l'agrégateur retourne 0.
    function testGetGoldPriceRevertsOnZeroPrice() public {
        mockAggregator.setPrice(0);
        vm.expectRevert("Invalid price");
        priceConsumer.getGoldPrice();
    }

    /// @notice Vérifie que getGoldPrice() reverte si l'agrégateur retourne un prix négatif.
    function testGetGoldPriceRevertsOnNegativePrice() public {
        mockAggregator.setPrice(-100);
        vm.expectRevert("Invalid price");
        priceConsumer.getGoldPrice();
    }
}