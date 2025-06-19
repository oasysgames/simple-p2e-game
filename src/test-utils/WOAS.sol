// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import {ERC20} from "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";

/**
 * @title WOAS
 * @dev Wrapped OAS token for BalancerV2 pool compatibility
 *      Allows OAS (native currency) to be used in ERC20-based pools
 */
contract WOAS is ERC20 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    constructor() ERC20("Wrapped OAS", "WOAS") {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        require(balanceOf(msg.sender) >= wad, "Insufficient balance");
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
}
