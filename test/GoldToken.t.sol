// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@contracts/GoldToken.sol";
import "@contracts/PriceConsumer.sol";
import "@contracts/Lottery.sol";

contract GoldTokenTest is Test {
    GoldToken public goldToken;
    address public user;

    // Paramètres fictifs pour le constructeur de GoldToken :
    // _xauusdAddress et _ethusdAddress pour PriceConsumer
    address public dummyXAUUSD = address(0x100);
    address public dummyETHUSD = address(0x200);
    // Paramètres pour Lottery
    address public dummyVRFCoordinator = address(0x300);
    address public dummyLinkToken = address(0x400);
    bytes32 public dummyKeyHash = bytes32("dummyKeyHash");
    uint256 public dummyVrfFee = 0;

    function setUp() public {
        user = address(0x123);
        // Déployer GoldToken en passant les adresses nécessaires
        goldToken = new GoldToken(
            dummyXAUUSD,
            dummyETHUSD,
            dummyVRFCoordinator,
            dummyLinkToken,
            dummyKeyHash,
            dummyVrfFee
        );
        // Forcer PriceConsumer.getGoldPrice() à retourner 1e18 pour simplifier les calculs
        vm.mockCall(
            address(goldToken.priceConsumer()),
            abi.encodeWithSelector(PriceConsumer.getGoldPrice.selector),
            abi.encode(1e18)
        );
    }

    /// @notice Vérifie que mint() crée le nombre attendu de tokens et transfère la bonne part de frais à la loterie.
    function testMint() public {
        vm.startPrank(user);
        uint256 ethSent = 1 ether;
        // Calcul : 5% de 1 ether = 0.05 ether de frais
        uint256 feeEth = (ethSent * 5) / 100;      // 0.05 ether
        uint256 ethAfterFee = ethSent - feeEth;      // 0.95 ether
        // Avec un goldPrice de 1e18, le nombre de tokens mintés est égal à ethAfterFee
        uint256 expectedTokens = ethAfterFee;

        uint256 lotteryBalanceBefore = address(goldToken.lottery()).balance;
        uint256 contractBalanceBefore = address(goldToken).balance;

        vm.deal(user, 10 ether);
        goldToken.mint{value: ethSent}();

        // Vérifier le nombre de tokens mintés pour l'utilisateur
        assertEq(
            goldToken.balanceOf(user),
            expectedTokens,
            "Incorrect number of tokens minted"
        );

        // La loterie reçoit 50% des frais, soit feeEth/2
        uint256 lotteryFee = feeEth / 2;  // 0.025 ether
        uint256 lotteryBalanceAfter = address(goldToken.lottery()).balance;
        assertEq(
            lotteryBalanceAfter - lotteryBalanceBefore,
            lotteryFee,
            "Incorrect fee transferred to lottery during mint"
        );

        // Le contrat GoldToken reçoit le reste des ETH (msg.value - lotteryFee)
        uint256 expectedContractIncrease = ethSent - lotteryFee;
        uint256 contractBalanceAfter = address(goldToken).balance;
        assertEq(
            contractBalanceAfter - contractBalanceBefore,
            expectedContractIncrease,
            "Incorrect ETH balance in contract after mint"
        );
        vm.stopPrank();
    }

    /// @notice Vérifie que mint() rejette un appel sans ETH.
    function testMintRevertIfNoEth() public {
        vm.startPrank(user);
        vm.expectRevert("Send ETH to mint tokens");
        goldToken.mint{value: 0}();
        vm.stopPrank();
    }

    /// @notice Teste que burn() restitue le bon montant d'ETH (après frais) et brûle les tokens.
    function testBurn() public {
        vm.startPrank(user);
        // D'abord, mint des tokens avec 1 ether.
        uint256 ethSent = 1 ether;
        vm.deal(user, 10 ether);
        goldToken.mint{value: ethSent}();
        uint256 initialTokenBalance = goldToken.balanceOf(user);
        // On s'attend à ce que initialTokenBalance soit égal à 0.95 ether (en tokens)

        // Calcul lors du burn :
        // ethToReturn = tokensToBurn (puisque goldPrice = 1e18)
        uint256 tokensToBurn = initialTokenBalance;
        uint256 ethToReturn = tokensToBurn;
        uint256 feeEth = (ethToReturn * 5) / 100;    // 5% des ETH à retourner
        uint256 ethAfterFee = ethToReturn - feeEth;    // ETH net reçu par l'utilisateur
        uint256 lotteryFee = feeEth / 2;               // 50% des frais

        uint256 userEthBefore = user.balance;
        uint256 lotteryBalanceBefore = address(goldToken.lottery()).balance;

        goldToken.burn(tokensToBurn);

        // L'utilisateur doit se retrouver avec 0 tokens
        assertEq(
            goldToken.balanceOf(user),
            0,
            "Tokens were not burned"
        );

        // L'utilisateur doit recevoir ethAfterFee en ETH
        uint256 userEthAfter = user.balance;
        assertEq(
            userEthAfter - userEthBefore,
            ethAfterFee,
            "Incorrect ETH returned to user after burn"
        );

        // La loterie doit recevoir lotteryFee en ETH
        uint256 lotteryBalanceAfter = address(goldToken.lottery()).balance;
        assertEq(
            lotteryBalanceAfter - lotteryBalanceBefore,
            lotteryFee,
            "Incorrect fee transferred to lottery during burn"
        );
        vm.stopPrank();
    }

    /// @notice Vérifie que burn() rejette l'opération si le solde de tokens est insuffisant.
    function testBurnRevertIfInsufficientBalance() public {
        vm.startPrank(user);
        vm.expectRevert("Insufficient balance");
        goldToken.burn(1e18);
        vm.stopPrank();
    }
}