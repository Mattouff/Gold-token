// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@contracts/GoldBridge.sol";

/// @title MockGoldBridge - A mock contract to expose _ccipReceive for testing.
/// @dev This contract allows test cases to simulate incoming CCIP messages.
contract MockGoldBridge is GoldBridge {
    constructor(address router, uint64 destinationChainId, address _goldToken)
        GoldBridge(router, destinationChainId, _goldToken)
    {}

    /// @notice Exposes the internal _ccipReceive() for testing purposes.
    /// @param message The CCIP message.
    function exposeCcipReceive(Client.Any2EVMMessage memory message) external {
        _ccipReceive(message);
    }
}