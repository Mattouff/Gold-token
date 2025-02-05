// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConsumer {
    AggregatorV3Interface internal priceFeed;

    constructor(address _priceFeedAddress) {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }
    function getGoldPrice() public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price) * 1e10; // Conversion en wei
    }
}