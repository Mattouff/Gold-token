// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "../src/Lottery.sol";
// On importe l'interface du coordinator pour pouvoir mocker l'appel externe.
import "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    // L'adresse du VRF coordinator est celle codée en dur dans le contrat.
    address public constant vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    // La valeur de keyHash est celle utilisée dans le contrat.
    bytes32 public constant expectedKeyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a48db59e5c46df3f6f2b;
    
    event LotteryWinner(address indexed winner, uint256 amount);
    event RequestSent(uint256 requestId, uint32 numWords);

    function setUp() public {
        // Le contrat Lottery se déploie avec un subscriptionId
        lottery = new Lottery(1);
    }

    /// @notice Vérifie que distributeFees rejette un appel avec 0 ETH.
    function testDistributeFeesRevertOnZeroValue() public {
        vm.prank(address(0x1));
        vm.expectRevert("No fees to distribute");
        lottery.distributeFees{value: 0}();
    }

    /// @notice Vérifie qu’un dépôt enregistre le participant et augmente le pool si moins de 10 participants.
    function testDistributeFeesUnderTenParticipants() public {
        uint256 depositAmount = 1 ether;
        address participant = address(0x1);
        vm.deal(participant, 10 ether);
        vm.prank(participant);
        lottery.distributeFees{value: depositAmount}();

        assertEq(lottery.lotteryPool(), depositAmount);
        assertEq(lottery.participants(0), participant);
    }

    /// @notice Teste l’appel direct à requestRandomWords et la mise à jour des variables associées.
    function testDirectRequestRandomWords() public {
        uint256 dummyRequestId = 333;
        bytes memory expectedCallData = abi.encodeWithSelector(
            VRFCoordinatorV2Interface.requestRandomWords.selector,
            expectedKeyHash,
            uint64(1),
            uint16(3),
            uint32(100000),
            uint32(1)
        );
        vm.mockCall(
            vrfCoordinator,
            expectedCallData,
            abi.encode(dummyRequestId)
        );

        uint256 requestId = lottery.requestRandomWords();
        assertEq(requestId, dummyRequestId);
        assertEq(lottery.lastRequestId(), dummyRequestId);
        assertEq(lottery.requestIds(0), dummyRequestId);
    }

    /// @notice Vérifie qu’après le 10ème dépôt, la fonction requestRandomWords est appelée et l’événement RequestSent est émis.
    function testRequestRandomWordsEmittedOnTenthDeposit() public {
        uint256 depositAmount = 1 ether;
        uint256 numParticipants = 10;
        uint256 dummyRequestId = 111;

        bytes memory expectedCallData = abi.encodeWithSelector(
            VRFCoordinatorV2Interface.requestRandomWords.selector,
            expectedKeyHash,
            uint64(1),
            uint16(3),
            uint32(100000),
            uint32(1)
        );
        vm.mockCall(
            vrfCoordinator,
            expectedCallData,
            abi.encode(dummyRequestId)
        );

        // Effectuer 9 dépôts (pas de demande VRF)
        for (uint256 i = 0; i < 9; i++) {
            address participant = address(uint160(i + 1));
            vm.deal(participant, 10 ether);
            vm.prank(participant);
            lottery.distributeFees{value: depositAmount}();
        }

        // Au 10ème dépôt, on s’attend à l’émission de RequestSent.
        vm.expectEmit(true, false, false, true);
        emit RequestSent(dummyRequestId, 1);
        address tenthParticipant = address(10);
        vm.deal(tenthParticipant, 10 ether);
        vm.prank(tenthParticipant);
        lottery.distributeFees{value: depositAmount}();

        assertEq(lottery.lastRequestId(), dummyRequestId);
        assertEq(lottery.requestIds(0), dummyRequestId);
    }

    /// @notice Teste le déroulement complet du loto :
    /// - 10 dépôts de 1 ether,
    /// - Simulation du callback via rawFulfillRandomWords,
    /// - Vérification que le gagnant reçoit le pool et que les variables sont réinitialisées.
    function testLotteryFulfillment() public {
        uint256 depositAmount = 1 ether;
        uint256 numParticipants = 10;
        uint256 dummyRequestId = 222;

        bytes memory expectedCallData = abi.encodeWithSelector(
            VRFCoordinatorV2Interface.requestRandomWords.selector,
            expectedKeyHash,
            uint64(1),
            uint16(3),
            uint32(100000),
            uint32(1)
        );
        vm.mockCall(
            vrfCoordinator,
            expectedCallData,
            abi.encode(dummyRequestId)
        );

        // Simulation de 10 dépôts depuis 10 adresses différentes.
        for (uint256 i = 0; i < numParticipants; i++) {
            address participant = address(uint160(i + 1));
            vm.deal(participant, 10 ether);
            vm.prank(participant);
            lottery.distributeFees{value: depositAmount}();
        }

        uint256 expectedPool = depositAmount * numParticipants;
        assertEq(lottery.lotteryPool(), expectedPool);
        assertEq(address(lottery).balance, expectedPool);

        // Préparer le tableau des randomWords pour le callback.
        uint256[] memory randomWords = new uint256[](1);
        uint256 randomValue = 3; // Le gagnant sera à l'index 3 (4ème participant)
        randomWords[0] = randomValue;

        address expectedWinner = address(uint160(4));

        vm.expectEmit(true, true, false, true);
        emit LotteryWinner(expectedWinner, expectedPool);


        // Simulation du callback par le VRF coordinator.
        vm.prank(vrfCoordinator);
        lottery.rawFulfillRandomWords(dummyRequestId, randomWords);

        // Vérifier que le pool et le solde du contrat sont remis à zéro.
        assertEq(lottery.lotteryPool(), 0);
        assertEq(address(lottery).balance, 0);

        // La liste des participants doit avoir été réinitialisée (l'accès à index 0 doit reverter).
        vm.expectRevert();
        lottery.participants(0);

        // Vérification du solde du gagnant : 10 ether initiaux - 1 ether déposé + 10 ether gagnés = 19 ether.
        assertEq(expectedWinner.balance, 19 ether);
    }

    /// @notice Vérifie que le callback revert si l’identifiant de demande n’existe pas.
    function testFulfillRandomWordsRevertIfRequestNotFound() public {
        uint256 dummyRequestId = 999;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 42;
        vm.prank(vrfCoordinator);
        vm.expectRevert("Request not found");
        lottery.rawFulfillRandomWords(dummyRequestId, randomWords);
    }

    /// @notice Vérifie que la fonction receive accepte l’ETH sans modifier lotteryPool.
    function testReceive() public {
        address depositor = address(0xABC);
        vm.deal(depositor, 5 ether);
        (bool success, ) = address(lottery).call{value: 1 ether}("");
        assertTrue(success, "La fonction receive doit accepter l'ETH");
        // Comme distributeFees n'est pas appelé, lotteryPool reste à 0.
        assertEq(lottery.lotteryPool(), 0);
    }
}
