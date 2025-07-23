// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title ISBTSaleERC721
 * @dev Interface for ERC721 tokens that can be minted by SBTSale contract
 */
interface ISBTSaleERC721 is IERC721 {
    /**
     * @dev Mint a new NFT to the specified address
     * @param to Address to mint the NFT to
     * @return tokenId The ID of the newly minted token
     */
    function mint(address to) external returns (uint256 tokenId);
}
