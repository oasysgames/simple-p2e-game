// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {AccessControlUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title SoulboundToken
 * @notice Minimal ERC721 Soulbound Token implementation
 * @dev Tokens are non-transferable and the contract is upgradeable.
 */
contract SoulboundToken is Initializable, ERC721Upgradeable, AccessControlUpgradeable {
    /// @dev Revert when attempting a prohibited transfer or approval
    error Soulbound();

    /// @notice Role identifier for accounts allowed to mint
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Error for invalid expiration timestamp
    error InvalidExpiration();

    /// @dev Error for unauthorized actions
    error Unauthorized();

    /// @dev Base URI for token metadata
    string private _baseTokenURI;

    /// @dev Token expiration timestamp mapping
    mapping(uint256 => uint256) private _expiresAt;

    /// @notice Default expiration duration in seconds
    uint256 private _defaultExpiration;

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
     * @param defaultExpiration_ Default expiration duration in seconds
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address owner_,
        uint256 defaultExpiration_
    ) public initializer {
        __ERC721_init(name_, symbol_);
        __AccessControl_init();

        _baseTokenURI = baseURI_;
        _defaultExpiration = defaultExpiration_;

        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(MINTER_ROLE, owner_);
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
        _expiresAt[tokenId] = block.timestamp + _defaultExpiration;
    }

    /**
     * @notice Mint with custom expiration timestamp
     * @param to Recipient address
     * @param tokenId Token id to mint
     * @param expiration Unix timestamp of expiration
     */
    function safeMintWithExpiration(
        address to,
        uint256 tokenId,
        uint256 expiration,
        bytes memory data
    ) external onlyRole(MINTER_ROLE) {
        if (expiration <= block.timestamp) {
            revert InvalidExpiration();
        }
        _safeMint(to, tokenId, data);
        _expiresAt[tokenId] = expiration;
    }

    /// @notice Burn an existing SBT
    /// @param tokenId Token id to burn
    function burn(uint256 tokenId) external {
        if (msg.sender != ownerOf(tokenId)) {
            revert Unauthorized();
        }
        _burn(tokenId);
        delete _expiresAt[tokenId];
    }

    /// @notice Update base URI for token metadata
    function setBaseURI(string memory newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
    }

    /// @notice Update default expiration duration
    function setDefaultExpiration(uint256 newDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _defaultExpiration = newDuration;
    }

    /// @notice View expiration timestamp of a token
    function expirationOf(uint256 tokenId) external view returns (uint256) {
        return _expiresAt[tokenId];
    }

    /// @notice Check if a token is expired
    function isExpired(uint256 tokenId) external view returns (bool) {
        return _expiresAt[tokenId] < block.timestamp;
    }

    /// @dev Returns the base URI for all tokens
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @inheritdoc ERC721Upgradeable
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string.concat(_baseTokenURI, Strings.toString(tokenId));
    }

    /// @inheritdoc ERC721Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ---------------------------------------------------------------------
    // Non-transferable overrides
    // ---------------------------------------------------------------------

    /// @dev Override approval to prevent any approvals
    function approve(address, uint256) public pure override {
        revert Soulbound();
    }

    /// @dev Override setApprovalForAll to prevent any approvals
    function setApprovalForAll(address, bool) public pure override {
        revert Soulbound();
    }

    /// @dev Override transferFrom to prevent any transfers
    function transferFrom(address, address, uint256) public pure override {
        revert Soulbound();
    }

    /// @dev Override the internal _safeTransfer function to prevent any transfers
    function _safeTransfer(address, address, uint256, bytes memory) internal pure override {
        revert Soulbound();
    }
}
