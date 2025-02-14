// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@chainlink-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink-ccip/src/v0.8/ccip/interfaces/IWrappedNative.sol";
import "@chainlink-ccip/src/v0.8/ccip/libraries/Client.sol";

/**
 * @title MockCCIPRouter
 * @notice This contract simulates a CCIP router for testing purposes.
 * @dev It implements the IRouterClient interface by simulating CCIP message sending, a fixed fee, and support for all chains.
 */
contract MockCCIPRouter is IRouterClient {

    /// @notice A test function (ignored by coverage tools).
    function testA() public {} // forge coverage ignore-file

    /// @notice The address of the wrapped native token.
    address public wrappedNative;

    /// @notice Mapping that associates a chain ID with a remote bridge address.
    mapping(uint64 => address) public remoteBridges;

    /**
     * @notice Emitted when a CCIP message is sent.
     * @param destinationChain The destination chain ID.
     * @param receiver The receiver address on the remote chain.
     * @param amount The amount of tokens transferred.
     */
    event MessageSent(uint64 destinationChain, address receiver, uint256 amount);

    /**
     * @notice Constructor that initializes the wrapped native token address.
     * @param _wrappedNative The address of the wrapped native token.
     */
    constructor(address _wrappedNative) {
        wrappedNative = _wrappedNative;
    }

    /**
     * @notice Returns the address of the wrapped native token.
     * @return The address of the wrapped native token.
     */
    function getWrappedNative() external view returns (address) {
        return wrappedNative;
    }

    /**
     * @notice Sets the remote bridge address for a given chain.
     * @param chainId The chain ID.
     * @param bridge The remote bridge address.
     */
    function setRemoteBridge(uint64 chainId, address bridge) external {
        remoteBridges[chainId] = bridge;
    }

    /**
     * @notice Returns the remote bridge address for a given chain.
     * @param chainId The chain ID.
     * @return The remote bridge address associated with the given chain ID.
     */
    function getRemoteBridge(uint64 chainId) external view returns (address) {
        return remoteBridges[chainId];
    }

    /**
     * @notice Returns the fee for sending a CCIP message.
     * @param _ignored This parameter is ignored.
     * @param _message The CCIP message (not used here).
     * @return A fixed fee of 0.01 ether.
     */
    function getFee(uint64, Client.EVM2AnyMessage calldata _message) external pure override returns (uint256) {
        return 0.01 ether; // Simulate a fixed fee
    }

    /**
     * @notice Simulates sending a CCIP message to a destination chain.
     * @param destinationChain The destination chain ID.
     * @param message The CCIP message to send.
     * @return A simulated CCIP message ID.
     */
    function ccipSend(uint64 destinationChain, Client.EVM2AnyMessage calldata message) external payable override returns (bytes32) {
        emit MessageSent(destinationChain, abi.decode(message.receiver, (address)), message.tokenAmounts[0].amount);
        return bytes32(uint256(1)); // Simulate a CCIP message ID
    }

    /**
     * @notice Indicates whether a destination chain is supported.
     * @param destChainSelector The destination chain ID.
     * @return True, as all chains are simulated as supported.
     */
    function isChainSupported(uint64 destChainSelector) external pure override returns (bool) {
        return true; // Simulate support for all chains
    }
}
