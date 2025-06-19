// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

/**
 * @title IMockSMP
 * @notice Interface for the MockSMP token used in testing
 */
interface IMockSMP is IERC20 {
    /**
     * @notice Mint tokens to a specified address
     * @param to Address to receive the minted tokens
     * @param amount Number of tokens to mint (in wei, 18 decimals)
     */
    function mint(address to, uint256 amount) external;
}
