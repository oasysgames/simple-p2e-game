// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ISBTSaleERC721} from "../interfaces/ISBTSaleERC721.sol";

/**
 * @title MockSBTSaleERC721
 * @notice Mock implementation of ERC721 token for testing the sale contract
 * @dev This contract implements the ISBTSaleERC721 interface for testing purposes.
 *      Only the designated SBTSale contract can mint tokens.
 */
contract MockSBTSaleERC721 is ISBTSaleERC721, ERC721 {
    /// @dev Counter for generating unique token IDs, starting from 0
    uint256 private _nextTokenId;

    /// @notice Address of the SBTSale contract that is allowed to mint tokens
    address public immutable sbtSale;

    /**
     * @notice Constructor to initialize the NFT collection
     * @param name The name of the NFT collection
     * @param symbol The symbol of the NFT collection
     * @param _sbtSale Address of the SBTSale contract that can mint tokens
     */
    constructor(string memory name, string memory symbol, address _sbtSale)
        ERC721(name, symbol)
    {
        sbtSale = _sbtSale;
    }

    /**
     * @notice Mint a new NFT to the specified address
     * @dev Only the SBTSale contract can call this function
     * @param to Address to mint the NFT to
     * @return tokenId The ID of the newly minted token
     */
    function mint(address to) external returns (uint256 tokenId) {
        require(msg.sender == sbtSale, "Only SBTSale can mint");

        // Generate unique token ID and increment counter
        tokenId = _nextTokenId++;

        // Mint the token to the specified address
        _mint(to, tokenId);
    }
}
