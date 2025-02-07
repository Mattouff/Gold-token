// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/PriceConsumer.sol";
import "./mocks/MockAggregatorV3.sol";

contract PriceConsumerTest is Test {
    PriceConsumer priceConsumer;

    // Adresse de l'oracle Chainlink pour XAU/USD sur Ethereum mainnet
    address XAU_USD_ORACLE = 0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6;

    function setUp() public {
        // Déployer le contrat avec l'adresse de l'oracle Chainlink
        priceConsumer = new PriceConsumer(XAU_USD_ORACLE);
    }

    function testGetGoldPrice() public {
        uint256 goldPrice = priceConsumer.getGoldPrice();
        
        console.log("Gold Price (in wei):", goldPrice);

        // Vérification que le prix est supérieur à zéro
        assertGt(goldPrice, 0, "Valid price");
    }

    function testInvalidPrice() public {
        // Déployer un mock avec un prix invalide (0)
        MockAggregatorV3 mockOracle = new MockAggregatorV3(0);
        PriceConsumer fakePriceConsumer = new PriceConsumer(address(mockOracle));

        // On s'attend à un revert avec le message "Invalid price"
        vm.expectRevert(bytes("Invalid price"));
        fakePriceConsumer.getGoldPrice();
    }
}
