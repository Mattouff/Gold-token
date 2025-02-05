// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./Lottery.sol";
import "./PriceConsumer.sol";

contract GoldToken is ERC20 {
    PriceConsumer public priceConsumer; // <-- Public
    Lottery public lottery; // <-- Public
    uint256 public constant FEE_PERCENT = 5;
    uint256 public constant LOTTERY_SHARE = 50;

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _vrfFee
    ) ERC20("GoldToken", "GLD") {
        priceConsumer = new PriceConsumer(_priceFeedAddress);
        lottery = new Lottery(_vrfCoordinator, _linkToken, _keyHash, _vrfFee);
    }

    function mint() external payable {
        require(msg.value > 0, "Send ETH to mint tokens");

        uint256 goldPriceInWei = priceConsumer.getGoldPrice();
        
        // Frais en ETH (5% du montant envoyé)
        uint256 feeEth = (msg.value * FEE_PERCENT) / 100;
        uint256 ethAfterFee = msg.value - feeEth;

        // Calcul des tokens à mint
        uint256 tokensToMint = (ethAfterFee * 1e18) / goldPriceInWei;

        _mint(msg.sender, tokensToMint);

        // Distribuer les frais (50% en ETH à la lotterie)
        uint256 lotteryAmount = feeEth / 2;
        payable(address(lottery)).transfer(lotteryAmount);
    }

    function burn(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 goldPriceInWei = priceConsumer.getGoldPrice();
        uint256 ethToReturn = (amount * goldPriceInWei) / 1e18;

        // Frais en ETH (5% du montant à retourner)
        uint256 feeEth = (ethToReturn * FEE_PERCENT) / 100;
        uint256 ethAfterFee = ethToReturn - feeEth;

        _burn(msg.sender, amount);
        payable(msg.sender).transfer(ethAfterFee);

        // Distribuer les frais (50% en ETH à la lotterie)
        uint256 lotteryAmount = feeEth / 2;
        payable(address(lottery)).transfer(lotteryAmount);
    }
}