// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@contracts/GoldToken.sol";
import "@contracts/PriceConsumer.sol";
import "@contracts/Lottery.sol";

contract GoldTokenTest is Test {
    GoldToken public goldToken;
    address public user;

    // Paramètres fictifs pour le constructeur de GoldToken
    address public dummyPriceFeed      = address(0x100);
    address public dummyVRFCoordinator = address(0x200);
    address public dummyLinkToken      = address(0x300);
    bytes32 public dummyKeyHash        = bytes32("dummyKeyHash");
    uint256 public dummyVrfFee         = 0;

    // Pour simplifier les calculs, on souhaite que PriceConsumer.getGoldPrice() retourne 1e18.
    // Ainsi, dans les formules de mint() et burn(), les conversions sont directes.
    function setUp() public {
        user = address(0x123);
        goldToken = new GoldToken(
            dummyPriceFeed,
            dummyVRFCoordinator,
            dummyLinkToken,
            dummyKeyHash,
            dummyVrfFee
        );
        // On force la fonction getGoldPrice() à retourner 1e18
        vm.mockCall(
            address(goldToken.priceConsumer()),
            abi.encodeWithSelector(PriceConsumer.getGoldPrice.selector),
            abi.encode(1e18)
        );
    }

    /// @notice Vérifie que mint() crée le nombre attendu de tokens et transfère la bonne part de fee à la loterie.
    function testMint() public {
        vm.startPrank(user);
        uint256 ethSent = 1 ether;
        // Calcul des frais : 5% de 1 ether = 0.05 ether
        uint256 feeEth      = (ethSent * 5) / 100; // 0.05 ether
        uint256 ethAfterFee = ethSent - feeEth;    // 0.95 ether
        // Le calcul des tokens mintés est : (ethAfterFee * 1e18) / goldPrice,
        // or avec goldPrice = 1e18, tokensToMint = ethAfterFee.
        uint256 expectedTokens = ethAfterFee;

        // On note la balance initiale du contrat Lottery et du GoldToken
        uint256 lotteryBalanceBefore  = address(goldToken.lottery()).balance;
        uint256 tokenContractBalanceBefore = address(goldToken).balance;

        // On s'assure que le compte possède suffisamment d'ETH
        vm.deal(user, 10 ether);
        goldToken.mint{value: ethSent}();

        // Vérifier que l'appelant reçoit bien le nombre de tokens attendu
        assertEq(
            goldToken.balanceOf(user),
            expectedTokens
        );

        // Le contrat envoie à la loterie 50% des frais (feeEth/2)
        uint256 lotteryFee = feeEth / 2; // ici 0.05/2 = 0.025 ether
        uint256 lotteryBalanceAfter = address(goldToken.lottery()).balance;
        assertEq(
            lotteryBalanceAfter - lotteryBalanceBefore,
            lotteryFee
        );

        // Le contrat GoldToken reçoit le reste de l'ETH (soit msg.value - lotteryFee)
        uint256 expectedContractIncrease = ethSent - lotteryFee;
        uint256 tokenContractBalanceAfter = address(goldToken).balance;
        assertEq(
            tokenContractBalanceAfter - tokenContractBalanceBefore,
            expectedContractIncrease
        );
    }

    /// @notice Vérifie que mint() rejette un appel sans ETH.
    function testMintRevertIfNoEth() public {
        vm.startPrank(user);
        vm.expectRevert("Send ETH to mint tokens");
        goldToken.mint{value: 0}();
    }

    /// @notice Teste que burn() restitue le bon montant d’ETH (après frais) et brûle les tokens.
    function testBurn() public {
        vm.startPrank(user);
        // D'abord, mint des tokens avec 1 ether.
        uint256 ethSent = 1 ether;
        vm.deal(user, 10 ether);
        goldToken.mint{value: ethSent}();
        uint256 initialTokenBalance = goldToken.balanceOf(user);
        // On s'attend à ce que initialTokenBalance == 0.95e18 (car ethAfterFee = 0.95 ether)

        // Lors du burn, le calcul est le suivant :
        // ethToReturn = (tokensToBurn * goldPrice) / 1e18 = tokensToBurn (puisque goldPrice = 1e18)
        // feeEth = 5% de ethToReturn, et ethAfterFee = ethToReturn - feeEth.
        uint256 tokensToBurn = initialTokenBalance;
        uint256 ethToReturn = tokensToBurn; // ici 0.95 ether
        uint256 feeEth      = (ethToReturn * 5) / 100; // 5% de 0.95 ether = 0.0475 ether
        uint256 ethAfterFee = ethToReturn - feeEth;      // 0.9025 ether
        uint256 lotteryFee  = feeEth / 2;                 // 0.02375 ether

        // On récupère la balance ETH de l'appelant et de la loterie avant le burn
        uint256 userEthBefore     = user.balance;
        uint256 lotteryBalanceBefore = address(goldToken.lottery()).balance;

        goldToken.burn(tokensToBurn);

        // Le solde de tokens de l'appelant doit être à 0
        assertEq(
            goldToken.balanceOf(user),
            0
        );

        // L'appelant doit recevoir ethAfterFee en ETH
        uint256 userEthAfter = user.balance;
        assertEq(
            userEthAfter - userEthBefore,
            ethAfterFee
        );

        // Le contrat doit transférer à la loterie la part correspondante aux frais
        uint256 lotteryBalanceAfter = address(goldToken.lottery()).balance;
        assertEq(
            lotteryBalanceAfter - lotteryBalanceBefore,
            lotteryFee
        );
    }

    /// @notice Vérifie que burn() rejette l'opération si le solde de tokens est insuffisant.
    function testBurnRevertIfInsufficientBalance() public {
        vm.startPrank(user);
        vm.expectRevert("Insufficient balance");
        goldToken.burn(1e18);
    }
}
