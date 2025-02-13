// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@contracts/GoldToken.sol";
import "@mocks/MockGoldTokenV2.sol"; // Nouvelle implémentation (doit ajouter par exemple une fonction version() retournant "v2")
import "@contracts/PriceConsumer.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev Contrat simple servant de récepteur pour simuler un utilisateur capable de recevoir des ETH.
 */
contract Receiver {
    fallback() external payable {}
}

contract GoldTokenTest is Test {
    GoldToken public goldToken; // Instance via proxy
    address public owner;
    address public user;
    address public nonOwner;
    ERC1967Proxy public proxy;

    // Paramètres d'initialisation fictifs
    address constant DUMMY_XAUUSD = address(0x100);
    address constant DUMMY_ETHUSD = address(0x200);
    address constant DUMMY_VRFCOORDINATOR = address(0x300);
    address constant DUMMY_LINKTOKEN = address(0x400);
    bytes32 constant DUMMY_KEYHASH = bytes32("keyhash");
    uint256 constant DUMMY_VRFFEES = 1 ether;
    bytes32 constant OWNER_ROLE = bytes32("owner");

    function setUp() public {
        owner = address(this);
        nonOwner = address(0x123);

        // Pour simuler un utilisateur qui peut recevoir des ETH, déployer un Receiver.
        Receiver receiver = new Receiver();
        user = address(receiver);

        // Déployer l'implémentation initiale de GoldToken
        GoldToken logic = new GoldToken();

        // Encoder l'appel à initialize()
        bytes memory data = abi.encodeWithSelector(
            GoldToken.initialize.selector,
            DUMMY_XAUUSD,
            DUMMY_ETHUSD,
            DUMMY_VRFCOORDINATOR,
            DUMMY_LINKTOKEN,
            DUMMY_KEYHASH,
            DUMMY_VRFFEES
        );

        // Déployer le proxy upgradeable via openzeppelin-foundry-upgrades
        goldToken = new GoldToken();
        proxy = new ERC1967Proxy(
            address(goldToken),
            data
        );

        goldToken = GoldToken(payable(address(proxy)));

        // Pour simplifier les calculs de test, forcer PriceConsumer.getGoldPrice() à retourner 1e18 (1 ETH)
        vm.mockCall(
            address(goldToken.priceConsumer()),
            abi.encodeWithSelector(PriceConsumer.getGoldPrice.selector),
            abi.encode(1e18)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS DE MINT
    //////////////////////////////////////////////////////////////*/

    function testMint() public {
        vm.startPrank(user);
        uint256 ethSent = 1 ether;
        // Calcul : 5% de 1 ether = 0.05 ether de frais
        uint256 feeEth = (ethSent * 5) / 100;      // 0.05 ether
        uint256 ethAfterFee = ethSent - feeEth;      // 0.95 ether
        // Avec un goldPrice de 1e18, le nombre de tokens mintés = ethAfterFee (en unités de 1e18)
        uint256 expectedTokens = ethAfterFee;

        uint256 lotteryBalanceBefore = address(goldToken.lottery()).balance;
        uint256 contractBalanceBefore = address(goldToken).balance;

        vm.deal(user, 10 ether);
        goldToken.mint{value: ethSent}();

        // Vérifier que l'utilisateur a reçu le nombre correct de tokens
        assertEq(
            goldToken.balanceOf(user),
            expectedTokens,
            "Wrong amount"
        );

        // La Lottery reçoit 50% des frais (feeEth/2)
        uint256 lotteryFee = feeEth / 2;  // 0.025 ether
        uint256 lotteryBalanceAfter = address(goldToken.lottery()).balance;
        assertEq(
            lotteryBalanceAfter - lotteryBalanceBefore,
            lotteryFee,
            "Wrong fees"
        );

        // Le contrat conserve le reste des ETH
        uint256 expectedContractIncrease = ethSent - lotteryFee;
        uint256 contractBalanceAfter = address(goldToken).balance;
        assertEq(
            contractBalanceAfter - contractBalanceBefore,
            expectedContractIncrease,
            "Wrong mint"
        );
        vm.stopPrank();
    }

    function testMintRevertIfNoEth() public {
        vm.startPrank(user);
        vm.expectRevert("Send ETH to mint tokens");
        goldToken.mint{value: 0}();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS DE BURN
    //////////////////////////////////////////////////////////////*/

    function testBurn() public {
        vm.startPrank(user);
        // D'abord, mint des tokens avec 1 ether
        uint256 ethSent = 1 ether;
        vm.deal(user, 10 ether);
        goldToken.mint{value: ethSent}();
        uint256 initialTokenBalance = goldToken.balanceOf(user);
        // On s'attend à ce que initialTokenBalance = 0.95 ether (en tokens)

        // Calculs pour le burn (goldPrice = 1e18) :
        // ethToReturn = tokens brûlés, puis 5% de frais appliqués
        uint256 tokensToBurn = initialTokenBalance;
        uint256 ethToReturn = tokensToBurn;
        uint256 feeEth = (ethToReturn * 5) / 100;    // 5% de frais
        uint256 ethAfterFee = ethToReturn - feeEth;    // ETH net pour l'utilisateur
        uint256 lotteryFee = feeEth / 2;               // 50% des frais

        uint256 userEthBefore = user.balance;
        uint256 lotteryBalanceBefore = address(goldToken.lottery()).balance;

        goldToken.burn(tokensToBurn);

        // Vérifier que les tokens ont été brûlés
        assertEq(
            goldToken.balanceOf(user),
            0,
            "Non burnt"
        );

        // Vérifier que l'utilisateur reçoit le bon montant d'ETH
        uint256 userEthAfter = user.balance;
        assertEq(
            userEthAfter - userEthBefore,
            ethAfterFee,
            "Wrong amount after burn"
        );

        // Vérifier le transfert des frais vers la Lottery
        uint256 lotteryBalanceAfter = address(goldToken.lottery()).balance;
        assertEq(
            lotteryBalanceAfter - lotteryBalanceBefore,
            lotteryFee,
            "Wrong fees"
        );
        vm.stopPrank();
    }

    function testBurnRevertIfInsufficientBalance() public {
        vm.startPrank(user);
        vm.expectRevert("Insufficient balance");
        goldToken.burn(1e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS D'UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_canUpgrade() public {
        GoldToken newImplementation = new GoldToken();

        vm.prank(owner);
        UUPSUpgradeable(address(goldToken)).upgradeToAndCall(address(newImplementation), "");
    }

    function test_cannotUpgradeUnauthorized() public {
        GoldToken newImplementation = new GoldToken();

        vm.prank(nonOwner);
        vm.expectRevert();
        UUPSUpgradeable(address(goldToken)).upgradeToAndCall(address(newImplementation), "");
    }
}
