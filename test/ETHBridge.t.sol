// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "@contracts/ETHBridge.sol";
import "@mocks/MockCCIPRouter.sol";
import "@mocks/MockWETH.sol";
import "@mocks/MockCCIPSimulator.sol";
import "@mocks/MockETHBridge.sol";

contract ETHBridgeTest is Test {
    MockCCIPRouter private routerSource;
    MockCCIPRouter private routerDestination;
    MockWETH private wethSource;
    MockWETH private wethDestination;
    ETHBridge private bridgeSource;
    MockETHBridge private bridgeDestination;
    MockCCIPSimulator private simulator;

    address private user = address(0x123);
    address private recipient = address(0x456);
    uint64 private constant CHAIN_SOURCE = 1;
    uint64 private constant CHAIN_DESTINATION = 2;

    event EthSent(address indexed sender, address indexed receiver, uint256 amount, uint64 destinationChain);
    event ExcessRefunded(address indexed refundReceiver, uint256 excessAmount);

    function setUp() public {
        // Déployer les mocks
        wethSource = new MockWETH();
        wethDestination = new MockWETH();
        routerSource = new MockCCIPRouter(address(wethSource));
        routerDestination = new MockCCIPRouter(address(wethDestination));

        bridgeSource = new ETHBridge(address(routerSource), CHAIN_DESTINATION);
        bridgeDestination = new MockETHBridge(address(routerDestination), CHAIN_SOURCE);

        simulator = new MockCCIPSimulator(routerSource, routerDestination, wethSource, wethDestination);

        // Enregistrer les bridges
        routerSource.setRemoteBridge(CHAIN_DESTINATION, address(bridgeDestination));
        routerDestination.setRemoteBridge(CHAIN_SOURCE, address(bridgeSource));

        // Déposer 100 ETH à l'utilisateur
        vm.deal(user, 100 ether);
        vm.deal(address(routerSource), 100 ether);
        vm.deal(address(simulator), 100 ether);
    }

    function test_SendETH_Success() public {
        uint256 amount = 1 ether;
        uint256 estimatedFee = bridgeSource.getFee(recipient, amount);

        vm.startPrank(user);
        vm.expectEmit(true, true, false, true);
        emit EthSent(user, recipient, amount, CHAIN_DESTINATION);

        bridgeSource.send{value: amount + estimatedFee}(recipient, amount);

        assertEq(wethSource.balanceOf(address(bridgeSource)), amount);

        simulator.simulateMessage(CHAIN_SOURCE, CHAIN_DESTINATION, recipient, amount);

        assertEq(address(recipient).balance, amount);
    }

    function test_SendETH_RefundExcess() public {
        uint256 amount = 1 ether;
        uint256 estimatedFee = bridgeSource.getFee(recipient, amount);
        uint256 extraSent = 0.5 ether;

        vm.startPrank(user);
        vm.expectEmit(true, true, false, true);
        emit ExcessRefunded(user, extraSent);

        bridgeSource.send{value: amount + estimatedFee + extraSent}(recipient, amount);

        assertEq(user.balance, 100 ether - (amount + estimatedFee));
    }

    function test_Fail_NotEnoughETH() public {
        uint256 amount = 1 ether;
        uint256 estimatedFee = bridgeSource.getFee(recipient, amount);

        vm.startPrank(user);
        vm.expectRevert("Not enough ETH sent");

        bridgeSource.send{value: amount + estimatedFee - 0.1 ether}(recipient, amount);
    }

    function test_Fail_InvalidAddress() public {
        uint256 amount = 1 ether;
        uint256 estimatedFee = bridgeSource.getFee(recipient, amount);

        vm.startPrank(user);
        vm.expectRevert("Invalid receiver address");

        bridgeSource.send{value: amount + estimatedFee}(address(0), amount);
    }

    function test_Fail_InvalidAmount() public {
        uint256 amount = 1 ether;
        uint256 estimatedFee = bridgeSource.getFee(recipient, amount);

        vm.startPrank(user);
        vm.expectRevert("Amount must be greater than zero");

        bridgeSource.send{value: amount + estimatedFee}(recipient, 0);
    }

    function test_Fail_InvalidValue() public {
        uint256 amount = 1 ether;

        vm.startPrank(user);
        vm.expectRevert("Insufficient ETH for transfer and fees");

        bridgeSource.send{value: amount}(recipient, amount);
    }

    function test_Fail_Refound() public {
        uint256 amount = 1 ether;
        uint256 estimatedFee = bridgeSource.getFee(recipient, 0);

        vm.startPrank(address(routerSource));
        vm.expectRevert("Refund failed"); // Contract with no receive

        bridgeSource.send{value: amount + estimatedFee * 2}(recipient, amount);
    }

    function test_ReceiveETH_Success() public {
        uint256 amount = 1 ether;

        wethDestination.deposit{value: amount}();
        wethDestination.transfer(address(bridgeDestination), amount);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(wethDestination),
            amount: amount
        });
        tokenAmounts[0] = tokenAmount;
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: 0,
            sourceChainSelector: CHAIN_SOURCE,
            sender: abi.encode(address(bridgeSource)),
            data: abi.encode(recipient),
            destTokenAmounts: tokenAmounts
        });

        vm.prank(address(routerDestination));
        bridgeDestination.test_ccipReceive(message);

        assertEq(address(recipient).balance, amount);
    }

    function test_Fail_ReceiveETH_InvalidTokenAmounts() public {
        uint256 amount = 1 ether;

        wethDestination.deposit{value: amount}();
        wethDestination.transfer(address(bridgeDestination), amount);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](2);
        Client.EVMTokenAmount memory tokenAmount1 = Client.EVMTokenAmount({
            token: address(wethDestination),
            amount: amount
        });
        Client.EVMTokenAmount memory tokenAmount2 = Client.EVMTokenAmount({
            token: address(wethDestination),
            amount: amount
        });
        tokenAmounts[0] = tokenAmount1;
        tokenAmounts[1] = tokenAmount2;
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: 0,
            sourceChainSelector: CHAIN_SOURCE,
            sender: abi.encode(address(bridgeSource)),
            data: abi.encode(recipient),
            destTokenAmounts: tokenAmounts
        });
        
        vm.prank(address(routerDestination));
        bytes4 selector = ETHBridge.InvalidTokenAmounts.selector;
        vm.expectRevert(abi.encodeWithSelector(selector, 2));
        bridgeDestination.test_ccipReceive(message);
    }

    function test_Fail_ReceiveETH_InvalidTokenAddress() public {
        uint256 amount = 1 ether;

        wethDestination.deposit{value: amount}();
        wethDestination.transfer(address(bridgeDestination), amount);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(0),
            amount: amount
        });
        tokenAmounts[0] = tokenAmount;
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: 0,
            sourceChainSelector: CHAIN_SOURCE,
            sender: abi.encode(address(bridgeSource)),
            data: abi.encode(recipient),
            destTokenAmounts: tokenAmounts
        });
        
        vm.prank(address(routerDestination));
        bytes4 selector = ETHBridge.InvalidToken.selector;
        vm.expectRevert(abi.encodeWithSelector(selector, address(0), address(wethDestination)));
        bridgeDestination.test_ccipReceive(message);
    }

    function test_ReceiveETH_FallbackToWETH() public {
        uint256 amount = 1 ether;

        wethDestination.deposit{value: amount}();
        wethDestination.transfer(address(bridgeDestination), amount);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(wethDestination),
            amount: amount
        });
        tokenAmounts[0] = tokenAmount;
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: 0,
            sourceChainSelector: CHAIN_SOURCE,
            sender: abi.encode(address(bridgeSource)),
            data: abi.encode(address(routerSource)), // ✅ Receiver is a contract that has no receive function
            destTokenAmounts: tokenAmounts
        });

        vm.prank(address(routerDestination));
        bridgeDestination.test_ccipReceive(message);

        assertEq(wethDestination.balanceOf(address(routerSource)), amount, "WETH fallback failed");
    }

}
