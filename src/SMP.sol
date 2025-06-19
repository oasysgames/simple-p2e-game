// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SMP
 * @dev Simple ERC20 token for P2E game on Oasys blockchain
 * Users consume SMP to obtain NFTs through the SimpleP2E contract
 */
contract SMP is ERC20 {
    /**
     * @dev Sets the values for {name} and {symbol}
     * @param initialSupply Initial supply to mint to deployer
     */
    constructor(uint256 initialSupply) ERC20("SMP", "SMP") {
        _mint(msg.sender, initialSupply);
    }
}
