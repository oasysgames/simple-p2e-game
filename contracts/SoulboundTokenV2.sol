// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SoulboundToken} from "./SoulboundToken.sol";

/// @title SoulboundTokenV2
/// @notice Upgrade implementation adding automatic token ID assignment
contract SoulboundTokenV2 is SoulboundToken {
    uint256 private _nextTokenId;

    function version() external pure returns (uint256) {
        return 2;
    }

    /// @notice Generate the next available token ID
    function assignTokenId() external returns (uint256 tokenId) {
        tokenId = _assignTokenId();
    }

    /// @dev Assigns the next token ID skipping already minted ones
    function _assignTokenId() internal returns (uint256 tokenId) {
        do {
            tokenId = ++_nextTokenId;
        } while (_ownerOf(tokenId) != address(0));
    }
}
