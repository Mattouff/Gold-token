// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import des outils de test de Foundry et du contrat à tester.
import "forge-std/Test.sol";
import "@contracts/Lottery.sol";

/*
  Ce fichier de test vérifie plusieurs comportements :
  - La fonction distributeFees rejette un appel avec 0 ETH.
  - Un dépôt d’ETH est correctement pris en compte tant que le nombre de participants est inférieur à 10.
  - Dès que 10 dépôts ont été effectués, la fonction requestRandomness est appelée (simulée ici) et,
    via le callback (rawFulfillRandomness), le gagnant est choisi, le pool est transféré et les variables réinitialisées.
  - Le fallback (receive) accepte bien des dépôts, sans modifier lotteryPool.
*/

contract LotteryTest is Test {
    Lottery public lottery;

    // On définit des adresses factices pour le VRF coordinator et le LINK token.
    address public vrfCoordinator = address(0x123);
    address public linkToken      = address(0x456);
    // Une valeur "dummy" pour keyHash (peut être n’importe quelle valeur, ici codée en dur).
    bytes32 public keyHash        = bytes32("dummyKeyHash");
    // Pour les tests, on fixe le fee à 0 pour éviter les vérifications de solde LINK.
    uint256 public fee            = 0;

    event LotteryWinner(address winner, uint256 amount);

    // La fonction setUp est exécutée avant chaque test.
    function setUp() public {
        lottery = new Lottery(vrfCoordinator, linkToken, keyHash, fee);
    }

    /// @notice Teste que la fonction distributeFees rejette un appel sans valeur.
    function testDistributeFeesRevertOnZeroValue() public {
        vm.prank(address(0x1));
        vm.expectRevert("No fees to distribute");
        lottery.distributeFees{value: 0}();
    }

    /// @notice Teste que l'appel à distributeFees avec un dépôt enregistre bien le participant
    /// et augmente le pool, tant que le nombre de participants reste inférieur à 10.
    function testDistributeFeesUnderTenParticipants() public {
        uint256 depositAmount = 1 ether;
        address participant   = address(0x1);

        // On donne à l'adresse participant une balance suffisante.
        vm.deal(participant, 10 ether);
        vm.prank(participant);
        lottery.distributeFees{value: depositAmount}();

        // Le pool du loto doit correspondre au montant déposé.
        assertEq(lottery.lotteryPool(), depositAmount);
        // Le participant est enregistré en position 0.
        assertEq(lottery.participants(0), participant);
    }

    /// @notice Teste le déroulement complet du Loto en adaptant les assertions selon la chaîne d'exécution.
    ///         - 10 dépôts de 1 ether par 10 adresses différentes
    ///         - Simulation du callback Chainlink (rawFulfillRandomness)
    ///         - Vérification que le gagnant est correctement choisi, que le pool est transféré et réinitialisé.
    function testLotteryFulfillment() public {
        // --- MOCK DE L'APPEL transferAndCall DU TOKEN LINK ---
        // Lors du 10ème dépôt, requestRandomness sera appelée,
        // qui via VRFConsumerBase appellera linkToken.transferAndCall(...).
        // On simule cet appel pour qu'il retourne 'true'.
        bytes memory payload = abi.encode(keyHash, uint256(0));
        vm.mockCall(
            linkToken,
            abi.encodeWithSignature("transferAndCall(address,uint256,bytes)", vrfCoordinator, fee, payload),
            abi.encode(true)
        );
        // --- FIN DU MOCK ---

        // Définir une tolérance en fonction de la chaîne d'exécution :
        // - En local (ex. chainid 31337 ou 1337), tolérance = 0 (comparaisons strictes)
        // - Sur mainnet/testnet (chainid 1, 4, 5, etc.), tolérance fixée à 1e15 wei (~0.001 ETH)
        uint256 tolerance = 0;
        if (block.chainid == 1 || block.chainid == 4 || block.chainid == 5) {
            tolerance = 1e15;
        }

        uint256 depositAmount = 1 ether;
        uint256 numParticipants = 10;

        // Simulation de 10 dépôts depuis 10 adresses différentes
        for (uint256 i = 0; i < numParticipants; i++) {
            address participant = address(uint160(i + 1));
            vm.deal(participant, 10 ether);
            vm.prank(participant);
            lottery.distributeFees{value: depositAmount}();
        }

        uint256 expectedPool = depositAmount * numParticipants;
        if (tolerance > 0) {
            assertApproxEqAbs(lottery.lotteryPool(), expectedPool, tolerance);
            assertApproxEqAbs(address(lottery).balance, expectedPool, tolerance);
        } else {
            assertEq(lottery.lotteryPool(), expectedPool);
            assertEq(address(lottery).balance, expectedPool);
        }

        // --- Simulation du callback Chainlink ---
        uint256 randomValue = 123;
        bytes32 requestId = bytes32("dummyRequestId");
        // Le gagnant est déterminé par randomValue % 10 = 123 % 10 = 3,
        // soit le 4ème participant (adresse convertie de uint160(4)).
        address expectedWinner = address(uint160(4));

        // Vérifier que l'événement LotteryWinner est émis avec les bonnes valeurs.
        vm.expectEmit(true, false, false, true);
        emit LotteryWinner(expectedWinner, expectedPool);

        // Simulation du callback (la fonction fulfillRandomness doit être appelée par le vrfCoordinator)
        vm.prank(vrfCoordinator);
        lottery.rawFulfillRandomness(requestId, randomValue);

        if (tolerance > 0) {
            assertApproxEqAbs(lottery.randomResult(), randomValue, tolerance);
            assertApproxEqAbs(lottery.lotteryPool(), 0, tolerance);
            assertApproxEqAbs(address(lottery).balance, 0, tolerance);
        } else {
            assertEq(lottery.randomResult(), randomValue);
            assertEq(lottery.lotteryPool(), 0);
            assertEq(address(lottery).balance, 0);
        }

        // Vérifier que la liste des participants a été vidée.
        vm.expectRevert();
        lottery.participants(0);

        // Vérifier que le gagnant a bien reçu le pool :
        // Chaque participant avait initialement 10 ether et a déposé 1 ether, donc le 4ème participant avait 9 ether.
        // Après avoir gagné le pool de 10 ether, son solde devrait être de 19 ether.
        if (tolerance > 0) {
            assertApproxEqAbs(expectedWinner.balance, 19 ether, tolerance);
        } else {
            assertEq(expectedWinner.balance, 19 ether);
        }
    }


    /// @notice Vérifie que la fonction receive (fallback) accepte les dépôts sans modifier le pool interne.
    function testReceive() public {
        address deposant = address(0xABC);
        vm.deal(deposant, 5 ether);

        // Envoi direct vers le contrat (la fonction receive() est appelée)
        (bool success, ) = address(lottery).call{value: 1 ether}("");
        assertTrue(success, "Le fallback doit accepter l'ETH");

        // Comme ce dépôt ne passe pas par distributeFees(), lotteryPool ne doit pas être modifié.
        assertEq(lottery.lotteryPool(), 0);
    }
}
