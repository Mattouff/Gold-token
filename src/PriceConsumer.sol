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
    AggregatorV3Interface internal xauusdAggregator;

    AggregatorV3Interface internal ethusdAggregator;

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the PriceConsumer contract.
    constructor(address _xauusdAddress, address _ethusdAddress) {
        xauusdAggregator = AggregatorV3Interface(_xauusdAddress);
        ethusdAggregator = AggregatorV3Interface(_ethusdAddress);
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getGoldPrice() public view returns (uint256) {
        (, int256 xauPrice, , , ) = xauusdAggregator.latestRoundData();
        (, int256 ethPrice, , , ) = ethusdAggregator.latestRoundData();

        require(xauPrice > 0, "XAU price feed error");
        require(ethPrice > 0, "ETH price feed error");

        // Conversion des prix de 8 décimales à 18 décimales
        uint256 xauUsd = uint256(xauPrice) * 1e10; // 1 XAU en USD (18 décimales)
        uint256 ethUsd = uint256(ethPrice) * 1e10; // 1 ETH en USD (18 décimales)

        // Retourne la valeur de 1 gramme d'or (1/31.1035 XAU) en ETH
        return (xauUsd * 1e18) / (ethUsd * 311035); // 1 XAU = 31.1035 grammes
    }
}
