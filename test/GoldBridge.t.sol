// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "@contracts/GoldBridge.sol";
import "@contracts/GoldToken.sol";
import "@contracts/PriceConsumer.sol";
import "@mocks/MockGoldBridge.sol";
import {Client} from "@chainlink-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title GoldBridgeTest
 * @notice This contract contains tests for the GoldBridge functionality.
 * @dev It uses Forge-std's Test framework to simulate minting, transferring, and receiving of GoldToken via the CCIP bridge.
 */
contract GoldBridgeTest is Test {
    using SafeERC20 for IERC20;

    /// @notice Instance of the mock GoldBridge.
    MockGoldBridge public bridge;

    /// @notice Instance of the GoldToken contract.
    GoldToken public goldToken;

    /// @notice Test user address.
    address public user;

    /// @notice Test destination user address.
    address public userDest;
    
    /// @notice Dummy router address for CCIP.
    address public dummyRouter = address(0x500);

    /// @notice Example destination chain ID (e.g., for BSC Testnet = 97) and source chain ID = 98.
    uint64 public destinationChainId = 97;
    uint64 public sourceChainId = 98;
    
    /// @notice Dummy parameters for initializing GoldToken (PriceConsumer and Lottery).
    address constant DUMMY_XAUUSD = address(0x100);
    address constant DUMMY_ETHUSD = address(0x200);
    uint64 constant DUMMY_SUBSCRIPTION_ID = 1111;

    /**
     * @notice Sets up the test environment.
     * @dev Deploys GoldToken and initializes it, mocks the price feed, and deploys the MockGoldBridge.
     */
    function setUp() public {
        user = address(0x123);
        userDest = address(0x456);
        
        // Deploy GoldToken with dummy aggregator addresses and subscription ID.
        goldToken = new GoldToken();
        goldToken.initialize(
            DUMMY_XAUUSD,
            DUMMY_ETHUSD,
            DUMMY_SUBSCRIPTION_ID
        );
        // Force PriceConsumer.getGoldPrice() to return 1e18 for simplified calculations.
        vm.mockCall(
            address(goldToken.priceConsumer()),
            abi.encodeWithSelector(PriceConsumer.getGoldPrice.selector),
            abi.encode(1e18)
        );
        
        // Deploy MockGoldBridge with dummyRouter, destinationChainId, and the address of GoldToken.
        bridge = new MockGoldBridge(dummyRouter, destinationChainId, payable(address(goldToken)));
    }
    
    /**
     * @notice Tests the sendGold() function of the bridge.
     * @dev Mints tokens, approves the bridge, mocks the router response for ccipSend, and verifies the correct transfer.
     */
    function testSendGold() public {
        vm.startPrank(user);
        vm.deal(user, 10 ether);
        
        // Mint tokens via GoldToken.mint(). With a mocked PriceConsumer.getGoldPrice() of 1e18,
        // sending 1 ether results in 0.95 tokens (after a 5% fee).
        goldToken.mint{value: 1 ether}();
        uint256 userTokenBalance = goldToken.balanceOf(user);
        
        // Approve the bridge to spend the user's tokens.
        goldToken.approve(address(bridge), userTokenBalance);
        
        address recipient = userDest;
        
        // Rebuild the expected CCIP message before calling sendGold(), to simulate the mock response for ccipSend.
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(goldToken),
            amount: userTokenBalance
        });
        Client.EVM2AnyMessage memory expectedMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(recipient),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV2({ gasLimit: 400_000, allowOutOfOrderExecution: true })
            ),
            feeToken: address(0)
        });
        
        // Simulate the router response for ccipSend by forcing the return of a dummy txId.
        vm.mockCall(
            dummyRouter,
            abi.encodeWithSelector(IRouterClient.ccipSend.selector, destinationChainId, expectedMessage),
            abi.encode(bytes32("dummyTxId"))
        );
        
        // Call sendGold() to transfer all user tokens via the bridge.
        bytes32 txId = bridge.sendGold(recipient, userTokenBalance);
        
        // Verify that the returned txId matches the dummy txId.
        assertEq(txId, bytes32("dummyTxId"), "Incorrect CCIP txId");
        // Verify that the tokens have been locked in the bridge.
        assertEq(goldToken.balanceOf(address(bridge)), userTokenBalance, "Tokens not locked in bridge");
        vm.stopPrank();
    }

    /**
     * @notice Tests that sendGold() fails when the receiver address is invalid (zero address).
     */
    function test_fail_send_address() public {
        vm.startPrank(user);
        vm.deal(user, 10 ether);
        
        goldToken.mint{value: 1 ether}();
        uint256 userTokenBalance = goldToken.balanceOf(user);

        vm.expectRevert("Invalid receiver address");
        bridge.sendGold(address(0), userTokenBalance);
    }

    /**
     * @notice Tests that sendGold() fails when the amount is zero.
     */
    function test_fail_send_0() public {
        vm.startPrank(user);
        vm.expectRevert("Amount must be > 0");
        bridge.sendGold(userDest, 0);
    }
    
    /**
     * @notice Tests the getFee() function of the GoldBridge.
     * @dev Mocks the router's fee response and verifies that the fee estimation is correct.
     */
    function testGetFee() public {
        // Simulate the router's fee response.
        uint256 dummyFee = 0.01 ether;
        
        // Construct the CCIP message as used in getFee().
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(goldToken),
            amount: 1000
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(userDest),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV2({ gasLimit: 400_000, allowOutOfOrderExecution: true })
            ),
            feeToken: address(0)
        });
        
        vm.mockCall(
            dummyRouter,
            abi.encodeWithSelector(IRouterClient.getFee.selector, destinationChainId, message),
            abi.encode(dummyFee)
        );
        
        uint256 fee = bridge.getFee(userDest, 1000);
        assertEq(fee, dummyFee, "Fee estimation is incorrect");
    }
    
    /**
     * @notice Tests the reception of GoldToken via CCIP.
     * @dev Simulates transferring tokens to the bridge and then calls exposeCcipReceive to simulate receiving the CCIP message.
     */
    function testReceiveGold() public {
        // For this test, transfer tokens to the bridge to simulate locked tokens.
        // Mint tokens for the user and transfer them to the bridge.
        vm.startPrank(user);
        vm.deal(user, 10 ether);
        goldToken.mint{value: 1 ether}();
        uint256 userTokenBalance = goldToken.balanceOf(user);
        // For testing, transfer the entire user balance to the bridge.
        goldToken.transfer(address(bridge), userTokenBalance);
        vm.stopPrank();
        
        // Construct a simulated CCIP message: the message contains the recipient in data and the amount in destTokenAmounts.
        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: address(goldToken),
            amount: userTokenBalance
        });
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: 0,
            sourceChainSelector: sourceChainId,
            sender: abi.encode(user),
            data: abi.encode(userDest), // recipient on this chain
            destTokenAmounts: destTokenAmounts
        });
        
        uint256 userBalanceBefore = goldToken.balanceOf(userDest);
        
        // Call the exposed function to simulate receiving the CCIP message.
        vm.prank(dummyRouter); // _ccipReceive verifies that msg.sender == getRouter()
        bridge.exposeCcipReceive(message);
        
        uint256 userBalanceAfter = goldToken.balanceOf(userDest);
        assertEq(userBalanceAfter - userBalanceBefore, userTokenBalance, "Tokens not correctly transferred on receive");
    }

    /**
     * @notice Tests that receive fails when the token amounts array has an invalid length.
     * @dev Constructs a CCIP message with two token amounts and expects a revert with "Invalid token amounts".
     */
    function test_fail_receive_invalidAmount() public {
        // For this test, transfer tokens to the bridge to simulate locked tokens.
        vm.startPrank(user);
        vm.deal(user, 10 ether);
        goldToken.mint{value: 1 ether}();
        uint256 userTokenBalance = goldToken.balanceOf(user);
        // For testing, transfer the entire user balance to the bridge.
        goldToken.transfer(address(bridge), userTokenBalance);
        vm.stopPrank();
        
        // Construct a simulated CCIP message with an invalid token amounts array (length != 1).
        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](2);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: address(goldToken),
            amount: userTokenBalance
        });
        destTokenAmounts[1] = Client.EVMTokenAmount({
            token: address(goldToken),
            amount: userTokenBalance
        });
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: 0,
            sourceChainSelector: sourceChainId,
            sender: abi.encode(user),
            data: abi.encode(userDest), // recipient on this chain
            destTokenAmounts: destTokenAmounts
        });
        
        // Call the exposed function to simulate receiving the message and expect a revert.
        vm.prank(dummyRouter); // _ccipReceive verifies that msg.sender == getRouter()
        vm.expectRevert("Invalid token amounts");
        bridge.exposeCcipReceive(message);
    }

    /**
     * @notice Tests that receive fails when an unexpected token is provided.
     * @dev Constructs a CCIP message with an unexpected token (address(0)) and expects a revert with "Unexpected token".
     */
    function test_fail_receive_invalidToken() public {
        // For this test, transfer tokens to the bridge to simulate locked tokens.
        vm.startPrank(user);
        vm.deal(user, 10 ether);
        goldToken.mint{value: 1 ether}();
        uint256 userTokenBalance = goldToken.balanceOf(user);
        // For testing, transfer the entire user balance to the bridge.
        goldToken.transfer(address(bridge), userTokenBalance);
        vm.stopPrank();
        
        // Construct a simulated CCIP message with an unexpected token (address(0)).
        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: address(0),
            amount: userTokenBalance
        });
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: 0,
            sourceChainSelector: sourceChainId,
            sender: abi.encode(user),
            data: abi.encode(userDest), // recipient on this chain
            destTokenAmounts: destTokenAmounts
        });
        
        // Call the exposed function to simulate receiving the message and expect a revert.
        vm.prank(dummyRouter); // _ccipReceive verifies that msg.sender == getRouter()
        vm.expectRevert("Unexpected token");
        bridge.exposeCcipReceive(message);
    }
}