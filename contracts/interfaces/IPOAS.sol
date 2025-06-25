// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

// lib/openzeppelin-contracts-upgradeable/contracts/access/IAccessControlUpgradeable.sol

// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

/**
 * @dev This file is based on the original IPOAS.sol from:
 * https://github.com/oasysgames/p-oas-contract/blob/v1.0.4/src/interfaces/IPOAS.sol
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(
        bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole
    );

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// lib/openzeppelin-contracts-upgradeable/contracts/access/IAccessControlEnumerableUpgradeable.sol

// OpenZeppelin Contracts v4.4.1 (access/IAccessControlEnumerable.sol)

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerableUpgradeable is IAccessControlUpgradeable {
    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

// src/interfaces/IPOAS.sol

/**
 * @title IPOAS - Interface for pOAS Token
 *
 * The pOAS token is a specialized ERC20 token with additional features:
 * - Role-based access control (Admin, Operator, Recipient)
 * - Collateral-backed payments
 * - Minting and burning with tracking
 * - Recipient management
 */
interface IPOAS is IAccessControlEnumerableUpgradeable, IERC20Upgradeable {
    /**
     * @dev Emitted when tokens are minted to an account
     * @param to The address receiving the minted tokens
     * @param amount The number of tokens minted
     */
    event Minted(address indexed to, uint256 amount);

    /**
     * @dev Emitted when tokens are burned from an account
     * @param from The address burning the tokens
     * @param amount The number of tokens burned
     */
    event Burned(address indexed from, uint256 amount);

    /**
     * @dev Emitted when a payment is made
     * @param from The address paying (burning tokens)
     * @param recipient The address receiving the payment
     * @param amount The payment amount
     */
    event Paid(address indexed from, address indexed recipient, uint256 amount);

    /**
     * @dev Emitted when collateral is deposited into the contract
     * @param amount The amount of collateral deposited
     */
    event CollateralDeposited(uint256 amount);

    /**
     * @dev Emitted when collateral is withdrawn from the contract
     * @param to The address receiving the withdrawn collateral
     * @param amount The amount of collateral withdrawn
     */
    event CollateralWithdrawn(address indexed to, uint256 amount);

    /**
     * @dev Emitted when a new payment recipient is added
     * @param recipient The address of the new recipient
     * @param name The name of the recipient
     * @param desc A description of the recipient
     */
    event RecipientAdded(address indexed recipient, string name, string desc);

    /**
     * @dev Emitted when a payment recipient is removed
     * @param recipient The address of the removed recipient
     * @param name The name of the removed recipient
     */
    event RecipientRemoved(address indexed recipient, string name);

    /**
     * @dev Generic error for general contract failures
     * @param message A descriptive error message
     */
    error POASError(string message);

    /**
     * @dev Error specific to token minting operations
     * @param message A descriptive error message related to minting
     */
    error POASMintError(string message);

    /**
     * @dev Error specific to token burning operations
     * @param message A descriptive error message related to burning
     */
    error POASBurnError(string message);

    /**
     * @dev Error specific to collateral withdrawal operations
     * @param message A descriptive error message related to collateral withdrawal
     */
    error POASWithdrawCollateralError(string message);

    /**
     * @dev Error specific to payment operations
     * @param message A descriptive error message related to payments
     */
    error POASPaymentError(string message);

    /**
     * @dev Error specific to recipient addition operations
     * @param message A descriptive error message related to adding recipients
     */
    error POASAddRecipientError(string message);

    /**
     * @dev Error specific to recipient removal operations
     * @param message A descriptive error message related to removing recipients
     */
    error POASRemoveRecipientError(string message);

    /**
     * @dev Returns the OPERATOR_ROLE
     */
    function OPERATOR_ROLE() external view returns (bytes32);

    /**
     * @dev Returns the RECIPIENT_ROLE
     */
    function RECIPIENT_ROLE() external view returns (bytes32);

    /**
     * @dev Total minted amount
     *      Unlike totalSupply, this does not decrease when tokens are burned
     */
    function totalMinted() external view returns (uint256);

