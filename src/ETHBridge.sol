// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IWrappedNative} from "@chainlink-ccip/src/v0.8/ccip/interfaces/IWrappedNative.sol";

import {Client} from "@chainlink-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

import {IERC20} from "@chainlink-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ETHBridge
/// @notice A contract for bridging ETH using Chainlink CCIP.
/// @dev Uses Chainlink's CCIP to facilitate cross-chain ETH transfers.
interface CCIPRouter {
  function getWrappedNative() external view returns (address);
}

contract ETHBridge is CCIPReceiver {
    using SafeERC20 for IERC20;

/*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
//////////////////////////////////////////////////////////////*/

    /// @notice The wrapped native token (WETH) used for bridging.
    IWrappedNative public immutable i_weth;
    
    /// @notice The destination chain ID.
    uint64 private immutable DEST_CHAIN_ID;

/*//////////////////////////////////////////////////////////////
                           EVENTS
//////////////////////////////////////////////////////////////*/

    /// @notice Emitted when ETH is sent across chains.
    /// @param sender The address sending ETH.
    /// @param receiver The address receiving ETH on the destination chain.
    /// @param amount The amount of ETH sent.
    /// @param destinationChain The destination chain ID.
    event EthSent(address indexed sender, address indexed receiver, uint256 amount, uint64 destinationChain);
    
    /// @notice Emitted when excess ETH is refunded.
    /// @param refundReceiver The address receiving the refund.
    /// @param excessAmount The amount refunded.
    event ExcessRefunded(address indexed refundReceiver, uint256 excessAmount);

/*//////////////////////////////////////////////////////////////
                        CUSTOM ERRORS
//////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when the received token amount is invalid.
    error InvalidTokenAmounts(uint256 gotAmounts);
    
    /// @notice Error thrown when an unexpected token is received.
    error InvalidToken(address gotToken, address expectedToken);
    
    /// @notice Error thrown when token amount does not match the message value.
    error TokenAmountNotEqualToMsgValue(uint256 gotAmount, uint256 msgValue);

/*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
//////////////////////////////////////////////////////////////*/

    /// @param router The Chainlink CCIP router address.
    /// @param _dest_chain The destination chain ID.
    constructor(address router, uint64 _dest_chain) CCIPReceiver(router) {
        i_weth = IWrappedNative(CCIPRouter(router).getWrappedNative());
        i_weth.approve(router, type(uint256).max);
        DEST_CHAIN_ID = _dest_chain;
    }

    /// @notice Fallback function to accept ETH deposits.
    receive() external payable {}

/*//////////////////////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
//////////////////////////////////////////////////////////////*/

    /// @notice Sends ETH to another chain using CCIP.
    /// @param _receiver The recipient address on the destination chain.
    /// @param _amount The amount of ETH to send.
    function send(address _receiver, uint256 _amount) external payable {
        require(_receiver != address(0), "Invalid receiver address");
        require(_amount > 0, "Amount must be greater than zero");
        require(msg.value >= _amount, "Not enough ETH sent");

        uint256 estimatedFee = getFee(_receiver, _amount);
        uint256 totalRequired = _amount + estimatedFee;

        require(msg.value >= totalRequired, "Insufficient ETH for transfer and fees");

        Client.EVM2AnyMessage memory message = _buildCCIPMessage(_receiver, _amount);
        _ccipSend(message, estimatedFee);

        emit EthSent(msg.sender, _receiver, _amount, DEST_CHAIN_ID);

        uint256 excess = msg.value - totalRequired;
        if (excess > 0) {
            (bool refunded, ) = msg.sender.call{value: excess}("");
            require(refunded, "Refund failed");
            emit ExcessRefunded(msg.sender, excess);
        }
    }

/*//////////////////////////////////////////////////////////////
                    PUBLIC FUNCTIONS
//////////////////////////////////////////////////////////////*/

    /// @notice Gets the estimated fee for sending ETH to another chain.
    /// @param _receiver The recipient address on the destination chain.
    /// @param _amount The amount of ETH to send.
    /// @return fee The estimated fee in ETH.
    function getFee(
        address _receiver,
        uint256 _amount
    ) public view returns (uint256 fee) {
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(_receiver, _amount);
        return IRouterClient(getRouter()).getFee(DEST_CHAIN_ID, message);
    }

/*//////////////////////////////////////////////////////////////
                    INTERNAL FUNCTIONS
//////////////////////////////////////////////////////////////*/

    /// @notice Handles received CCIP messages.
    /// @param message The received message containing ETH transfer details.
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        address receiver = abi.decode(message.data, (address));

        if (message.destTokenAmounts.length != 1) {
            revert InvalidTokenAmounts(message.destTokenAmounts.length);
        }

        if (message.destTokenAmounts[0].token != address(i_weth)) {
            revert InvalidToken(message.destTokenAmounts[0].token, address(i_weth));
        }

        uint256 tokenAmount = message.destTokenAmounts[0].amount;
        i_weth.withdraw(tokenAmount);

        (bool success,) = payable(receiver).call{value: tokenAmount}("");
        if (!success) {
            i_weth.deposit{value: tokenAmount}();
            i_weth.transfer(receiver, tokenAmount);
        }
    }

/*//////////////////////////////////////////////////////////////
                    PRIVATE FUNCTIONS
//////////////////////////////////////////////////////////////*/

    /// @notice Builds a CCIP message for cross-chain ETH transfer.
    /// @param _receiver The recipient address on the destination chain.
    /// @param _amount The amount of ETH to send.
    /// @return The constructed CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        uint256 _amount
    ) private view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(i_weth),
            amount: _amount
        });
        tokenAmounts[0] = tokenAmount;

        return Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV2({
                    gasLimit: 400_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });
    }

    /// @notice Sends a CCIP message for cross-chain ETH transfer.
    /// @param message The CCIP message to send.
    /// @param fees The transaction fees in ETH.
    /// @return The transaction ID.
    function _ccipSend(
        Client.EVM2AnyMessage memory message,
        uint256 fees
    ) private returns (bytes32) {
        i_weth.deposit{value: message.tokenAmounts[0].amount}();
        return IRouterClient(getRouter()).ccipSend{value: fees}(DEST_CHAIN_ID, message);
    }
}