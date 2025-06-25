/**
 * @fileoverview Test deployment utilities for SimpleP2E game contracts
 * @description This module provides comprehensive helper functions for deploying and configuring
 *              the complete SimpleP2E ecosystem. It includes Balancer V2 infrastructure deployment,
 *              mock token creation, liquidity pool setup, and P2E game contract deployment.
 *
 *              Key Features:
 *              - Deterministic contract deployments using CREATE2
 *              - Automated Balancer V2 ecosystem setup (Vault, Pool Factory, Helper)
 *              - Mock token deployment (SMP, POAS) with proper permissions
 *              - Liquidity pool creation and initial funding
 *              - SimpleP2E contract deployment with configurable parameters
 *              - Mock NFT contract factory for testing scenarios
 */

import hre from "hardhat";
import { ContractTypesMap } from "hardhat/types/artifacts";
import {
  keccak256,
  stringToBytes,
  parseEther,
  Address,
  fromHex,
  zeroAddress,
  toHex,
} from "viem";

/**
 * @notice Fixed deployer address used across all test deployments
 * @dev This address is consistently used to ensure deterministic deployments
 *      and simplified permission management in test environments.
 *      Using a fixed address allows for predictable contract addresses via CREATE2.
 */
const deployer: Address = "0x62AD94a07F5cC3E86BCFC7eCb3fE93c980404efF";

/**
 * @notice Private key corresponding to the deployer address
 * @dev This private key is used for signing transactions in test environments.
 *      WARNING: This is a test-only key and should NEVER be used in production.
 */
const privateKey =
  "0x728e4097a6eef29d3056fcce31b6d038ab3492ddc080e8eabea13ddb049b40de";

/**
 * @notice Sets up the deployer account with necessary balance and permissions
 * @dev Creates a wallet client, ensures adequate funding, and provides standardized
 *      deployment and transaction options. This function handles the initial setup
 *      required for all contract deployments and interactions.
 * @returns Object containing wallet client and standardized option objects
 * @returns wallet - Wallet client for the deployer address
 * @returns deployOpts - Standard options for contract deployments
 * @returns writeOpts - Standard options for contract write operations
 */
const setupDeployer = async () => {
  // Create wallet client for the deployer address
  const wallet = await hre.viem.getWalletClient(deployer);

  // Check if deployer account needs funding
  const client = await hre.viem.getPublicClient();
  const currentBalance = await client.getBalance({ address: deployer });
  const isAccountFunded = currentBalance !== 0n;

  // Fund the deployer account if it has zero balance
  if (!isAccountFunded) {
    // Enable account impersonation for balance setting
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [deployer],
    });

    // Set deployer balance to 10,000 ETH for testing purposes
    await hre.network.provider.request({
      method: "hardhat_setBalance",
      params: [deployer, toHex(parseEther("10000"))],
    });
  }

  // Standard deployment options that include the wallet client
  const deployOpts = { client: { wallet } };

  // Standard write operation options that specify the account
  const writeOpts = { account: deployer };

  return { wallet, deployOpts, writeOpts };
};

/**
 * @notice Deploys the complete Balancer V2 ecosystem for testing
 * @dev Deploys all necessary Balancer V2 infrastructure contracts in the correct order:
 *      1. VaultDeployer - Deploys the main Vault contract and WOAS token
 *      2. WeightedPoolFactoryDeployer - Creates the factory for weighted pools
 *      3. BalancerV2HelperDeployer - Deploys helper contract for simplified interactions
 *      4. Grants relayer permissions to the helper for vault operations
 *
 *      Uses deterministic CREATE2 salt for consistent deployment addresses across test runs.
 *      This ensures that the same contract addresses are used in repeated test executions.
 *
 * @param params Optional configuration parameters for deployment
 * @param params.salt Custom salt string for CREATE2 deployment (default: "SALT")
 *                   Different salts result in different contract addresses
 *
 * @returns Object containing all deployed Balancer V2 contract instances
 * @returns vault - The main Balancer V2 Vault contract for asset management
 * @returns poolFactory - Factory contract for creating weighted pools
 * @returns bv2helper - Helper contract for simplified pool operations
 * @returns woas - Wrapped OAS token contract for native currency support
 */
