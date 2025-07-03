// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {AccessControlUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ISBTSaleERC721} from "./interfaces/ISBTSaleERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title SoulboundToken
 * @notice Minimal ERC721 Soulbound Token implementation
 * @dev Tokens are non-transferable and the contract is upgradeable.
 */
contract SoulboundToken is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    ISBTSaleERC721
{
    /// @dev Error for invalid owner
    error InvalidOwner();

    /// @dev Revert when attempting a prohibited transfer or approval
    error Soulbound();

    /// @dev Error for failed to assign token ID
    error FailedToAssignTokenId();

    /// @notice Role identifier for accounts allowed to mint
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Base URI for token metadata
    string private _baseTokenURI;

    /// @dev Token mint timestamp mapping
    mapping(uint256 => uint256) private _mintedAt;

    /// @dev Counter for token IDs
    ///      NFT ID starts from 0
    uint256 private _nextTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the SBT contract
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param baseURI_ Initial base URI for token metadata
     * @param owner_ Initial contract owner and admin
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address owner_
    ) public initializer {
        if (owner_ == address(0)) {
            revert InvalidOwner();
        }

        __ERC721_init(name_, symbol_);
        __ERC721Burnable_init();
        __AccessControl_init();

        _baseTokenURI = baseURI_;

        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(MINTER_ROLE, owner_);
    }

    /// @notice Mint a new token with auto-incrementing ID
    function mint(address to)
        external
        override(ISBTSaleERC721)
        onlyRole(MINTER_ROLE)
        returns (uint256 tokenId)
    {
        tokenId = _assignTokenId();
        _safeMint(to, tokenId);
        _mintedAt[tokenId] = block.timestamp;
        return tokenId;
    }

    /**
     * @notice Mint a new SBT
     * @param to Recipient address
     * @param tokenId Token id to mint
     * @param data Additional data to pass to the recipient
     */
    function safeMint(address to, uint256 tokenId, bytes memory data)
        external
        onlyRole(MINTER_ROLE)
    {
        _safeMint(to, tokenId, data);
        _mintedAt[tokenId] = block.timestamp;
    }

    /// @notice Burn an existing SBT
    /// @param tokenId Token id to burn
    function burn(uint256 tokenId) public override(ERC721BurnableUpgradeable) {
        super.burn(tokenId);
        delete _mintedAt[tokenId];
    }

    /// @notice Update base URI for token metadata
    function setBaseURI(string memory newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
    }

    /// @notice View mint timestamp of a token
    function mintTimeOf(uint256 tokenId) external view returns (uint256) {
        return _mintedAt[tokenId];
    }

    /// @dev Returns the base URI for all tokens
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @inheritdoc ERC721Upgradeable
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // Implement custom logic here if needed
        return super.tokenURI(tokenId);
    }

    /// @inheritdoc ERC721Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @dev Assigns a unique token ID by incrementing _nextTokenId and retrying if taken
    function _assignTokenId() internal virtual returns (uint256 tokenId) {
        // Prevent infinite loops
        uint256 currentTokenId = _nextTokenId;
        uint256 maxAttempts = 1024; // NOTE: You can change this value by upgrading this contract
        uint256 i = 0;
        while (i < maxAttempts) {
            if (_ownerOf(currentTokenId) == address(0)) {
                // Token ID is available, update storage and return
                _nextTokenId = currentTokenId + 1;
                return currentTokenId;
            }
            unchecked {
                ++currentTokenId;
                ++i;
            }
        }
        revert FailedToAssignTokenId();
    }

    // ---------------------------------------------------------------------
    // Non-transferable overrides
    // ---------------------------------------------------------------------

    /// @dev Override approval to prevent any approvals
    function approve(address, uint256) public pure override(ERC721Upgradeable, IERC721) {
        revert Soulbound();
    }

    /// @dev Override setApprovalForAll to prevent any approvals
    function setApprovalForAll(address, bool) public pure override(ERC721Upgradeable, IERC721) {
        revert Soulbound();
    }

    /// @dev Override transferFrom to prevent any transfers
    function transferFrom(address, address, uint256)
        public
        pure
        override(ERC721Upgradeable, IERC721)
    {
        revert Soulbound();
    }

    /// @dev Override the internal _safeTransfer function to prevent any transfers
    function _safeTransfer(address, address, uint256, bytes memory) internal pure override {
        revert Soulbound();
    }
}
