// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@contracts/GoldToken.sol";
import "@mocks/MockGoldTokenV2.sol"; // New implementation (should include, for example, a version() function returning "v2")
import "@contracts/PriceConsumer.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev A simple contract that acts as a receiver to simulate a user capable of receiving ETH.
 */
contract Receiver {
    fallback() external payable {}
}

contract GoldTokenTest is Test {
    GoldToken public goldToken; // Instance via proxy
    address public owner;
    address public user;
    address public nonOwner;
    ERC1967Proxy public proxy;

    // Dummy initialization parameters
    address constant DUMMY_XAUUSD = address(0x100);
    address constant DUMMY_ETHUSD = address(0x200);
    uint64 constant DUMMY_SUBSCRIPTION_ID = 1234;

    function setUp() public {
        owner = address(this);
        nonOwner = address(0x123);

        // Deploy a Receiver to simulate a user that can receive ETH.
        Receiver receiver = new Receiver();
        user = address(receiver);

        // Encode the call to initialize()
        bytes memory data = abi.encodeWithSelector(
            GoldToken.initialize.selector,
            DUMMY_XAUUSD,
            DUMMY_ETHUSD,
            DUMMY_SUBSCRIPTION_ID
        );

        // Deploy the upgradeable proxy
        goldToken = new GoldToken();
        proxy = new ERC1967Proxy(address(goldToken), data);
        goldToken = GoldToken(payable(address(proxy)));

        // For test simplicity, force PriceConsumer.getGoldPrice() to return 1e18 (i.e. 1 ETH)
        vm.mockCall(
            address(goldToken.priceConsumer()),
            abi.encodeWithSelector(PriceConsumer.getGoldPrice.selector),
            abi.encode(uint256(1e18))
        );
    }

    /*//////////////////////////////////////////////////////////////
                              MINT TESTS
    //////////////////////////////////////////////////////////////*/

    function testMint() public {
        vm.startPrank(user);
        uint256 ethSent = 1 ether;
        // Calculation: 5% of 1 ether = 0.05 ether fee
        uint256 feeEth = (ethSent * 5) / 100;      // 0.05 ether
        uint256 ethAfterFee = ethSent - feeEth;      // 0.95 ether
        // With a goldPrice of 1e18, the number of minted tokens equals ethAfterFee (in 1e18 units)
        uint256 expectedTokens = ethAfterFee;

        uint256 lotteryBalanceBefore = address(goldToken.lottery()).balance;
        uint256 contractBalanceBefore = address(goldToken).balance;

        vm.deal(user, 10 ether);
        goldToken.mint{value: ethSent}();

        // Verify that the user received the correct amount of tokens.
        assertEq(
            goldToken.balanceOf(user),
            expectedTokens,
            "Incorrect token amount"
        );

        // The Lottery receives 50% of the fee (i.e. feeEth/2)
        uint256 lotteryFee = feeEth / 2;  // 0.025 ether
        uint256 lotteryBalanceAfter = address(goldToken.lottery()).balance;
        assertEq(
            lotteryBalanceAfter - lotteryBalanceBefore,
            lotteryFee,
            "Incorrect lottery fee"
        );

        // The contract retains the remaining ETH.
        uint256 expectedContractIncrease = ethSent - lotteryFee;
        uint256 contractBalanceAfter = address(goldToken).balance;
        assertEq(
            contractBalanceAfter - contractBalanceBefore,
            expectedContractIncrease,
            "Incorrect mint amount"
        );
        vm.stopPrank();
    }

    function testMintRevertIfNoEth() public {
        vm.startPrank(user);
        vm.expectRevert("Send ETH to mint tokens");
        goldToken.mint{value: 0}();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              BURN TESTS
    //////////////////////////////////////////////////////////////*/

    function testBurn() public {
        vm.startPrank(user);
        // First, mint tokens with 1 ether.
        uint256 ethSent = 1 ether;
        vm.deal(user, 10 ether);
        goldToken.mint{value: ethSent}();
        uint256 initialTokenBalance = goldToken.balanceOf(user);
        // We expect initialTokenBalance = 0.95 ether (in token units)

        // Calculations for burn (with goldPrice = 1e18):
        // ethToReturn = tokens burned, then a 5% fee is applied.
        uint256 tokensToBurn = initialTokenBalance;
        uint256 ethToReturn = tokensToBurn;
        uint256 feeEth = (ethToReturn * 5) / 100;    // 5% fee
        uint256 ethAfterFee = ethToReturn - feeEth;    // Net ETH for the user
        uint256 lotteryFee = feeEth / 2;               // 50% of the fee

        uint256 userEthBefore = user.balance;
        uint256 lotteryBalanceBefore = address(goldToken.lottery()).balance;

        goldToken.burn(tokensToBurn);

        // Verify that the tokens have been burned.
        assertEq(
            goldToken.balanceOf(user),
            0,
            "Tokens not burned"
        );

        // Verify that the user receives the correct amount of ETH.
        uint256 userEthAfter = user.balance;
        assertEq(
            userEthAfter - userEthBefore,
            ethAfterFee,
            "Incorrect ETH amount after burn"
        );

        // Verify that the lottery receives the correct fee.
        uint256 lotteryBalanceAfter = address(goldToken.lottery()).balance;
        assertEq(
            lotteryBalanceAfter - lotteryBalanceBefore,
            lotteryFee,
            "Incorrect lottery fee"
        );
        vm.stopPrank();
    }

    function testBurnRevertIfInsufficientBalance() public {
        vm.startPrank(user);
        vm.expectRevert("Insufficient balance");
        goldToken.burn(1e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              UPGRADE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_canUpgrade() public {
        GoldToken newImplementation = new GoldToken();

        vm.prank(owner);
        UUPSUpgradeable(address(goldToken)).upgradeToAndCall(address(newImplementation), "");
    }

    function test_cannotUpgradeUnauthorized() public {
        GoldToken newImplementation = new GoldToken();

        vm.prank(nonOwner);
        vm.expectRevert();
        UUPSUpgradeable(address(goldToken)).upgradeToAndCall(address(newImplementation), "");
    }
}
