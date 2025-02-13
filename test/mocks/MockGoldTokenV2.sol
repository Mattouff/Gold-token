// Dans GoldTokenV2.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@contracts/GoldToken.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MockGoldTokenV2 is GoldToken {
    function testA() public{}
    // Nouvelle variable d'état introduite dans V2
    uint256 public newVariable;

    /// @notice Fonction de réinitialisation pour la version 2.
    /// Elle ne peut être appelée qu'une seule fois.
    function initializeV2(uint256 _newValue) external reinitializer(2) {
        newVariable = _newValue;
    }

    function version() public pure returns (string memory) {
        return "v2";
    }
}
