// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@contracts/Lottery.sol";
import "@mocks/MockLottery.sol";
import "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFSubscriptionV2Plus.sol";
import {VRFV2PlusClient} from "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

/**
 * @title LotteryTest
 * @notice This contract contains unit tests for the Lottery contract.
 * @dev Uses Forge's Test framework to simulate CCIP and VRF interactions.
 */
contract LotteryTest is Test {
    /// @notice Instance of the mock Lottery contract.
    MockLottery lottery;

    /// @notice The VRF coordinator address for Sepolia.
    address constant COORDINATOR_ADDRESS = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    /// @notice The VRF subscription ID.
    uint256 constant SUBSCRIPTION_ID = 113443817678221480716193921788970781569421434945316746607573576334968878784509;
    /// @notice The subscription owner address (must be the on-chain subscription owner).
    address constant SUB_OWNER = 0xa35CC4A4096d53e718460fDDE30d36854133282A;

    /**
     * @notice Internal function to add the Lottery contract as a consumer for the VRF subscription.
     * @param lotteryAddress The address of the Lottery contract.
     */
    function addLotteryConsumer(address lotteryAddress) internal {
        vm.startPrank(SUB_OWNER);
        IVRFSubscriptionV2Plus(COORDINATOR_ADDRESS).addConsumer(SUBSCRIPTION_ID, lotteryAddress);
        vm.stopPrank();
    }

    /**
     * @notice Sets up the test environment.
     * @dev Deploys the MockLottery, funds it with ETH, and either mocks VRF calls or adds the lottery as a consumer based on the chain ID.
     */
    function setUp() public {
        // Ensure this test contract has ample ETH.
        vm.deal(address(this), 100 ether);
        
        // Deploy the lottery contract.
        lottery = new MockLottery(SUBSCRIPTION_ID);

        // Pre-fund the lottery contract with 1 ether.
        (bool success, ) = address(lottery).call{value: 1 ether}("");
        require(success, "Pre-funding lottery failed");

        if (block.chainid != 11155111) {
            // If not on Sepolia, mock any call to the coordinator to return a dummy request ID.
            vm.mockCall(
                COORDINATOR_ADDRESS,
                bytes(""),
                abi.encode(uint256(123))
            );
        } else {
            // On Sepolia, add the lottery as a consumer of the VRF subscription.
            addLotteryConsumer(address(lottery));
        }
    }

    /**
     * @notice Tests that distributeFees() reverts when called with zero ETH.
     */
    function testDistributeFeesRevertOnZeroValue() public {
        vm.expectRevert("No ETH sent");
        lottery.distributeFees{value: 0}();
    }

    /**
     * @notice Tests that distributeFees() correctly adds the caller as a participant and updates the lottery pool.
     */
    function testDistributeFeesAddsParticipantAndUpdatesPool() public {
        uint256 fee = 1 ether;
        lottery.distributeFees{value: fee}();

        uint256 pool = lottery.lotteryPool();
        assertEq(pool, fee, "The lotteryPool must equal the sent value");

        address participant0 = lottery.participants(0);
        assertEq(participant0, address(this), "The participant must be the calling address");
    }

    /**
     * @notice Tests that a VRF request is triggered after 10 participants have called distributeFees().
     */
    function testRequestRandomWordsTriggeredAfter10Participants() public {
        uint256 fee = 0.1 ether;
        for (uint256 i = 0; i < 10; i++) {
            lottery.distributeFees{value: fee}();
        }
        uint256 reqId = lottery.lastRequestId();
        if (block.chainid != 11155111) {
            assertEq(reqId, 123, "The VRF request must return 123");
        } else {
            assertTrue(reqId != 0, "A VRF request must have been triggered");
        }
    }

    /**
     * @notice Tests that fulfillRandomWords() resets the lottery state and transfers funds to the selected winner.
     * @dev Simulates 10 participants, triggers the VRF callback, and verifies that the lottery pool is reset,
     * the participants array is cleared, and the winner receives the correct payout.
     */
    function testFulfillRandomWordsResetsStateAndTransfersFunds() public {
        uint256 fee = 0.1 ether;
        uint256 nbParticipants = 10;
        for (uint256 i = 0; i < nbParticipants; i++) {
            lottery.distributeFees{value: fee}();
        }
        
        // Record the lottery pool amount (expected to be 10 * fee).
        uint256 poolBefore = lottery.lotteryPool();
        // Record the winner's balance before the payout.
        uint256 winnerBalanceBefore = address(this).balance;
        
        uint256 reqId = lottery.lastRequestId();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 5; // Winner index: 5 % 10
        
        // Simulate the VRF callback.
        lottery.externalFulfillRandomWords(reqId, randomWords);
        
        // Check that the lottery pool is reset.
        assertEq(lottery.lotteryPool(), 0, "The lottery pool must be reset");
        
        // Verify that the participants array is reset.
        bool reverted;
        try lottery.participants(0) {
            reverted = false;
        } catch {
            reverted = true;
        }
        assertTrue(reverted, "The participants array must be reset");

        // Check that the winner's balance increased by the lottery pool amount.
        uint256 winnerBalanceAfter = address(this).balance;
        assertEq(
            winnerBalanceAfter - winnerBalanceBefore,
            poolBefore,
            "The winner did not receive the correct payout"
        );
    }

    /**
     * @notice Tests that fulfillRandomWords() reverts when called with an invalid request ID.
     */
    function testFulfillRandomWordsFailsForInvalidRequest() public {
        uint256 invalidRequestId = 999; // An ID that has never been created.
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;
        
        vm.expectRevert("Request not found");
        lottery.externalFulfillRandomWords(invalidRequestId, randomWords);
    }

    /**
     * @notice Allows this test contract to receive ETH during transfers.
     */
    receive() external payable {}
}
