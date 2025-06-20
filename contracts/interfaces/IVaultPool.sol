// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IBasePool} from "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

/// @title IVaultPool
/// @dev This interface extends the original IBasePool interface to
///      include a method for retrieving the associated Vault.
interface IVaultPool is IERC20, IBasePool {
    /// @dev Returns the Vault associated with this pool.
    function getVault() external view returns (IVault);
}
