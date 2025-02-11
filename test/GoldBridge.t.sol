// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@contracts/GoldBridge.sol";
import "@contracts/GoldToken.sol";
import "@contracts/PriceConsumer.sol";
import "@mocks/MockGoldBridge.sol";
import {Client} from "@chainlink-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract GoldBridgeTest is Test {
    using SafeERC20 for IERC20;

    MockGoldBridge public bridge;
    GoldToken public goldToken;
    address public user;
    address public userDest;
    
    // Adresse fictive pour le routeur CCIP
    address public dummyRouter = address(0x500);
    // Exemple : destinationChainId pour BSC Testnet = 97, sourceChainId = 98
    uint64 public destinationChainId = 97;
    uint64 public sourceChainId = 98;
    
    // Paramètres pour GoldToken (PriceConsumer et Lottery)
    address public dummyXAUUSD = address(0x100);
    address public dummyETHUSD = address(0x200);
    address public dummyVRFCoordinator = address(0x300);
    address public dummyLinkToken = address(0x400);
    bytes32 public dummyKeyHash = bytes32("dummyKeyHash");
    uint256 public dummyVrfFee = 0;
    
    function setUp() public {
        user = address(0x123);
        userDest = address(0x456);
        
        // Déployer GoldToken avec les adresses pour les agrégateurs et la loterie.
        goldToken = new GoldToken(
            dummyXAUUSD,
            dummyETHUSD,
            dummyVRFCoordinator,
            dummyLinkToken,
            dummyKeyHash,
            dummyVrfFee
        );
        // Forcer PriceConsumer.getGoldPrice() à retourner 1e18 pour simplifier les calculs.
        vm.mockCall(
            address(goldToken.priceConsumer()),
            abi.encodeWithSelector(PriceConsumer.getGoldPrice.selector),
            abi.encode(1e18)
        );
        
        // Déployer MockGoldBridge avec dummyRouter, destinationChainId et l'adresse de GoldToken.
        bridge = new MockGoldBridge(dummyRouter, destinationChainId, address(goldToken));
    }
    
    /// @notice Teste la fonction sendGold().
    function testSendGold() public {
        vm.startPrank(user);
        vm.deal(user, 10 ether);
        
        // Mint des tokens via GoldToken.mint().
        // Avec PriceConsumer.getGoldPrice() = 1e18, l'envoi de 1 ether donne 0.95 tokens (1 ether - 5% de frais).
        goldToken.mint{value: 1 ether}();
        uint256 userTokenBalance = goldToken.balanceOf(user);
        
        // Approver le bridge pour dépenser les tokens de l'utilisateur.
        goldToken.approve(address(bridge), userTokenBalance);
        
        address recipient = userDest;
        
        // Avant d'appeler sendGold(), reconstruire le message attendu pour simuler le mock de ccipSend.
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
        
        // Simuler la réponse du routeur pour ccipSend en forçant le retour d'un identifiant fictif.
        vm.mockCall(
            dummyRouter,
            abi.encodeWithSelector(IRouterClient.ccipSend.selector, destinationChainId, expectedMessage),
            abi.encode(bytes32("dummyTxId"))
        );
        
        // Appeler sendGold() pour transférer tous les tokens de l'utilisateur.
        bytes32 txId = bridge.sendGold(recipient, userTokenBalance);
        
        // Vérifier que le txId retourné correspond au dummyTxId.
        assertEq(txId, bytes32("dummyTxId"), "Incorrect CCIP txId");
        // Vérifier que les tokens ont été verrouillés dans le bridge.
        assertEq(goldToken.balanceOf(address(bridge)), userTokenBalance, "Tokens not locked in bridge");
        vm.stopPrank();
    }

    function test_fail_send_address() public {
        vm.startPrank(user);
        vm.deal(user, 10 ether);
        
        goldToken.mint{value: 1 ether}();
        uint256 userTokenBalance = goldToken.balanceOf(user);

        vm.expectRevert("Invalid receiver address");
        bridge.sendGold(address(0),userTokenBalance);
    }

    function test_fail_send_0() public {
        vm.startPrank(user);
        vm.expectRevert("Amount must be > 0");
        bridge.sendGold(userDest,0);
    }
    
    /// @notice Teste la fonction getFee() du GoldBridge.
    function testGetFee() public {
        // Simuler le retour d'un fee estimé par le routeur.
        uint256 dummyFee = 0.01 ether;
        
        // Construire le message CCIP comme dans getFee().
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
    
    /// @notice Teste la réception de GoldToken via CCIP.
    function testReceiveGold() public {
        // Pour ce test, on transfère des tokens dans le bridge pour simuler des tokens verrouillés.
        uint256 amount = 1000;
        // Mint des tokens pour l'utilisateur et les transférer au bridge.
        vm.startPrank(user);
        vm.deal(user, 10 ether);
        goldToken.mint{value: 1 ether}();
        uint256 userTokenBalance = goldToken.balanceOf(user);
        // Pour le test, transférer tout le solde de l'utilisateur au bridge.
        goldToken.transfer(address(bridge), userTokenBalance);
        vm.stopPrank();
        
        // Construire un message CCIP simulé : le message contient le destinataire dans data et le montant dans destTokenAmounts.
        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: address(goldToken),
            amount: userTokenBalance
        });
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: 0,
            sourceChainSelector: sourceChainId,
            sender: abi.encode(user),
            data: abi.encode(userDest), // destinataire sur cette chaîne
            destTokenAmounts: destTokenAmounts
        });
        
        uint256 userBalanceBefore = goldToken.balanceOf(userDest);
        
        // Appeler la fonction exposée pour simuler la réception du message.
        vm.prank(dummyRouter); // _ccipReceive vérifie que msg.sender == getRouter()
        bridge.exposeCcipReceive(message);
        
        uint256 userBalanceAfter = goldToken.balanceOf(userDest);
        assertEq(userBalanceAfter - userBalanceBefore, userTokenBalance, "Tokens not correctly transferred on receive");
    }

    /// @notice Teste la réception de GoldToken via CCIP.
    function test_fail_receive_invalidAmount() public {
        // Pour ce test, on transfère des tokens dans le bridge pour simuler des tokens verrouillés.
        uint256 amount = 1000;
        // Mint des tokens pour l'utilisateur et les transférer au bridge.
        vm.startPrank(user);
        vm.deal(user, 10 ether);
        goldToken.mint{value: 1 ether}();
        uint256 userTokenBalance = goldToken.balanceOf(user);
        // Pour le test, transférer tout le solde de l'utilisateur au bridge.
        goldToken.transfer(address(bridge), userTokenBalance);
        vm.stopPrank();
        
        // Construire un message CCIP simulé : le message contient le destinataire dans data et le montant dans destTokenAmounts.
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
            data: abi.encode(userDest), // destinataire sur cette chaîne
            destTokenAmounts: destTokenAmounts
        });
        
        uint256 userBalanceBefore = goldToken.balanceOf(userDest);
        
        // Appeler la fonction exposée pour simuler la réception du message.
        vm.prank(dummyRouter); // _ccipReceive vérifie que msg.sender == getRouter()
        vm.expectRevert("Invalid token amounts");
        bridge.exposeCcipReceive(message);
    }

    /// @notice Teste la réception de GoldToken via CCIP.
    function test_fail_receive_invalidToken() public {
        // Pour ce test, on transfère des tokens dans le bridge pour simuler des tokens verrouillés.
        uint256 amount = 1000;
        // Mint des tokens pour l'utilisateur et les transférer au bridge.
        vm.startPrank(user);
        vm.deal(user, 10 ether);
        goldToken.mint{value: 1 ether}();
        uint256 userTokenBalance = goldToken.balanceOf(user);
        // Pour le test, transférer tout le solde de l'utilisateur au bridge.
        goldToken.transfer(address(bridge), userTokenBalance);
        vm.stopPrank();
        
        // Construire un message CCIP simulé : le message contient le destinataire dans data et le montant dans destTokenAmounts.
        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: address(0),
            amount: userTokenBalance
        });
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: 0,
            sourceChainSelector: sourceChainId,
            sender: abi.encode(user),
            data: abi.encode(userDest), // destinataire sur cette chaîne
            destTokenAmounts: destTokenAmounts
        });
        
        uint256 userBalanceBefore = goldToken.balanceOf(userDest);
        
        // Appeler la fonction exposée pour simuler la réception du message.
        vm.prank(dummyRouter); // _ccipReceive vérifie que msg.sender == getRouter()
        vm.expectRevert("Unexpected token");
        bridge.exposeCcipReceive(message);
    }
}