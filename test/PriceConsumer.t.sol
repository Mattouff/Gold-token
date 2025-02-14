// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@contracts/PriceConsumer.sol";
import "@chainlink/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@mocks/MockAggregator.sol";


/// @title PriceConsumerTest
/// @notice Teste le contrat PriceConsumer.
contract PriceConsumerTest is Test {
    PriceConsumer public priceConsumer;
    MockAggregator public mockXAUUSD;
    MockAggregator public mockETHUSD;

    /// @notice Initialize the PriceConsumer contract with valid price feeds.
    /// To have 1e18 as a result, we need the following values:
    /// - ethPrice = 1e8 (with 1.0, 8 decimals)
    /// - xauPrice = 311035e8 (with 311035, 8 decimals)
    /// The conversion made by PriceConsumer is the following:
    ///    (xauUsd * 1e18) / (ethUsd * 311035)
    /// with xauUsd = 311035e8 * 1e10 = 311035e18 and ethUsd = 1e8 * 1e10 = 1e18,
    /// d'où : (311035e18 * 1e18) / (1e18 * 311035) = 1e18.
    function setUp() public {
        int256 ethAnswer = 1e8;           // represents 1.0 with 8 decimals
        int256 xauAnswer = 311035e8;        // represents 311035 with 8 decimals

        mockXAUUSD = new MockAggregator(xauAnswer);
        mockETHUSD = new MockAggregator(ethAnswer);

        priceConsumer = new PriceConsumer(address(mockXAUUSD), address(mockETHUSD));
    }

    /// @notice Check that getGoldPrice() returns the correct value.
    function testGetGoldPriceValid() view public {
        uint256 goldPrice = priceConsumer.getGoldPrice();
        assertEq(goldPrice, 1e18, "Gold price should be 1e18");
    }

    /// @notice Check that getGoldPrice() reverts if the XAU price is zero.
    function testGetGoldPriceRevertsOnZeroXAU() public {
        mockXAUUSD.setAnswer(0);
        vm.expectRevert("XAU price feed error");
        priceConsumer.getGoldPrice();
    }

    /// @notice Check that getGoldPrice() reverts if the ETH price is zero.
    function testGetGoldPriceRevertsOnZeroETH() public {
        mockETHUSD.setAnswer(0);
        vm.expectRevert("ETH price feed error");
        priceConsumer.getGoldPrice();
    }

    /// @notice Check that getGoldPrice() reverts if the XAU price is negative.
    function testGetGoldPriceRevertsOnNegativeXAU() public {
        mockXAUUSD.setAnswer(-100);
        vm.expectRevert("XAU price feed error");
        priceConsumer.getGoldPrice();
    }

    /// @notice Check that getGoldPrice() reverts if the ETH price is negative.
    function testGetGoldPriceRevertsOnNegativeETH() public {
        mockETHUSD.setAnswer(-100);
        vm.expectRevert("ETH price feed error");
        priceConsumer.getGoldPrice();
    }
}