    /**
     * @dev Total burned amount
     */
    function totalBurned() external view returns (uint256);

    /**
     * @dev Mint tokens
     * @param account The recipient address
     * @param amount The amount to mint
     */
    function mint(address account, uint256 amount) external;

    /**
     * @dev Mint tokens to multiple accounts
     * @param accounts List of recipient addresses
     * @param amounts List of amounts to mint
     */
    function bulkMint(address[] calldata accounts, uint256[] calldata amounts) external;

    /**
     * @dev Burn tokens
     * @param amount The amount to burn
     */
    function burn(uint256 amount) external;

    /**
     * @dev Make a payment
     *      Overrides `ERC20.transferFrom`
     * @param from The payer
     * @param recipient The payment recipient
     * @param amount The payment amount
     */
    function transferFrom(address from, address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Add collateral into the contract
     */
    function depositCollateral() external payable;

    /**
     * @dev Withdraw collateral from the contract
     * @param amount The amount to withdraw
     */
    function withdrawCollateral(uint256 amount) external;

    /**
     * @dev Withdraw collateral from the contract to a specific address
     * @param to The withdrawal address
     * @param amount The amount to withdraw
     */
    function withdrawCollateralTo(address to, uint256 amount) external;

    /**
     * @dev Returns the ratio of collateral to token totalSupply in 1e18 format
     *      1 ether (1e18) represents 100%, 0.5 ether (5e17) represents 50%
     * @return ratio The collateral ratio in 1e18 format
     */
    function getCollateralRatio() external view returns (uint256 ratio);

    /**
     * @dev Add Recipients
     *      Adding through `AccessControl.grantRole` will result in an error
     * @param recipients List of recipient addresses to add
     * @param names List of names
     * @param descriptions List of descriptions
     */
    function addRecipients(
        address[] calldata recipients,
        string[] calldata names,
        string[] calldata descriptions
    ) external;

    /**
     * @dev Remove Recipients
     *      This is a syntactic sugar for `AccessControl.revokeRole`
     * @param recipients List of recipient addresses to remove
     */
    function removeRecipients(address[] calldata recipients) external;

    /**
     * @dev Returns the number of Recipients
     * @return count The number of registered Recipients
     */
    function getRecipientCount() external view returns (uint256);

    /**
     * @dev Returns a Recipient
     * @param recipient The Recipient address
     * @return name The name
     * @return description The description
     */
    function getRecipient(address recipient)
        external
        view
        returns (string memory name, string memory description);

    /**
     * @dev Returns a Recipient in JSON format
     * @param recipient The Recipient address
     * @return json The Recipient in JSON format
     */
    function getRecipientJSON(address recipient) external view returns (string memory json);

    /**
     * @dev Returns all Recipients
     * @return recipients List of Recipient addresses
     * @return names List of names
     * @return descriptions List of descriptions
     */
    function getRecipients()
        external
        view
        returns (address[] memory recipients, string[] memory names, string[] memory descriptions);

    /**
     * @dev Returns all Recipients in JSON format
     * @return json List of Recipients in JSON format
     */
    function getRecipientsJSON() external view returns (string memory json);

    /**
     * @dev Returns Recipients with pagination
     * @param cursor Cursor for pagination
     * @param size Size for pagination
     * @return recipients List of Recipient addresses
     * @return names List of names
     * @return descriptions List of descriptions
     * @return nextCursor Next cursor for pagination
     */
    function getRecipientsPaginated(uint256 cursor, uint256 size)
        external
        view
        returns (
            address[] memory recipients,
            string[] memory names,
            string[] memory descriptions,
            uint256 nextCursor
        );

    /**
     * @dev Returns Recipients with pagination in JSON format
     * @param cursor Cursor for pagination
     * @param size Size for pagination
     * @return json List of Recipients in JSON format
     * @return nextCursor Next cursor for pagination
     */
    function getRecipientsJSONPaginated(uint256 cursor, uint256 size)
        external
        view
        returns (string memory json, uint256 nextCursor);
}
