# 🏆 GoldToken Project

<p style="align: center">
    <img src="https://img.shields.io/badge/coverage-100%25-brightgreen?style=flat">
    <img src="https://img.shields.io/github/commit-activity/m/Mattouff/Gold-token">
</p>

<p style="align: center">
    <img src="https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white">
    <img src="https://img.shields.io/badge/Chainlink-Oracle-375BD2?style=for-the-badge&logo=chainlink">
    <img src="https://img.shields.io/badge/OpenZeppelin-Security-4E5EE4?style=for-the-badge&logo=openzeppelin">
    <img src="https://img.shields.io/badge/Ethereum-Mainnet-3C3C3D?style=for-the-badge&logo=ethereum">
    <img src="https://img.shields.io/badge/BSC-Smart_Chain-F0B90B?style=for-the-badge&logo=binance">
</p>

## 📜 Introduction
GoldToken is an ERC20 token indexed to the price of gold, allowing users to mint and burn tokens using ETH. The project includes a cross-chain bridge, a lottery system for fee redistribution, and a price consumer for real-time gold price tracking.

## 📂 Project Structure
```
.
├── foundry.toml
├── README.md
├── remappings.txt
├── script
│   └── Deploy.s.sol
├── src
│   ├── GoldBridge.sol
│   ├── GoldToken.sol
│   ├── Lottery.sol
│   └── PriceConsumer.sol
└── test
    ├── GoldBridge.t.sol
    ├── GoldToken.t.sol
    ├── Lottery.t.sol
    ├── mocks
    │   ├── MockAggregator.sol
    │   ├── MockCCIPRouter.sol
    │   ├── MockCCIPSimulator.sol
    │   ├── MockGoldBridge.sol
    │   ├── MockGoldTokenV2.sol
    │   └── MockWETH.sol
    └── PriceConsumer.t.sol
```

## 🏗️ Components
### 1️⃣ GoldToken.sol 🪙
- ERC20 token representing gold
- Uses UUPS upgradeability
- Minting and burning based on ETH-gold price
- Fee distribution with 50% going to the Lottery contract

### 2️⃣ GoldBridge.sol 🌉
- Cross-chain bridge using Chainlink CCIP
- Locks tokens on source chain and releases on destination chain
- Uses CCIP messages for secure transfers

### 3️⃣ Lottery.sol 🎲
- Fee distribution mechanism for token minting/burning
- Uses Chainlink VRF for randomness
- Picks a random winner when 10 participants accumulate

### 4️⃣ PriceConsumer.sol 📈
- Fetches real-time gold price using Chainlink oracles
- Converts XAU/USD price to ETH
- Essential for mint/burn operations

## 🚀 Deployment
### Using Foundry
```sh
forge script script/Deploy.s.sol --broadcast --rpc-url <NETWORK_URL>
```

## 🛠️ Testing
### Running Tests
```sh
forge test
```

### Specific Contract Test
```sh
forge test --match-contract <Contract>
```

### Specific Test Case
```sh
forge test --match-test <test_function>
```

## 📜 License
This project is licensed under the MIT License.

## 🤝 Contributing
1. Fork the repository 🍴
2. Create a new branch 🛠️
3. Make changes and test 🔬
4. Submit a pull request 🚀

## 📬 Contact
For questions and discussions, open an issue or reach out on Discord!

<div style="display: flex; gap: 10px;">
    <a href="https://discord.com/users/377848185827229700">
    <img src="https://img.shields.io/badge/-Mattouf94-gray?style=for-the-badge&logo=discord&logoColor=white&labelColor=5865F2">
    </a>
    <a href="https://discord.com/users/360420244088422400">
    <img src="https://img.shields.io/badge/-MattLvsr-gray?style=for-the-badge&logo=discord&logoColor=white&labelColor=5865F2">
    </a>
</div>
