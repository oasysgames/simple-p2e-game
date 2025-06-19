// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import {IWETH} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/misc/IWETH.sol";

/**
 * @title IWOAS
 * @notice Interface for Wrapped OAS (WOAS) token
 * @dev WOAS follows the same pattern as WETH but for OAS (Oasys) native token.
 *      This allows native OAS to be used as an ERC20 token in DeFi protocols.
 *      Inherited functions from IWETH:
 *      - deposit() payable: Wrap native OAS into WOAS tokens
 *      - withdraw(uint256 amount): Unwrap WOAS tokens back to native OAS
 *      - Standard ERC20 functions: transfer, approve, balanceOf, etc.
 */
interface IWOAS is IWETH {}
