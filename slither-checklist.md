Summary
 - [unchecked-transfer](#unchecked-transfer) (2 results) (High)
 - [unprotected-upgrade](#unprotected-upgrade) (1 results) (High)
 - [divide-before-multiply](#divide-before-multiply) (1 results) (Medium)
 - [unused-return](#unused-return) (4 results) (Medium)
 - [events-maths](#events-maths) (1 results) (Low)
 - [reentrancy-benign](#reentrancy-benign) (1 results) (Low)
 - [reentrancy-events](#reentrancy-events) (3 results) (Low)
 - [assembly](#assembly) (15 results) (Informational)
 - [pragma](#pragma) (1 results) (Informational)
 - [solc-version](#solc-version) (5 results) (Informational)
 - [low-level-calls](#low-level-calls) (4 results) (Informational)
 - [naming-convention](#naming-convention) (23 results) (Informational)
 - [reentrancy-unlimited-gas](#reentrancy-unlimited-gas) (1 results) (Informational)
 - [too-many-digits](#too-many-digits) (1 results) (Informational)
 - [constable-states](#constable-states) (4 results) (Optimization)
 - [immutable-states](#immutable-states) (7 results) (Optimization)
## unchecked-transfer
Impact: High
Confidence: Medium
 - [ ] ID-0
[GoldBridge._ccipReceive(Client.Any2EVMMessage)](src/GoldBridge.sol#L143-L158) ignores return value by [goldToken.transfer(receiver,amount)](src/GoldBridge.sol#L155)

src/GoldBridge.sol#L143-L158


 - [ ] ID-1
[GoldBridge.sendGold(address,uint256)](src/GoldBridge.sol#L79-L109) ignores return value by [goldToken.transferFrom(msg.sender,address(this),_amount)](src/GoldBridge.sol#L84)

src/GoldBridge.sol#L79-L109


## unprotected-upgrade
Impact: High
Confidence: High
 - [ ] ID-2
[GoldToken](src/GoldToken.sol#L22-L122) is an upgradeable contract that does not protect its initialize functions: [GoldToken.initialize(address,address,uint64)](src/GoldToken.sol#L49-L60). Anyone can delete the contract with: [UUPSUpgradeable.upgradeToAndCall(address,bytes)](lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol#L92-L95)
src/GoldToken.sol#L22-L122


## divide-before-multiply
Impact: Medium
Confidence: Medium
 - [ ] ID-3
[GoldToken.burn(uint256)](src/GoldToken.sol#L94-L110) performs a multiplication on the result of a division:
	- [ethToReturn = (amount * goldPriceInWei) / 1e18](src/GoldToken.sol#L98)
	- [feeEth = (ethToReturn * FEE_PERCENT) / 100](src/GoldToken.sol#L101)

src/GoldToken.sol#L94-L110


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-4
[ERC1967Utils.upgradeBeaconToAndCall(address,bytes)](lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol#L157-L166) ignores return value by [Address.functionDelegateCall(IBeacon(newBeacon).implementation(),data)](lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol#L162)

lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol#L157-L166


 - [ ] ID-5
[ERC1967Utils.upgradeToAndCall(address,bytes)](lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol#L67-L76) ignores return value by [Address.functionDelegateCall(newImplementation,data)](lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol#L72)

lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol#L67-L76


 - [ ] ID-6
[PriceConsumer.getGoldPrice()](src/PriceConsumer.sol#L40-L53) ignores return value by [(None,xauPrice,None,None,None) = xauusdAggregator.latestRoundData()](src/PriceConsumer.sol#L41)

src/PriceConsumer.sol#L40-L53


 - [ ] ID-7
[PriceConsumer.getGoldPrice()](src/PriceConsumer.sol#L40-L53) ignores return value by [(None,ethPrice,None,None,None) = ethusdAggregator.latestRoundData()](src/PriceConsumer.sol#L42)

src/PriceConsumer.sol#L40-L53


## events-maths
Impact: Low
Confidence: Medium
 - [ ] ID-8
[Lottery.distributeFees()](src/Lottery.sol#L109-L118) should emit an event for: 
	- [lotteryPool += msg.value](src/Lottery.sol#L111) 

src/Lottery.sol#L109-L118


## reentrancy-benign
Impact: Low
Confidence: Medium
 - [ ] ID-9
Reentrancy in [Lottery._requestRandomWords()](src/Lottery.sol#L129-L150):
	External calls:
	- [requestId = s_vrfCoordinator.requestRandomWords(req)](src/Lottery.sol#L141)
	State variables written after the call(s):
	- [lastRequestId = requestId](src/Lottery.sol#L148)
	- [requestIds.push(requestId)](src/Lottery.sol#L147)
	- [s_requests[requestId] = RequestStatus({randomWords:new uint256[](0),exists:true,fulfilled:false})](src/Lottery.sol#L142-L146)

src/Lottery.sol#L129-L150


## reentrancy-events
Impact: Low
Confidence: Medium
 - [ ] ID-10
Reentrancy in [GoldBridge.sendGold(address,uint256)](src/GoldBridge.sol#L79-L109):
	External calls:
	- [goldToken.transferFrom(msg.sender,address(this),_amount)](src/GoldBridge.sol#L84)
	- [txId = IRouterClient(getRouter()).ccipSend{value: msg.value}(destinationChainId,message)](src/GoldBridge.sol#L106)
	External calls sending eth:
	- [txId = IRouterClient(getRouter()).ccipSend{value: msg.value}(destinationChainId,message)](src/GoldBridge.sol#L106)
	Event emitted after the call(s):
	- [GoldSent(msg.sender,_receiver,_amount,destinationChainId)](src/GoldBridge.sol#L108)

src/GoldBridge.sol#L79-L109


 - [ ] ID-11
Reentrancy in [GoldBridge._ccipReceive(Client.Any2EVMMessage)](src/GoldBridge.sol#L143-L158):
	External calls:
	- [goldToken.transfer(receiver,amount)](src/GoldBridge.sol#L155)
	Event emitted after the call(s):
	- [GoldReceived(receiver,amount)](src/GoldBridge.sol#L157)

src/GoldBridge.sol#L143-L158


 - [ ] ID-12
Reentrancy in [Lottery._requestRandomWords()](src/Lottery.sol#L129-L150):
	External calls:
	- [requestId = s_vrfCoordinator.requestRandomWords(req)](src/Lottery.sol#L141)
	Event emitted after the call(s):
	- [RequestSent(requestId,numWords)](src/Lottery.sol#L149)

src/Lottery.sol#L129-L150


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-13
[StorageSlot.getAddressSlot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L66-L70) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L67-L69)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L66-L70


 - [ ] ID-14
[StorageSlot.getInt256Slot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L102-L106) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L103-L105)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L102-L106


 - [ ] ID-15
[OwnableUpgradeable._getOwnableStorage()](lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L30-L34) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L31-L33)

lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L30-L34


 - [ ] ID-16
[StorageSlot.getBytesSlot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L129-L133) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L130-L132)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L129-L133


 - [ ] ID-17
[StorageSlot.getStringSlot(string)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L120-L124) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L121-L123)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L120-L124


 - [ ] ID-18
[ERC20Upgradeable._getERC20Storage()](lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L46-L50) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L47-L49)

lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L46-L50


 - [ ] ID-19
[SafeERC20._callOptionalReturnBool(IERC20,bytes)](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L188-L198) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L192-L196)

lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L188-L198


 - [ ] ID-20
[StorageSlot.getBytes32Slot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L84-L88) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L85-L87)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L84-L88


 - [ ] ID-21
[StorageSlot.getBytesSlot(bytes)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L138-L142) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L139-L141)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L138-L142


 - [ ] ID-22
[Initializable._getInitializableStorage()](lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol#L223-L227) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol#L224-L226)

lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol#L223-L227


 - [ ] ID-23
[Address._revert(bytes)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L138-L149) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/Address.sol#L142-L145)

lib/openzeppelin-contracts/contracts/utils/Address.sol#L138-L149


 - [ ] ID-24
[StorageSlot.getBooleanSlot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L75-L79) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L76-L78)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L75-L79


 - [ ] ID-25
[StorageSlot.getStringSlot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L111-L115) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L112-L114)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L111-L115


 - [ ] ID-26
[SafeERC20._callOptionalReturn(IERC20,bytes)](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L160-L178) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L163-L173)

lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L160-L178


 - [ ] ID-27
[StorageSlot.getUint256Slot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L93-L97) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L94-L96)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L93-L97


## pragma
Impact: Informational
Confidence: High
 - [ ] ID-28
5 different versions of Solidity are used:
	- Version constraint ^0.8.4 is used by:
		-[^0.8.4](lib/ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol#L2)
		-[^0.8.4](lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol#L2)
		-[^0.8.4](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol#L2)
		-[^0.8.4](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol#L2)
	- Version constraint ^0.8.0 is used by:
		-[^0.8.0](lib/ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol#L2)
		-[^0.8.0](lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol#L2)
		-[^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFCoordinatorV2Plus.sol#L2)
		-[^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFMigratableConsumerV2Plus.sol#L2)
		-[^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFSubscriptionV2Plus.sol#L2)
		-[^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol#L2)
		-[^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol#L2)
		-[^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/access/ConfirmedOwner.sol#L2)
		-[^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/access/ConfirmedOwnerWithProposal.sol#L2)
		-[^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/IOwnable.sol#L2)
		-[^0.8.0](src/GoldBridge.sol#L2)
		-[^0.8.0](src/GoldToken.sol#L2)
		-[^0.8.0](src/Lottery.sol#L2)
		-[^0.8.0](src/PriceConsumer.sol#L2)
	- Version constraint ^0.8.20 is used by:
		-[^0.8.20](lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v5.0.2/contracts/utils/introspection/IERC165.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/IERC1967.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/draft-IERC1822.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol#L3)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/Address.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/Errors.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L5)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol#L4)
	- Version constraint ^0.8.21 is used by:
		-[^0.8.21](lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol#L4)
	- Version constraint ^0.8.22 is used by:
		-[^0.8.22](lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol#L4)

lib/ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol#L2


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-29
Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
It is used by:
	- [^0.8.20](lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v5.0.2/contracts/utils/introspection/IERC165.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/IERC1967.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/draft-IERC1822.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol#L3)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/Address.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/Errors.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L5)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol#L4)

lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v5.0.2/contracts/utils/introspection/IERC165.sol#L4


 - [ ] ID-30
Version constraint ^0.8.21 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication.
It is used by:
	- [^0.8.21](lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol#L4)

lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol#L4


 - [ ] ID-31
Version constraint ^0.8.22 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication.
It is used by:
	- [^0.8.22](lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol#L4)

lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol#L4


 - [ ] ID-32
Version constraint ^0.8.4 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess
	- AbiReencodingHeadOverflowWithStaticArrayCleanup
	- DirtyBytesArrayToStorage
	- DataLocationChangeInInternalOverride
	- NestedCalldataArrayAbiReencodingSizeValidation
	- SignedImmutables.
It is used by:
	- [^0.8.4](lib/ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol#L2)
	- [^0.8.4](lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol#L2)
	- [^0.8.4](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol#L2)
	- [^0.8.4](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol#L2)

lib/ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol#L2


 - [ ] ID-33
Version constraint ^0.8.0 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess
	- AbiReencodingHeadOverflowWithStaticArrayCleanup
	- DirtyBytesArrayToStorage
	- DataLocationChangeInInternalOverride
	- NestedCalldataArrayAbiReencodingSizeValidation
	- SignedImmutables
	- ABIDecodeTwoDimensionalArrayMemory
	- KeccakCaching.
It is used by:
	- [^0.8.0](lib/ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol#L2)
	- [^0.8.0](lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol#L2)
	- [^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFCoordinatorV2Plus.sol#L2)
	- [^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFMigratableConsumerV2Plus.sol#L2)
	- [^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFSubscriptionV2Plus.sol#L2)
	- [^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol#L2)
	- [^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol#L2)
	- [^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/access/ConfirmedOwner.sol#L2)
	- [^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/access/ConfirmedOwnerWithProposal.sol#L2)
	- [^0.8.0](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/IOwnable.sol#L2)
	- [^0.8.0](src/GoldBridge.sol#L2)
	- [^0.8.0](src/GoldToken.sol#L2)
	- [^0.8.0](src/Lottery.sol#L2)
	- [^0.8.0](src/PriceConsumer.sol#L2)

lib/ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol#L2


## low-level-calls
Impact: Informational
Confidence: High
 - [ ] ID-34
Low level call in [Address.functionDelegateCall(address,bytes)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L96-L99):
	- [(success,returndata) = target.delegatecall(data)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L97)

lib/openzeppelin-contracts/contracts/utils/Address.sol#L96-L99


 - [ ] ID-35
Low level call in [Address.functionCallWithValue(address,bytes,uint256)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L75-L81):
	- [(success,returndata) = target.call{value: value}(data)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L79)

lib/openzeppelin-contracts/contracts/utils/Address.sol#L75-L81


 - [ ] ID-36
Low level call in [Address.sendValue(address,uint256)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L33-L42):
	- [(success,None) = recipient.call{value: amount}()](lib/openzeppelin-contracts/contracts/utils/Address.sol#L38)

lib/openzeppelin-contracts/contracts/utils/Address.sol#L33-L42


 - [ ] ID-37
Low level call in [Address.functionStaticCall(address,bytes)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L87-L90):
	- [(success,returndata) = target.staticcall(data)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L88)

lib/openzeppelin-contracts/contracts/utils/Address.sol#L87-L90


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-38
Constant [OwnableUpgradeable.OwnableStorageLocation](lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L28) is not in UPPER_CASE_WITH_UNDERSCORES

lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L28


 - [ ] ID-39
Variable [Lottery.COORDINATOR](src/Lottery.sol#L26) is not in mixedCase

src/Lottery.sol#L26


 - [ ] ID-40
Parameter [GoldToken.initialize(address,address,uint64)._xauusdAddress](src/GoldToken.sol#L50) is not in mixedCase

src/GoldToken.sol#L50


 - [ ] ID-41
Parameter [GoldToken.initialize(address,address,uint64)._subscriptionId](src/GoldToken.sol#L52) is not in mixedCase

src/GoldToken.sol#L52


 - [ ] ID-42
Parameter [GoldToken.initialize(address,address,uint64)._ethusdAddress](src/GoldToken.sol#L51) is not in mixedCase

src/GoldToken.sol#L51


 - [ ] ID-43
Function [OwnableUpgradeable.__Ownable_init(address)](lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L51-L53) is not in mixedCase

lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L51-L53


 - [ ] ID-44
Function [ERC20Upgradeable.__ERC20_init_unchained(string,string)](lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L62-L66) is not in mixedCase

lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L62-L66


 - [ ] ID-45
Function [OwnableUpgradeable.__Ownable_init_unchained(address)](lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L55-L60) is not in mixedCase

lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol#L55-L60


 - [ ] ID-46
Variable [Lottery.s_subscriptionId](src/Lottery.sol#L32) is not in mixedCase

src/Lottery.sol#L32


 - [ ] ID-47
Parameter [GoldBridge.getFee(address,uint256)._receiver](src/GoldBridge.sol#L115) is not in mixedCase

src/GoldBridge.sol#L115


 - [ ] ID-48
Function [ERC20Upgradeable.__ERC20_init(string,string)](lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L58-L60) is not in mixedCase

lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L58-L60


 - [ ] ID-49
Function [ContextUpgradeable.__Context_init_unchained()](lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol#L21-L22) is not in mixedCase

lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol#L21-L22


 - [ ] ID-50
Parameter [VRFConsumerBaseV2Plus.setCoordinator(address)._vrfCoordinator](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol#L144) is not in mixedCase

lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol#L144


 - [ ] ID-51
Function [UUPSUpgradeable.__UUPSUpgradeable_init_unchained()](lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol#L68-L69) is not in mixedCase

lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol#L68-L69


 - [ ] ID-52
Parameter [GoldBridge.getFee(address,uint256)._amount](src/GoldBridge.sol#L115) is not in mixedCase

src/GoldBridge.sol#L115


 - [ ] ID-53
Variable [UUPSUpgradeable.__self](lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol#L22) is not in mixedCase

lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol#L22


 - [ ] ID-54
Parameter [GoldBridge.sendGold(address,uint256)._amount](src/GoldBridge.sol#L79) is not in mixedCase

src/GoldBridge.sol#L79


 - [ ] ID-55
Constant [ERC20Upgradeable.ERC20StorageLocation](lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L44) is not in UPPER_CASE_WITH_UNDERSCORES

lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#L44


 - [ ] ID-56
Function [UUPSUpgradeable.__UUPSUpgradeable_init()](lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol#L65-L66) is not in mixedCase

lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol#L65-L66


 - [ ] ID-57
Parameter [GoldBridge.sendGold(address,uint256)._receiver](src/GoldBridge.sol#L79) is not in mixedCase

src/GoldBridge.sol#L79


 - [ ] ID-58
Variable [Lottery.s_requests](src/Lottery.sol#L60) is not in mixedCase

src/Lottery.sol#L60


 - [ ] ID-59
Function [ContextUpgradeable.__Context_init()](lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol#L18-L19) is not in mixedCase

lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol#L18-L19


 - [ ] ID-60
Variable [VRFConsumerBaseV2Plus.s_vrfCoordinator](lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol#L106) is not in mixedCase

lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol#L106


## reentrancy-unlimited-gas
Impact: Informational
Confidence: Medium
 - [ ] ID-61
Reentrancy in [Lottery.fulfillRandomWords(uint256,uint256[])](src/Lottery.sol#L161-L176):
	External calls:
	- [address(winner).transfer(lotteryPool)](src/Lottery.sol#L170)
	State variables written after the call(s):
	- [lotteryPool = 0](src/Lottery.sol#L175)
	- [participants = new address[](0)](src/Lottery.sol#L174)
	Event emitted after the call(s):
	- [LotteryWinner(winner,lotteryPool)](src/Lottery.sol#L171)

src/Lottery.sol#L161-L176


## too-many-digits
Impact: Informational
Confidence: Medium
 - [ ] ID-62
[Lottery.slitherConstructorVariables()](src/Lottery.sol#L19-L177) uses literals with too many digits:
	- [callbackGasLimit = 100000](src/Lottery.sol#L38)

src/Lottery.sol#L19-L177


## constable-states
Impact: Optimization
Confidence: High
 - [ ] ID-63
[Lottery.numWords](src/Lottery.sol#L41) should be constant 

src/Lottery.sol#L41


 - [ ] ID-64
[Lottery.randomResult](src/Lottery.sol#L44) should be constant 

src/Lottery.sol#L44


 - [ ] ID-65
[Lottery.callbackGasLimit](src/Lottery.sol#L38) should be constant 

src/Lottery.sol#L38


 - [ ] ID-66
[Lottery.requestConfirmations](src/Lottery.sol#L35) should be constant 

src/Lottery.sol#L35


## immutable-states
Impact: Optimization
Confidence: High
 - [ ] ID-67
[PriceConsumer.ethusdAggregator](src/PriceConsumer.sol#L24) should be immutable 

src/PriceConsumer.sol#L24


 - [ ] ID-68
[PriceConsumer.xauusdAggregator](src/PriceConsumer.sol#L22) should be immutable 

src/PriceConsumer.sol#L22


 - [ ] ID-69
[Lottery.COORDINATOR](src/Lottery.sol#L26) should be immutable 

src/Lottery.sol#L26


 - [ ] ID-70
[Lottery.keyHash](src/Lottery.sol#L29) should be immutable 

src/Lottery.sol#L29


 - [ ] ID-71
[GoldBridge.goldToken](src/GoldBridge.sol#L31) should be immutable 

src/GoldBridge.sol#L31


 - [ ] ID-72
[Lottery.s_subscriptionId](src/Lottery.sol#L32) should be immutable 

src/Lottery.sol#L32


 - [ ] ID-73
[GoldBridge.destinationChainId](src/GoldBridge.sol#L34) should be immutable 

src/GoldBridge.sol#L34


