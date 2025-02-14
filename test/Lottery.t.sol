// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@contracts/Lottery.sol";
import "@mocks/MockLottery.sol";
import "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFSubscriptionV2Plus.sol";
import {VRFV2PlusClient} from "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";


contract LotteryTest is Test {
    MockLottery lottery;
    // For Sepolia (chainid 11155111), this should be the actual coordinator address.
    address constant COORDINATOR_ADDRESS = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    uint256 constant SUBSCRIPTION_ID = 113443817678221480716193921788970781569421434945316746607573576334968878784509;
    // Subscription owner address (must be the owner of the subscription on-chain)
    address constant SUB_OWNER = 0xa35CC4A4096d53e718460fDDE30d36854133282A;

    /// @dev Adds the Lottery contract as a consumer for the VRF subscription.
    function addLotteryConsumer(address lotteryAddress) internal {
        vm.startPrank(SUB_OWNER);
        IVRFSubscriptionV2Plus(COORDINATOR_ADDRESS).addConsumer(SUBSCRIPTION_ID, lotteryAddress);
        vm.stopPrank();
    }

    function setUp() public {
        // Ensure the test contract has ample ETH.
        vm.deal(address(this), 100 ether);
        
        // Deploy the lottery.
        lottery = new MockLottery(SUBSCRIPTION_ID);

        // Pre-fund the lottery contract with 1 ether.
        (bool success, ) = address(lottery).call{value: 1 ether}("");
        require(success, "Pre-funding lottery failed");

        if (block.chainid != 11155111) {
            // Use an empty expected calldata so that any call with the function selector is intercepted.
            vm.mockCall(
                COORDINATOR_ADDRESS,
                bytes(""),
                abi.encode(uint256(123))
            );
        } else {
            addLotteryConsumer(address(lottery));
        }
    }

    function testDistributeFeesRevertOnZeroValue() public {
        vm.expectRevert("No ETH sent");
        lottery.distributeFees{value: 0}();
    }

    function testDistributeFeesAddsParticipantAndUpdatesPool() public {
        uint256 fee = 1 ether;
        lottery.distributeFees{value: fee}();

        uint256 pool = lottery.lotteryPool();
        assertEq(pool, fee, "The lotteryPool must equal the sent value");

        address participant0 = lottery.participants(0);
        assertEq(participant0, address(this), "The participant must be the calling address");
    }

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

    function testFulfillRandomWordsResetsStateAndTransfersFunds() public {
        uint256 fee = 0.1 ether;
        uint256 nbParticipants = 10;
        for (uint256 i = 0; i < nbParticipants; i++) {
            lottery.distributeFees{value: fee}();
        }
        
        // Record the lottery pool amount (expected to be 10 * fee).
        uint256 poolBefore = lottery.lotteryPool();
        // Record the winner's (address(this)) balance before the payout.
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

    function testFulfillRandomWordsFailsForInvalidRequest() public {
        uint256 invalidRequestId = 999; // An ID that has never been created.
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;
        
        vm.expectRevert("Request not found");
        lottery.externalFulfillRandomWords(invalidRequestId, randomWords);
    }

    // Allow this contract to receive ETH during transfers.
    receive() external payable {}
}