export const deployBalancerV2 = async (params?: { salt?: string }) => {
  const { deployContract, getContractAt } = hre.viem;
  const { deployOpts, writeOpts } = await setupDeployer();

  // Use deterministic salt for consistent deployment addresses across test runs
  const salt = keccak256(stringToBytes(params?.salt || "SALT"));

  // Deploy Balancer V2 Vault, Authorizer, and WOAS contracts
  const vaultDeployer = await deployContract(
    "VaultDeployer",
    [salt],
    deployOpts
  );
  const vault = await getContractAt("IVault", await vaultDeployer.read.vault());

  // Deploy WeightedPoolFactory for creating weighted pools
  const poolFactoryDeployer = await deployContract(
    "WeightedPoolFactoryDeployer",
    [salt, vault.address],
    deployOpts
  );
  const poolFactory = await getContractAt(
    "IWeightedPoolFactory",
    await poolFactoryDeployer.read.poolFactory()
  );

  // Deploy BalancerV2Helper for simplified pool interactions
  const helperDeployer = await deployContract(
    "BalancerV2HelperDeployer",
    [salt, vault.address, poolFactory.address],
    deployOpts
  );
  const bv2helper = await getContractAt(
    "IBalancerV2Helper",
    await helperDeployer.read.helper()
  );

  // Grant relayer permissions to helper contract for vault operations
  await vaultDeployer.write.grantRelayerRolesToHelper(
    [bv2helper.address],
    writeOpts
  );

  const woas = await getContractAt("IWOAS", await vaultDeployer.read.woas());

  return { vault, poolFactory, bv2helper, woas };
};

/**
 * @notice Deploys the complete SimpleP2E ecosystem including all dependencies
 * @dev Orchestrates the deployment of the entire P2E game testing environment:
 *
 *      Phase 1 - Infrastructure Setup:
 *      - Deploys complete Balancer V2 ecosystem via deployBalancerV2()
 *      - Creates mock SMP and POAS tokens for testing
 *
 *      Phase 2 - Pool Creation:
 *      - Creates WOAS-SMP weighted pool (50/50 allocation)
 *      - Configures zero swap fees for testing convenience
 *      - Retrieves pool address from creation events
 *
 *      Phase 3 - P2E Contract Deployment:
 *      - Deploys SimpleP2E contract with configurable parameters
 *      - Sets up burn ratios, liquidity ratios, and price configurations
 *
 *      Phase 4 - Initial Liquidity Setup:
 *      - Mints and deposits WOAS tokens from provided ETH
 *      - Mints SMP tokens to the deployer account
 *      - Adds initial liquidity to the WOAS-SMP pool
 *      - Ensures proper token ordering (Balancer requires sorted addresses)
 *
 * @param params Configuration object for ecosystem deployment
 * @param params.initialLiquidity Initial liquidity amounts for the WOAS-SMP pool
 * @param params.initialLiquidity.woas Amount of WOAS to add to pool (in wei)
 * @param params.initialLiquidity.smp Amount of SMP to add to pool (in wei)
 * @param params.p2e SimpleP2E contract configuration parameters
 * @param params.p2e.lpRecipient Address to receive LP tokens from protocol operations
 * @param params.p2e.revenueRecipient Address to receive revenue from token sales
 * @param params.p2e.smpBasePrice Price per NFT in SMP tokens (default: 50 SMP)
 * @param params.p2e.smpBurnRatio Percentage of SMP to burn (default: 50% = 5000 basis points)
 * @param params.p2e.smpLiquidityRatio Percentage of SMP for liquidity (default: 40% = 4000 basis points)
 *
 * @returns Comprehensive object containing all deployed contracts and utilities
 * @returns nativeOAS - Zero address representing native OAS in transactions
 * @returns woas - Wrapped OAS token contract for ERC20 compatibility
 * @returns poas - Mock POAS token contract for testing payments
 * @returns smp - Mock SMP token contract for testing game economy
 * @returns pool - WOAS-SMP liquidity pool contract
 * @returns p2e - Deployed SimpleP2E game contract
 */
