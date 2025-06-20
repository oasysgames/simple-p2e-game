// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title MockSMP
 * @notice Mock version of the SMP token for testing purposes
 * @dev No access control - any caller can mint tokens. This is intentional for testing.
 */
contract MockSMP is ERC20Burnable {
    /**
     * @notice Deploy MockSMP token with "SMP" name and symbol
     */
    constructor() ERC20("SMP", "SMP") {}

    /**
     * @notice Mint tokens to a specified address
     * @param to Address to receive the minted tokens
     * @param amount Number of tokens to mint (in wei, 18 decimals)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
