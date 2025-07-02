// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

/**
 * @dev This file is based on the original IPOAS.sol from:
 * https://github.com/oasysgames/p-oas-contract/blob/v1.0.4/src/samples/MinterSample.sol
 */
interface IPOASMinter {
    /// @dev Interface instance for interacting with the POAS token contract.
    function poas() external view returns (address);

    /**
     * @dev Mints POAS tokens for a specified account
     * @param account The address that will receive the minted tokens
     * @param depositAmount The amount of OAS to deposit (in wei)
     * @notice The caller must send exactly the OAS amount that matches the token amount
     * @notice Contract must have OPERATOR_ROLE to execute this function
     */
    function mint(address account, uint256 depositAmount) external payable;
}
