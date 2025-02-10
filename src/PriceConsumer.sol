// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*//////////////////////////////////////////////////////////////
//                           IMPORTS
//////////////////////////////////////////////////////////////*/

import "@chainlink/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*//////////////////////////////////////////////////////////////
//                    PRICE CONSUMER CONTRACT
//////////////////////////////////////////////////////////////*/
/// @title PriceConsumer
/// @notice Retrieves the current gold price in wei using a Chainlink price feed.
/// @dev Fetches the latest price from an AggregatorV3Interface and converts it to wei.
contract PriceConsumer {
    /*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Chainlink price feed interface.
    AggregatorV3Interface internal priceFeed;

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the PriceConsumer contract.
    /// @param _priceFeedAddress The address of the Chainlink price feed.
    constructor(address _priceFeedAddress) {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the current gold price in wei.
    /// @dev Calls latestRoundData() on the price feed and converts the returned price to wei.
    /// @return The gold price in wei.
    function getGoldPrice() public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price) * 1e10; // Conversion to wei (assuming the price feed returns 8 decimals)
    }
}
