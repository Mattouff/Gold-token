// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";
import "../src/GoldToken.sol";
import "../src/GoldBridge.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    uint64 public DESTINATION_CHAIN_ID;
    address public ethUsdFeed;
    address public xauUsdFeed;
    address public routerAddress;
    uint256 public vrfFee;
    uint64 public subscriptionID; 

    function run() external {
        vm.startBroadcast();

        if (block.chainid == 11155111) {
            // Sepolia Testnet
            ethUsdFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // Sepolia ETH/USD Feed
            xauUsdFeed = 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea; // Sepolia XAU/USD Feed
            routerAddress = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59; // Sepolia Router
            DESTINATION_CHAIN_ID = 13264668187771770619; // Destination chain selector
            subscriptionID = 7032;
        } else if (block.chainid == 137) {
            // BSC Testnet 
            ethUsdFeed = 0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e; // BNB ETH/USD Feed
            xauUsdFeed = 0x86896fEB19D8A607c3b11f2aF50A0f239Bd71CD0; // BNB XAU/USD Feed
            routerAddress = 0xC1C6438D60AbE9bF4b1F10460184CE9bD312e328; // BNB Router
            DESTINATION_CHAIN_ID = 11344663589394136015; // Destination chain selector
            subscriptionID = 7032; 
        } else {
            revert("Unsupported network");
        }
        vrfFee = 0.1 * 10 ** 18; // Exemple de fee (0.1 LINK)

        // 1. Deployement of the implementation of GoldToken (but empty)
        GoldToken goldTokenImpl = new GoldToken();

        // 2. Encode the data for the initialize function
        // The initialize function of GoldToken takes 3 arguments: xauUsdFeed, ethUsdFeed, subscriptionID
        bytes memory data = abi.encodeWithSelector(
            GoldToken.initialize.selector,
            xauUsdFeed,
            ethUsdFeed,
            subscriptionID
        );

        // 3. Deploy the proxy with the implementation and the data
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(goldTokenImpl),
            data
        );

        // 4. Convert the proxy address to payable
        address payable proxyAddress = payable(address(proxy));

        // 5. Deploy the GoldBridge contract
        // The GoldBridge contract takes 3 arguments: routerAddress, DESTINATION_CHAIN_ID, proxyAddress
        GoldBridge goldBridge = new GoldBridge(
            payable(routerAddress),
            DESTINATION_CHAIN_ID,
            proxyAddress
        );

        vm.stopBroadcast();
    }
}