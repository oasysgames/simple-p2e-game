// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

interface IMockSMP is IERC20 {
    function mint(address to, uint256 amount) external;
}
