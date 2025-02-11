// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@mocks/MockCCIPRouter.sol";
import "@mocks/MockWETH.sol";
import "@chainlink-ccip/src/v0.8/ccip/libraries/Client.sol";

contract MockCCIPSimulator {

    function testA() public {} // forge coverage ignore-file

    MockCCIPRouter public routerSource;
    MockCCIPRouter public routerDestination;
    MockWETH public wethSource;
    MockWETH public wethDestination;

    event CCIPExecuted(address receiver, uint256 amount);

    constructor(MockCCIPRouter _routerSource, MockCCIPRouter _routerDestination, MockWETH _wethSource, MockWETH _wethDestination) {
        routerSource = _routerSource;
        routerDestination = _routerDestination;
        wethSource = _wethSource;
        wethDestination = _wethDestination;
    }

    function simulateMessage(uint64 sourceChain, uint64 destinationChain, address receiver, uint256 amount) external {
        require(routerDestination.getRemoteBridge(sourceChain) != address(0), "Destination bridge not set");

        // Mint du WETH
        wethDestination.deposit{value: amount}();
        
        // Convertir WETH en ETH et envoyer au destinataire
        wethDestination.withdraw(amount);
        payable(receiver).transfer(amount);

        emit CCIPExecuted(receiver, amount);
    }

    receive() external payable {}
}