export const deploySimpleP2E = async (params: {
  initialLiquidity: {
    woas: bigint;
    smp: bigint;
  };
  p2e: {
    lpRecipient: `0x${string}`;
    revenueRecipient: `0x${string}`;
    smpBasePrice?: bigint;
    smpBurnRatio?: bigint;
    smpLiquidityRatio?: bigint;
  };
}) => {
  const { deployContract, getContractAt } = hre.viem;
  const { deployOpts, writeOpts } = await setupDeployer();
  const { vault, poolFactory, bv2helper, woas } = await deployBalancerV2();

  // Deploy mock tokens for testing
  const nativeOAS = zeroAddress; // Native OAS represented as zero address
  const smp = await deployContract("MockSMP", [], deployOpts);
  const poas = await deployContract("MockPOAS", [], deployOpts);

  // Create WOAS-SMP weighted pool with 50/50 allocation
  await bv2helper.write.createPool(
    [
      {
        owner: deployer,
        name: "WOAS-SMP",
        symbol: "WOAS-SMP",
        swapFeePercentage: 0n, // Default: 0.0001%
        tokenA: woas.address,
        tokenB: smp.address,
      },
    ],
    writeOpts
  );

  // Get the created pool address from events
  const { pool: poolAddr } = (await bv2helper.getEvents.PoolCreated())[0].args;
  const pool = await getContractAt("IVaultPool", poolAddr!);

  const p2e = await deployContract(
    "SimpleP2E",
    [
      poas.address,
      pool.address,
      params.p2e.lpRecipient,
      params.p2e.revenueRecipient,
      params.p2e?.smpBasePrice ?? parseEther("50"), // Default: 50 SMP per NFT
      params.p2e?.smpBurnRatio ?? 5000n, // Default: 50% burn ratio
      params.p2e?.smpLiquidityRatio ?? 4000n, // Default: 40% liquidity ratio
    ],
    deployOpts
  );

  // Mint WOAS by depositing ETH and approve Vault for liquidity provision
  await woas.write.deposit({
    ...writeOpts,
    value: params.initialLiquidity.woas,
  });
  await woas.write.approve(
    [vault.address, params.initialLiquidity.woas],
    writeOpts
  );

  // Mint SMP tokens and approve Vault for liquidity provision
  await smp.write.mint([deployer, params.initialLiquidity.smp], writeOpts);
  await smp.write.approve(
    [vault.address, params.initialLiquidity.smp],
    writeOpts
  );

  // Prepare tokens in correct order (Balancer requires sorted addresses)
  const tokens: [Address, Address] = [woas.address, smp.address];
  const amounts: [bigint, bigint] = [
    params.initialLiquidity.woas,
    params.initialLiquidity.smp,
  ];
  if (fromHex(woas.address, "bigint") > fromHex(smp.address, "bigint")) {
    tokens.reverse();
    amounts.reverse();
  }

  // Grant relayer permissions to helper for Vault operations
  await vault.write.setRelayerApproval(
    [deployer, bv2helper.address, true],
    writeOpts
  );

  // Add initial liquidity to WOAS-SMP pool using sorted tokens and amounts
  await bv2helper.write.addInitialLiquidity(
    [pool.address, deployer, deployer, tokens, amounts],
    writeOpts
  );

  return {
    vault,
    poolFactory,
    bv2helper,
    woas,
    nativeOAS,
    poas,
    smp,
    pool,
    p2e,
  };
};

/**
 * @notice Deploys multiple mock NFT contracts for testing P2E scenarios
 * @dev Creates the specified number of MockSimpleP2EERC721 contracts with unique
 *      names and symbols. Each NFT contract is configured to only allow minting
 *      from the specified SimpleP2E contract, ensuring proper access control.
 *
 *      Generated contracts will have:
 *      - Sequential names: "NFT1", "NFT2", "NFT3", etc.
 *      - Sequential symbols: "NFT1", "NFT2", "NFT3", etc.
 *      - Minting permission restricted to the provided SimpleP2E address
 *
 * @param simpleP2E Address of the SimpleP2E contract that can mint these NFTs
 * @param count Number of NFT contracts to deploy (must be > 0)
 * @returns Array of deployed NFT contract instances, indexed from 0
 *
 * @example
 * // Deploy 3 NFT contracts for testing
 * const nfts = await deployMockNFTs(p2eAddress, 3);
 * // Results: [NFT1, NFT2, NFT3] contracts
 */
export const deployMockNFTs = async (
  simpleP2E: `0x${string}`,
  count: number
) => {
  const nfts: ContractTypesMap["MockSimpleP2EERC721"][] = [];
  for (let i = 0; i < count; i++) {
    const nft = await hre.viem.deployContract("MockSimpleP2EERC721", [
      `NFT${i + 1}`,
      `NFT${i + 1}`,
      simpleP2E,
    ]);
    nfts.push(nft);
  }
  return nfts;
};
