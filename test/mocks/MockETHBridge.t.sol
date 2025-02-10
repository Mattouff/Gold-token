// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@contracts/ETHBridge.sol";

/// @title MockETHBridge - A mock contract to expose _ccipReceive for testing.
/// @dev This contract allows test cases to simulate incoming CCIP messages.
contract MockETHBridge is ETHBridge {
    constructor(address router, uint64 _destChain) ETHBridge(router, _destChain) {}

    /// @notice Public function to test `_ccipReceive()`.
    /// @dev This is only for testing purposes.
    /// @param message The incoming CCIP message.
    function test_ccipReceive(Client.Any2EVMMessage memory message) public {
        _ccipReceive(message);
    }
}
