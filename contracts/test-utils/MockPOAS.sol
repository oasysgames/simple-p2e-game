// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title MockPOAS - Mock version of the pOAS token for testing purposes
 * @dev https://github.com/oasysgames/p-oas-contract/blob/v1.0.4/src/POAS.sol
 */
contract MockPOAS is ERC20Burnable {
    event Paid(address indexed from, address indexed recipient, uint256 amount);

    error POASPaymentError(string message);

    address public immutable mockMinter;

    constructor(address _mockMinter) ERC20("pOAS", "POAS") {
        mockMinter = _mockMinter;
    }

    function mint(address account, uint256 amount) external payable {
        // Note: The actual code does not validate msg.value
        require(msg.sender == mockMinter, "MockPOAS: Invalid minter");
        _mint(account, amount);
    }

    function transfer(address, uint256) public virtual override returns (bool) {
        revert POASPaymentError("cannot pay with transfer");
    }

    function transferFrom(address from, address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        if (from == msg.sender) {
            revert POASPaymentError("cannot pay from self");
        }
        if (amount == 0) {
            revert POASPaymentError("amount is zero");
        }
        if (amount > address(this).balance) {
            revert POASPaymentError("insufficient collateral");
        }

        // The sender must have been previously approved by 'from'.
        // The sender doesn't need to have RECIPIENT_ROLE, providing flexibility for the app side.
        burnFrom(from, amount);

        (bool success,) = recipient.call{value: amount}("");
        if (!success) {
            revert POASPaymentError("transfer failed to recipient");
        }

        emit Paid(from, recipient, amount);
        return true;
    }
}
