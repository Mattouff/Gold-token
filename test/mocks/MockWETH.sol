// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@chainlink-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/ERC20.sol";

contract MockWETH is ERC20 {

    function testA() public {} // forge coverage ignore-file

    constructor() ERC20("Mock WETH", "mWETH") {}

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient WETH balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {
        deposit();
    }
}
