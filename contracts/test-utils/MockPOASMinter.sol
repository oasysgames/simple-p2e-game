// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import {MockPOAS} from "./MockPOAS.sol";
import {IPOASMinter} from "../interfaces/IPOASMinter.sol";

/**
 * @title MockPOASMinter - Mock version of the pOAS minter contract for testing purposes
 * @dev https://github.com/oasysgames/p-oas-contract/blob/v1.0.4/src/POAS.sol
 */
contract MockPOASMinter is IPOASMinter {
    /// @inheritdoc IPOASMinter
    address public immutable poas;

    constructor() {
        poas = address(new MockPOAS(address(this)));
    }

    /// @inheritdoc IPOASMinter
    function mint(address account, uint256 amount) external payable {
        require(msg.value == amount, "MockPOASMinter: msg.value mismatch");
        MockPOAS(poas).mint{value: amount}(account, amount);
    }
}
