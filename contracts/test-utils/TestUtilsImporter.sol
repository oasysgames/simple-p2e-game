// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**
 * @title TestUtilsImporter
 * @dev This file ensures all necessary contracts and interfaces are compiled
 *      when using Hardhat toolchain, as Hardhat may not detect all dependencies
 *      automatically like Foundry does.
 */

// Balancer V2 Core Interfaces
import {IAsset} from "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IBasePoolFactory} from
    "@balancer-labs/v2-interfaces/contracts/pool-utils/IBasePoolFactory.sol";

// SBTSale
import {IVaultPool} from "../interfaces/IVaultPool.sol";
import {IPOAS} from "../interfaces/IPOAS.sol";
import {IPOASMinter} from "../interfaces/IPOASMinter.sol";
import {ISBTSale} from "../interfaces/ISBTSale.sol";
import {IWOAS} from "../interfaces/IWOAS.sol";
import {ISBTSaleERC721} from "../interfaces/ISBTSaleERC721.sol";
import {SBTSale} from "../SBTSale.sol";
import {SoulboundToken} from "../SoulboundToken.sol";

// Test utilities
import {IBalancerV2Helper} from "./interfaces/IBalancerV2Helper.sol";
import {IMockSMP} from "./interfaces/IMockSMP.sol";
import {IWeightedPoolFactory} from "./interfaces/IWeightedPoolFactory.sol";
import {VaultDeployer, IMinimumAuthorizer} from "./deployers/VaultDeployer.sol";
import {WeightedPoolFactoryDeployer} from "./deployers/WeightedPoolFactoryDeployer.sol";
import {BalancerV2HelperDeployer} from "./deployers/BalancerV2HelperDeployer.sol";
import {MockSBTSaleERC721} from "./MockSBTSaleERC721.sol";
import {MockPOAS} from "./MockPOAS.sol";
import {MockPOASMinter} from "./MockPOASMinter.sol";
import {MockSMP} from "./MockSMPv8.sol";
