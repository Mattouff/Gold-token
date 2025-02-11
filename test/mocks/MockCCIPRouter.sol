// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@chainlink-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink-ccip/src/v0.8/ccip/interfaces/IWrappedNative.sol";
import "@chainlink-ccip/src/v0.8/ccip/libraries/Client.sol";
contract MockCCIPRouter is IRouterClient {

    function testA() public {} // forge coverage ignore-file

    address public wrappedNative;
    mapping(uint64 => address) public remoteBridges;

    event MessageSent(uint64 destinationChain, address receiver, uint256 amount);

    constructor(address _wrappedNative) {
        wrappedNative = _wrappedNative;
    }

    function getWrappedNative() external view returns (address) {
        return wrappedNative;
    }

    function setRemoteBridge(uint64 chainId, address bridge) external {
        remoteBridges[chainId] = bridge;
    }

    function getRemoteBridge(uint64 chainId) external view returns (address) {
        return remoteBridges[chainId];
    }

    function getFee(uint64, Client.EVM2AnyMessage calldata) external pure override returns (uint256) {
        return 0.01 ether; // Simule un coût fixe
    }

    function ccipSend(uint64 destinationChain, Client.EVM2AnyMessage calldata message) external payable override returns (bytes32) {
        emit MessageSent(destinationChain, abi.decode(message.receiver, (address)), message.tokenAmounts[0].amount);
        return bytes32(uint256(1)); // Simule un message CCIP
    }

    function isChainSupported(uint64 destChainSelector) external pure override returns (bool) {
        return true; // Simule que toutes les chaînes sont supportées
    }
}
