// SPDX-License-Identifier: MIT
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

// Balancer V2 Interfaces
import {IAsset} from "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import {IBasePool} from "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import {IBasePoolFactory} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IBasePoolFactory.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

// Balancer V2 Core Contracts
import {MockRateProvider} from "@balancer-labs/v2-pool-utils/contracts/test/MockRateProvider.sol";

// Local Interfaces
import {IBalancerV2Helper} from "./interfaces/IBalancerV2Helper.sol";
import {IMockSMP} from "./interfaces/IMockSMP.sol";
import {IWeightedPoolFactory} from "./interfaces/IWeightedPoolFactory.sol";
import {IWOAS} from "./interfaces/IWOAS.sol";

/**
 * @title BalancerV2Helper
 * @notice Test helper interface for Balancer V2 ecosystem
 * @dev Provides liquidity pool creation, liquidity management, and swap functionality
 */
contract BalancerV2Helper is IBalancerV2Helper {
    /// @dev Minimum swap fee percentage as per Balancer V2 protocol specification (0.0001%)
    uint256 constant MIN_SWAP_FEE_PERCENTAGE = 1e12;

    /// @notice The Balancer V2 Vault contract that handles all pool operations
    IVault public immutable vault;

    /// @notice The WeightedPoolFactory contract used to create new weighted pools
    IWeightedPoolFactory public immutable poolFactory;

    /// @dev Equal weights for 50%-50% pools (0.5 = 50% in 18-decimal fixed point)
    uint256[] equalWeights = [0.5e18, 0.5e18];

    /**
     * @notice Constructor that initializes the helper with Vault and PoolFactory contracts
     * @param _vault The Balancer V2 Vault contract address
     * @param _poolFactory The WeightedPoolFactory contract address
     */
    constructor(IVault _vault, IWeightedPoolFactory _poolFactory) {
        vault = _vault;
        poolFactory = _poolFactory;
    }

    /**
     * @inheritdoc IBalancerV2Helper
     */
    function createPool(PoolConfig memory cfg) external override returns (IBasePool) {
        // Ensure swap fee meets minimum protocol requirements
        if (cfg.swapFeePercentage < MIN_SWAP_FEE_PERCENTAGE) {
            cfg.swapFeePercentage = MIN_SWAP_FEE_PERCENTAGE;
        }

        // Token addresses must be sorted in ascending order for Balancer V2 compatibility
        IERC20[] memory tokens = new IERC20[](2);
        if (cfg.tokenA < cfg.tokenB) {
            tokens[0] = cfg.tokenA;
            tokens[1] = cfg.tokenB;
        } else {
            tokens[0] = cfg.tokenB;
            tokens[1] = cfg.tokenA;
        }

        // Deploy mock rate providers for each token (required by WeightedPoolFactory)
        // Rate providers return exchange rates for tokens that may appreciate over time
        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        rateProviders[0] = IRateProvider(new MockRateProvider());
        rateProviders[1] = IRateProvider(new MockRateProvider());

        // Create the weighted pool with 50/50 token distribution
        address pool = poolFactory.create(
            cfg.name, cfg.symbol, tokens, equalWeights, rateProviders, cfg.swapFeePercentage, cfg.owner
        );
        emit PoolCreated(cfg.name, cfg.symbol, pool);

        return IBasePool(pool);
    }

    /**
     * @inheritdoc IBalancerV2Helper
     */
    function addInitialLiquidity(
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts
    ) external payable override {
        _addLiquidity(pool, sender, recipient, tokens, amounts, WeightedPoolUserData.JoinKind.INIT);
    }

    /**
     * @inheritdoc IBalancerV2Helper
     */
    function addLiquidity(
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts
    ) external payable override {
        _addLiquidity(
            pool, sender, recipient, tokens, amounts, WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT
        );
    }

    /**
     * @inheritdoc IBalancerV2Helper
     */
    function swap(IBasePool pool, address sender, address payable recipient, IERC20 tokenIn, uint256 amountIn)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        // Get sorted token addresses from Vault
        bytes32 poolId = pool.getPoolId();
        (IERC20[] memory sortedTokens,,) = vault.getPoolTokens(poolId);

        // Determine the output token index for the swap
        uint8 tokenOutIndex;
        bool isOAS = address(tokenIn) == address(0);
        if (isOAS) {
            // For native OAS swap, find the non-WOAS token as output
            tokenOutIndex = address(sortedTokens[0]) == address(vault.WETH()) ? 1 : 0;
        } else {
            // For regular token swap, find the opposite token
            tokenOutIndex = tokenIn == sortedTokens[0] ? 1 : 0;
        }

        IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
            poolId: poolId,
            kind: IVault.SwapKind.GIVEN_IN,
            assetIn: IAsset(address(tokenIn)),
            assetOut: IAsset(address(sortedTokens[tokenOutIndex])),
            amount: amountIn,
            userData: ""
        });
        IVault.FundManagement memory funds = IVault.FundManagement({
            sender: sender,
            fromInternalBalance: false,
            recipient: recipient,
            toInternalBalance: false
        });
        // Slippage protection limit (0 = no protection)
        uint256 limit = 0;
        // Deadline for this swap transaction (60 seconds from now)
        uint256 deadline = block.timestamp + 60;

        if (isOAS) {
            // Native OAS swap - forward msg.value to Vault for WOAS wrapping
            amountOut = vault.swap{value: msg.value}(singleSwap, funds, limit, deadline);
        } else {
            // ERC20 token swap - no native value needed
            amountOut = vault.swap(singleSwap, funds, limit, deadline);
        }
    }

    /**
     * @notice Internal function to add liquidity to a pool
     */
    function _addLiquidity(
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata _tokens,
        uint256[2] calldata _amounts,
        WeightedPoolUserData.JoinKind kind
    ) internal {
        // Note: When adding native OAS, address(0) must be specified at the WOAS index position,
        //       so tokens must not be sorted in ascending order to maintain correct indexing.
        IERC20[] memory tokens = new IERC20[](2);
        uint256[] memory amounts = new uint256[](2);
        (tokens[0], tokens[1]) = (_tokens[0], _tokens[1]);
        (amounts[0], amounts[1]) = (_amounts[0], _amounts[1]);

        // Build userdata according to WeightedPoolUserData.JoinKind specification
        // Reference: https://docs-v2.balancer.fi/reference/joins-and-exits/pool-joins.html
        bytes memory userdata;
        if (kind == WeightedPoolUserData.JoinKind.INIT) {
            // Initial liquidity provision (first join) - only requires token amounts
            userdata = abi.encode(kind, amounts);
        } else if (kind == WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT) {
            // Proportional join with exact token amounts - requires minimum BPT out
            uint256 minimumBPT = 0; // No minimum BPT requirement for testing
            userdata = abi.encode(kind, amounts, minimumBPT);
        } else {
            revert("Invalid WeightedPoolUserData.JoinKind");
        }

        // Construct the join pool request
        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: _asIAsset(tokens),
            maxAmountsIn: amounts,
            userData: userdata,
            fromInternalBalance: false // Use external balances (user's wallet)
        });

        // Execute pool join with or without native OAS value
        bytes32 poolId = pool.getPoolId();
        if (msg.value > 0) {
            vault.joinPool{value: msg.value}(poolId, sender, recipient, request);
        } else {
            vault.joinPool(poolId, sender, recipient, request);
        }
    }

    /**
     * @notice Convert IERC20 array to IAsset array for Vault compatibility
     */
    function _asIAsset(IERC20[] memory tokens) internal pure returns (IAsset[] memory) {
        IAsset[] memory assets = new IAsset[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
        }
        return assets;
    }
}
