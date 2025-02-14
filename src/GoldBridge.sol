// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*//////////////////////////////////////////////////////////////
//                           IMPORTS
//////////////////////////////////////////////////////////////*/

import {CCIPReceiver} from "@chainlink-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {GoldToken} from "@contracts/GoldToken.sol";

/*//////////////////////////////////////////////////////////////
//                         GOLD BRIDGE
//////////////////////////////////////////////////////////////*/
/// @title GoldBridge
/// @notice A CCIP bridge contract for transferring GoldToken between Sepolia and BSC.
/// @dev On the source chain, users call sendGold() to lock their GoldToken and send a CCIP message;
///      on the destination chain, the CCIP message triggers _ccipReceive() which transfers tokens from the bridge to the recipient.
contract GoldBridge is CCIPReceiver {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The GoldToken contract whose tokens are bridged.
    GoldToken public goldToken;

    /// @notice The destination chain ID.
    uint64 public destinationChainId;

    /*//////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when tokens are sent cross-chain.
    /// @param sender The address that initiated the transfer.
    /// @param receiver The recipient address on the destination chain.
    /// @param amount The amount of GoldToken transferred.
    /// @param destinationChain The destination chain ID.
    event GoldSent(address indexed sender, address indexed receiver, uint256 amount, uint64 destinationChain);

    /// @notice Emitted when tokens are received via CCIP.
    /// @param receiver The address receiving tokens on this chain.
    /// @param amount The amount of GoldToken received.
    event GoldReceived(address indexed receiver, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructs the GoldBridge contract.
    /// @param _router The CCIP router address.
    /// @param _destinationChainId The destination chain ID (e.g. BSC chain id).
    /// @param _goldToken Address of the deployed GoldToken contract on this chain.
    constructor(
        address _router,
        uint64 _destinationChainId,
        address payable _goldToken
    ) CCIPReceiver(_router) {
        destinationChainId = _destinationChainId;
        goldToken = GoldToken(_goldToken);
    }

    /*//////////////////////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sends GoldToken cross-chain.
    /// @dev The sender must have approved the bridge contract to spend at least `_amount` tokens.
    ///      The function transfers the tokens from the sender to the bridge (locking them) and sends a CCIP message.
    /// @param _receiver The recipient address on the destination chain.
    /// @param _amount The amount of GoldToken to send.
    /// @return txId The transaction ID returned by the CCIP router.
    function sendGold(address _receiver, uint256 _amount) external payable returns (bytes32 txId) {
        require(_receiver != address(0), "Invalid receiver address");
        require(_amount > 0, "Amount must be > 0");

        // Transfer tokens from sender to bridge (lock tokens)
        goldToken.transferFrom(msg.sender, address(this), _amount);

        // Build the CCIP message
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(goldToken),
            amount: _amount
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
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

        // Send the CCIP message, forwarding any ETH sent to cover fees.
        txId = IRouterClient(getRouter()).ccipSend{value: msg.value}(destinationChainId, message);

        emit GoldSent(msg.sender, _receiver, _amount, destinationChainId);
    }

    /// @notice Returns the estimated fee for sending GoldToken cross-chain.
    /// @param _receiver The recipient address on the destination chain.
    /// @param _amount The amount of GoldToken to send.
    /// @return fee The estimated fee in ETH.
    function getFee(address _receiver, uint256 _amount) public view returns (uint256 fee) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(goldToken),
            amount: _amount
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
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
        return IRouterClient(getRouter()).getFee(destinationChainId, message);
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Handles received CCIP messages.
    /// @dev Decodes the message data to retrieve the recipient address and unlocks the corresponding amount of GoldToken.
    /// @param message The CCIP message containing transfer details.
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // Decode receiver from the message data.
        address receiver = abi.decode(message.data, (address));

        // The message should include exactly one token amount.
        require(message.destTokenAmounts.length == 1, "Invalid token amounts");
        Client.EVMTokenAmount memory tokenInfo = message.destTokenAmounts[0];
        require(tokenInfo.token == address(goldToken), "Unexpected token");

        uint256 amount = tokenInfo.amount;

        // Transfer (unlock) the tokens from the bridge contract to the receiver.
        goldToken.transfer(receiver, amount);

        emit GoldReceived(receiver, amount);
    }
}