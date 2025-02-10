// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*//////////////////////////////////////////////////////////////
                           IMPORTS
//////////////////////////////////////////////////////////////*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@contracts/Lottery.sol";
import "@contracts/PriceConsumer.sol";

/*//////////////////////////////////////////////////////////////
                      GOLD TOKEN CONTRACT
//////////////////////////////////////////////////////////////*/
/// @title GoldToken
/// @notice ERC20 token representing gold that can be minted with ETH and burned to redeem ETH.
/// @dev Minting and burning operations apply a fee and distribute a share to a lottery contract.
contract GoldToken is ERC20 {
    /*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Instance of PriceConsumer for fetching the current gold price.
    PriceConsumer public priceConsumer;

    /// @notice Instance of Lottery for fee distribution.
    Lottery public lottery;

    /// @notice Fee percentage applied on minting and burning (5%).
    uint256 public constant FEE_PERCENT = 5;

    /// @notice Lottery share percentage of the fee (50% of the fee in ETH is sent to the lottery).
    uint256 public constant LOTTERY_SHARE = 50;

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructs the GoldToken contract.
    /// @param _priceFeedAddress Address of the price feed for gold.
    /// @param _vrfCoordinator Address of the VRF coordinator for the lottery.
    /// @param _linkToken Address of the LINK token used by the lottery.
    /// @param _keyHash Key hash used for VRF.
    /// @param _vrfFee Fee required for VRF.
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

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints GoldToken by sending ETH.
    /// @dev 5% fee is deducted from the sent ETH, and 50% of that fee is forwarded to the lottery.
    /// @dev The number of tokens minted is calculated based on the ETH received after fee deduction and the current gold price.
    function mint() external payable {
        require(msg.value > 0, "Send ETH to mint tokens");

        uint256 goldPriceInWei = priceConsumer.getGoldPrice();

        // Calculate fee in ETH (5% of the sent amount)
        uint256 feeEth = (msg.value * FEE_PERCENT) / 100;
        uint256 ethAfterFee = msg.value - feeEth;

        // Calculate the number of tokens to mint based on the gold price (price in wei)
        uint256 tokensToMint = (ethAfterFee * 1e18) / goldPriceInWei;

        _mint(msg.sender, tokensToMint);

        // Distribute fees: 50% of fee ETH is sent to the lottery contract.
        uint256 lotteryAmount = feeEth / 2;
        payable(address(lottery)).transfer(lotteryAmount);
    }

    /// @notice Burns GoldToken to redeem ETH.
    /// @dev 5% fee is deducted from the ETH returned, and 50% of that fee is forwarded to the lottery.
    /// @param amount The amount of tokens to burn.
    function burn(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 goldPriceInWei = priceConsumer.getGoldPrice();
        uint256 ethToReturn = (amount * goldPriceInWei) / 1e18;

        // Calculate fee in ETH (5% of the ETH to return)
        uint256 feeEth = (ethToReturn * FEE_PERCENT) / 100;
        uint256 ethAfterFee = ethToReturn - feeEth;

        _burn(msg.sender, amount);
        payable(msg.sender).transfer(ethAfterFee);

        // Distribute fees: 50% of fee ETH is sent to the lottery contract.
        uint256 lotteryAmount = feeEth / 2;
        payable(address(lottery)).transfer(lotteryAmount);
    }
}
