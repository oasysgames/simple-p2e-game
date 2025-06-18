// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {ERC20} from "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";

/**
 * @title MockSMP
 * @dev TODO
 */
contract MockSMP is ERC20 {
    constructor() ERC20("SMP", "SMP") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
