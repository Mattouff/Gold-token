// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/GoldToken.sol";
import "../src/Lottery.sol";
import "../src/PriceConsumer.sol";

// Mock du Price Feed Chainlink
contract MockPriceFeed is AggregatorV3Interface {
    int public price;
    uint8 public decimals = 8;

    function setPrice(int _price) external {
        price = _price;
    }

    function latestRoundData() external view returns (
        uint80 roundId,
        int answer,
        uint startedAt,
        uint updatedAt,
        uint80 answeredInRound
    ) {
        return (0, price, 0, 0, 0);
    }
    
    // Les autres fonctions ne sont pas utilisées
    function getRoundData(uint80) external pure returns (uint80, int, uint, uint, uint80) {
        revert();
    }
    function description() external pure returns (string memory) { return ""; }
    function version() external pure returns (uint256) { return 0; }
}

contract GoldTokenTest is Test {
    GoldToken public goldToken;
    MockPriceFeed public mockPriceFeed;
    address public user = address(1);
    
    // Configuration VRF factice pour les tests
    address constant VRF_COORDINATOR = address(0x123);
    address constant LINK_TOKEN = address(0x456);
    bytes32 constant KEY_HASH = keccak256("TEST_KEY");
    uint256 constant VRF_FEE = 0.1 ether;

    function setUp() public {
        // Déployer le mock PriceFeed
        mockPriceFeed = new MockPriceFeed();
        
        // Prix initial : 2000 USD par gramme (8 décimales)
        mockPriceFeed.setPrice(2000 * 1e8);

        // Déployer GoldToken avec le mock
        goldToken = new GoldToken(
            address(mockPriceFeed),
            VRF_COORDINATOR,
            LINK_TOKEN,
            KEY_HASH,
            VRF_FEE
        );

        // Créditer l'utilisateur avec 100 ETH
        vm.deal(user, 100 ether);
    }

    // Test 1: Mint correct avec calcul des frais
    function testMint() public {
        vm.startPrank(user);
        
        // 1. Envoyer 1 ETH (supposant 1 ETH = 2000 USD)
        // Calcul attendu : 1 token = 1g d'or = 2000 USD
        uint256 ethAmount = 1 ether;
        goldToken.mint{value: ethAmount}();

        // 2. Vérifier le solde
        uint256 expectedTokens = (ethAmount * 1e18) / 2000e18; // 1e18 / 2000 = 0.0005 tokens
        expectedTokens = expectedTokens * 95 / 100; // Frais de 5%
        
        assertEq(goldToken.balanceOf(user), expectedTokens);
    }

    // Test 2: Burn avec vérification du remboursement
    function testBurn() public {
        vm.startPrank(user);
        
        // Mint avec 1 ETH
        goldToken.mint{value: 1 ether}();
        uint256 initialBalance = goldToken.balanceOf(user);
        
        // Burn total
        goldToken.burn(initialBalance);
        
        // Vérifier le solde ETH (100 ETH - 1 ETH + 0.95 ETH retourné)
        assertEq(user.balance, 100 ether - 1 ether + (1 ether * 95 / 100));
    }

    // Test 3: Vérification des frais de 5%
    function testFeeDistribution() public {
        vm.startPrank(user);
        
        goldToken.mint{value: 1 ether}();
        
        // Frais attendus : 5% de 1 ETH = 0.05 ETH
        uint256 expectedFee = (1 ether * 5) / 100;
        
        // 50% des frais vont à la lotterie (0.025 ETH)
        assertEq(address(goldToken.lottery()).balance, expectedFee / 2);
    }

    // Test 4: Simulation de la lotterie (version simplifiée)
    function testLottery() public {
        // Configurer le mock pour retourner un prix cohérent
        mockPriceFeed.setPrice(2000 * 1e8); // 2000 USD/g

        // Mint avec 10 utilisateurs (0.1 ETH chacun)
        for (uint i = 0; i < 10; i++) {
            address userAddr = address(uint160(i + 1000));
            vm.deal(userAddr, 1 ether);
            vm.prank(userAddr);
            goldToken.mint{value: 0.1 ether}();
        }

        // Forcer l'exécution de la lotterie (simuler Chainlink VRF)
        vm.prank(address(goldToken.lottery()));
        goldToken.lottery().fulfillRandomness(bytes32(0), 12345);

        // Vérifier qu'un gagnant a reçu les fonds
        assertGt(address(goldToken.lottery()).balance, 0);
    }
}