// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@mocks/MockCCIPRouter.sol";
import "@mocks/MockWETH.sol";
import "@chainlink-ccip/src/v0.8/ccip/libraries/Client.sol";

/**
 * @title MockCCIPSimulator
 * @notice This contract simulates a CCIP message execution between source and destination chains.
 * @dev It uses mock CCIP routers and mock WETH contracts to simulate the bridging process.
 */
contract MockCCIPSimulator {

    /// @notice A test function (ignored by coverage).
    function testA() public {} // forge coverage ignore-file

    /// @notice The source chain CCIP router.
    MockCCIPRouter public routerSource;

    /// @notice The destination chain CCIP router.
    MockCCIPRouter public routerDestination;

    /// @notice The WETH contract on the source chain.
    MockWETH public wethSource;

    /// @notice The WETH contract on the destination chain.
    MockWETH public wethDestination;

    /**
     * @notice Emitted when a CCIP message simulation is executed.
     * @param receiver The receiver address on the destination chain.
     * @param amount The amount of tokens transferred.
     */
    event CCIPExecuted(address receiver, uint256 amount);

    /**
     * @notice Constructor.
     * @param _routerSource The source chain CCIP router.
     * @param _routerDestination The destination chain CCIP router.
     * @param _wethSource The WETH contract on the source chain.
     * @param _wethDestination The WETH contract on the destination chain.
     */
    constructor(
        MockCCIPRouter _routerSource,
        MockCCIPRouter _routerDestination,
        MockWETH _wethSource,
        MockWETH _wethDestination
    ) {
        routerSource = _routerSource;
        routerDestination = _routerDestination;
        wethSource = _wethSource;
        wethDestination = _wethDestination;
    }

    /**
     * @notice Simulates the execution of a CCIP message from a source chain to a destination chain.
     * @param sourceChain The ID of the source chain.
     * @param destinationChain The ID of the destination chain.
     * @param receiver The address of the receiver on the destination chain.
     * @param amount The amount of tokens to simulate transferring.
     */
    function simulateMessage(
        uint64 sourceChain,
        uint64 destinationChain,
        address receiver,
        uint256 amount
    ) external {
        require(
            routerDestination.getRemoteBridge(sourceChain) != address(0),
            "Destination bridge not set"
        );

        // Mint WETH on the destination chain.
        wethDestination.deposit{value: amount}();
        
        // Convert WETH to native ETH (simulate unwrapping) and send to the receiver.
        wethDestination.withdraw(amount);
        payable(receiver).transfer(amount);

        emit CCIPExecuted(receiver, amount);
    }

    /**
     * @notice Fallback function to accept ETH deposits.
     */
    receive() external payable {}
}
