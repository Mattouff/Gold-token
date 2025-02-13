// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*//////////////////////////////////////////////////////////////
//                           IMPORTS
//////////////////////////////////////////////////////////////*/
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@contracts/Lottery.sol";
import "@contracts/PriceConsumer.sol";

/*//////////////////////////////////////////////////////////////
//                     GOLD TOKEN UUPS CONTRACT
//////////////////////////////////////////////////////////////*/
/**
 * @title GoldToken
 * @notice ERC20 token representing gold that can be minted with ETH and burned to redeem ETH.
 * @dev Uses the UUPS proxy upgradeability pattern.
 */
contract GoldToken is Initializable, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
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
                        INITIALIZER FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the contract replacing the constructor.
     * @param _xauusdAddress Address of the XAU/USD price feed.
     * @param _ethusdAddress Address of the ETH/USD price feed.
     * @param _subscriptionId Id of the Chainlink's subscription
     */
    function initialize(
        address _xauusdAddress,
        address _ethusdAddress,
        uint64 _subscriptionId
    ) public initializer {
        __ERC20_init("GoldToken", "GLD");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        priceConsumer = new PriceConsumer(_xauusdAddress, _ethusdAddress);
        lottery = new Lottery(_subscriptionId);
    }

    /*//////////////////////////////////////////////////////////////
                      EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints GoldToken by sending ETH.
     * @dev 5% fee is deducted from the sent ETH, and 50% of that fee is forwarded to the lottery.
     *      The number of tokens minted is calculated based on the ETH received after fee deduction and the current gold price.
     */
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

    /**
     * @notice Burns GoldToken to redeem ETH.
     * @dev 5% fee is deducted from the ETH returned, and 50% of that fee is forwarded to the lottery.
     * @param amount The amount of tokens to burn.
     */
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

    /**
     * @notice Fallback function to receive ETH.
     */
    receive() external payable {}

    /**
     * @dev Function required by UUPS upgradeability pattern.
     * It restricts upgrades to the contract owner.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
