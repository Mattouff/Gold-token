// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/GoldToken.sol";
import "../src/GoldBridge.sol";

contract DemoScript is Script {
    address constant GOLD_TOKEN_ADDRESS = 0xb85aBf511b4b3A1775DD1e3A06310205aBC5561b;   // Address of GoldToken
    address constant GOLD_BRIDGE_ADDRESS = 0xCeBeDD9D6b7e4FF2F58e8eE0296a7f63db504588; // Address of GoldBridge
    address constant PROXY_ADDRESS = 0xb3D657D4C9686CAF32ac7485aF3A7CfFAb938398;              // Adresse of the proxy
    address constant RECEIVER_ADDRESS = 0x3c88dB8F24AD88A75FB4de1da97288772148D5B9;          // Address of the receiver

    address constant XAUUSD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant ETHUSD_FEED = 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea;
    uint64 constant SUBSCRIPTION_ID = 7032;

    function run() external {
        vm.startBroadcast();

        // Get the GoldToken and GoldBridge instances
        GoldToken goldToken = GoldToken(payable(PROXY_ADDRESS));
        GoldBridge goldBridge = GoldBridge(payable(GOLD_BRIDGE_ADDRESS));

        // Check if GoldToken is initialized
        if (address(goldToken.priceConsumer()) == address(0)) {
            console.log("Initializing GoldToken...");
            goldToken.initialize(XAUUSD_FEED, ETHUSD_FEED, SUBSCRIPTION_ID);
        } else {
            console.log("GoldToken already initialized.");
        }

        // 1. Mint tokens
        uint256 mintValue = 0.1 ether;
        console.log("Minting tokens with", mintValue, "wei");
        goldToken.mint{value: mintValue}();

        uint256 mintedBalance = goldToken.balanceOf(msg.sender);
        console.log("Minted token balance:", mintedBalance);

        // 2. Approve the GoldBridge to spend the minted tokens
        goldToken.approve(GOLD_BRIDGE_ADDRESS, 0);
        goldToken.approve(GOLD_BRIDGE_ADDRESS, mintedBalance);
        uint256 allowance = goldToken.allowance(msg.sender, GOLD_BRIDGE_ADDRESS);
        console.log("Allowance after approve:", allowance);
        require(allowance >= mintedBalance, "Approval failed: insufficient allowance");

        // 3. Send tokens via GoldBridge
        uint256 feeValue = 0.01 ether;
        console.log("Sending tokens via GoldBridge with fee", feeValue, "wei");
        
        goldBridge.sendGold{value: feeValue}(RECEIVER_ADDRESS, mintedBalance);
        console.log("Tokens bridged to receiver:", RECEIVER_ADDRESS);

        vm.stopBroadcast();
    }
}