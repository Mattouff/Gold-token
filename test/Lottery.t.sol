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

    /// @notice Teste le déroulement complet du Loto :
    /// - 10 dépôts de 1 ether par 10 adresses différentes
    /// - Simulation du callback Chainlink (rawFulfillRandomness)
    /// - Vérification que le gagnant est correctement choisi, que le pool est transféré et réinitialisé.
    function testLotteryFulfillment() public {
        // --- MOCK DE L'APPEL TRANSFERANDCALL DU TOKEN LINK ---
        //
        // Lors du 10ème dépôt, requestRandomness sera appelée,
        // qui, via VRFConsumerBase, appellera linkToken.transferAndCall(...).
        // On simule cet appel pour qu'il retourne 'true'.

        // Préparer le payload attendu (selon l’implémentation de VRFConsumerBase)
        bytes memory payload = abi.encode(keyHash, uint256(0));
        vm.mockCall(
            linkToken,
            abi.encodeWithSignature("transferAndCall(address,uint256,bytes)", vrfCoordinator, fee, payload),
            abi.encode(true)
        );
        // --- FIN DU MOCK ---

        uint256 depositAmount   = 1 ether;
        uint256 numParticipants = 10;

        // Simuler 10 dépôts depuis 10 adresses différentes
        for (uint256 i = 0; i < numParticipants; i++) {
            address participant = address(uint160(i + 1));
            vm.deal(participant, 10 ether);
            vm.prank(participant);
            lottery.distributeFees{value: depositAmount}();
        }

        uint256 expectedPool = depositAmount * numParticipants;
        assertEq(lottery.lotteryPool(), expectedPool);
        assertEq(address(lottery).balance, expectedPool);

        // --- Simulation du callback Chainlink ---
        uint256 randomValue = 123;
        bytes32 requestId   = bytes32("dummyRequestId");
        // Le gagnant sera choisi via randomValue % 10 = 123 % 10 = 3 (4ème participant)
        address expectedWinner = address(uint160(4));

        // Vérification de l'émission de l'événement LotteryWinner.
        vm.expectEmit(true, false, false, true);
        emit LotteryWinner(expectedWinner, expectedPool);

        // Simulation du callback (la fonction fulfillRandomness nécessite que msg.sender soit le vrfCoordinator)
        vm.prank(vrfCoordinator);
        lottery.rawFulfillRandomness(requestId, randomValue);

        assertEq(lottery.randomResult(), randomValue);
        assertEq(lottery.lotteryPool(), 0);
        assertEq(address(lottery).balance, 0);

        // Vérifier que la liste des participants a été vidée.
        vm.expectRevert();
        lottery.participants(0);

        // Vérifier que le gagnant a reçu le pool
        // Chaque participant a 10 ether, a envoyé 1 ether, donc le participant gagnant (n°4) avait 9 ether.
        // Après avoir gagné le pool de 10 ether, son solde doit être de 19 ether.
        assertEq(expectedWinner.balance, 19 ether);
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
