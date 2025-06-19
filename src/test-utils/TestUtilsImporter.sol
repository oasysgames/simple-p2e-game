// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

/**
 * @title TestUtilsImporter
 * @dev This file ensures all necessary contracts and interfaces are compiled
 *      when using Hardhat toolchain, as Hardhat may not detect all dependencies
 *      automatically like Foundry does.
 */

// Balancer V2 Core Interfaces
import {IAsset} from "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IBasePool} from "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import {IBasePoolFactory} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IBasePoolFactory.sol";

// Local Interfaces
import {IBalancerV2Helper} from "./interfaces/IBalancerV2Helper.sol";
import {IWeightedPoolFactory} from "./interfaces/IWeightedPoolFactory.sol";
import {IWOAS} from "./interfaces/IWOAS.sol";
import {IMockSMP} from "./interfaces/IMockSMP.sol";

// Deployment Utilities
import {VaultDeployer, IMinimumAuthorizer} from "./deployers/VaultDeployer.sol";
import {WeightedPoolFactoryDeployer} from "./deployers/WeightedPoolFactoryDeployer.sol";
import {BalancerV2HelperDeployer} from "./deployers/BalancerV2HelperDeployer.sol";
