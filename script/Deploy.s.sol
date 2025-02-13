// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../src/GoldToken.sol";
import "../src/Lottery.sol";
import "../src/PriceConsumer.sol";

contract DeployScript is Script {
    function testA() public {} // forge coverage ignore-file
    function run() external {
        vm.startBroadcast();

        // // Adresses Chainlink (Ethereum Mainnet)
        // address priceFeedAddressXAUUSD = 0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6; // Feed XAU/USD
        // address priceFeedAddressETHUSD = 0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6; // Feed XAU/USD
        // address vrfCoordinator = 0xf0d54349aDdcf704F77AE15b96510dEA15cb7952;
        // address linkToken = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        // bytes32 keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
        // uint256 vrfFee = 2 * 10 ** 18; // 2 LINK

        // // Déployer GoldToken avec les 5 paramètres requis
        // GoldToken goldToken = new GoldToken(
        //     priceFeedAddressXAUUSD,   // _priceFeedAddress
        //     priceFeedAddressETHUSD,   // _priceFeedAddress
        //     vrfCoordinator,     // _vrfCoordinator
        //     linkToken,          // _linkToken
        //     keyHash,            // _keyHash
        //     vrfFee              // _vrfFee
        // );

        vm.stopBroadcast();
    }
}