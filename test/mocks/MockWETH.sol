// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@chainlink-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockWETH
 * @notice A mock implementation of Wrapped Ether (WETH) for testing purposes.
 * @dev Users can deposit Ether to mint WETH tokens and withdraw Ether by burning WETH tokens.
 */
contract MockWETH is ERC20 {

    /**
     * @notice A test function used for coverage purposes.
     */
    function testA() public {} // forge coverage ignore-file

    /**
     * @notice Constructor that initializes the ERC20 token with a name and symbol.
     */
    constructor() ERC20("Mock WETH", "mWETH") {}

    /**
     * @notice Deposits Ether and mints an equivalent amount of WETH tokens to the sender.
     * @dev The minted amount is equal to the amount of Ether sent.
     */
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    /**
     * @notice Withdraws Ether by burning a specified amount of WETH tokens.
     * @param amount The amount of WETH tokens to burn in order to withdraw Ether.
     * @dev Reverts if the sender does not have enough WETH tokens.
     */
    function withdraw(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient WETH balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    /**
     * @notice Fallback function that automatically calls deposit() when Ether is sent directly.
     */
    receive() external payable {
        deposit();
    }
}