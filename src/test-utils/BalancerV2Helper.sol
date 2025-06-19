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
import {ERC20} from "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";
import {MockRateProvider} from "@balancer-labs/v2-pool-utils/contracts/test/MockRateProvider.sol";
import {WeightedPool} from "@balancer-labs/v2-pool-weighted/contracts/WeightedPool.sol";
import {WeightedPoolFactory} from "@balancer-labs/v2-pool-weighted/contracts/WeightedPoolFactory.sol";
import {MockBasicAuthorizer} from "@balancer-labs/v2-vault/contracts/test/MockBasicAuthorizer.sol";
import {Vault} from "@balancer-labs/v2-vault/contracts/Vault.sol";

// Local Interfaces
import {IBalancerV2Helper} from "./interfaces/IBalancerV2Helper.sol";
import {IMockSMP} from "./interfaces/IMockSMP.sol";
import {IWeightedPoolFactory} from "./interfaces/IWeightedPoolFactory.sol";
import {IWOAS} from "./interfaces/IWOAS.sol";

// Local Contracts
import {MockProtocolFeePercentagesProvider} from "./MockProtocolFeePercentagesProvider.sol";
import {MockSMP} from "./MockSMP.sol";
import {WOAS} from "./WOAS.sol";

/**
 * @title BalancerV2Helper
 * @notice Test helper interface for Balancer V2 ecosystem
 * @dev Provides liquidity pool creation, liquidity management, and swap functionality
 */
contract BalancerV2Helper is IBalancerV2Helper {
    /// @dev Minimum swap fee percentage as per Balancer V2 protocol specification (0.0001%)
    uint256 constant MIN_SWAP_FEE_PERCENTAGE = 1e12;

    /// @dev Equal weights for 50/50 pools
    uint256[] equalWeights = [0.5e18, 0.5e18];

    /**
     * @inheritdoc IBalancerV2Helper
     */
    function deployBalancerV2() external override returns (IVault, IWeightedPoolFactory, IWOAS, IMockSMP) {
        // Deploy required ERC20 tokens for testing
        IWOAS woas = IWOAS(address(new WOAS()));
        IMockSMP smp = IMockSMP(address(new MockSMP()));

        // Deploy vault
        MockBasicAuthorizer authorizer = new MockBasicAuthorizer();
        Vault vault = new Vault(authorizer, woas, 90 days, 30 days);

        // Deploy pool factory
        MockProtocolFeePercentagesProvider protocolFeeProvider = new MockProtocolFeePercentagesProvider();
        WeightedPoolFactory factory = new WeightedPoolFactory(vault, protocolFeeProvider, 90 days, 30 days);

        // Grant relayer permissions to this helper contract
        authorizer.grantRole(vault.getActionId(vault.joinPool.selector), address(this));
        authorizer.grantRole(vault.getActionId(vault.exitPool.selector), address(this));
        authorizer.grantRole(vault.getActionId(vault.swap.selector), address(this));

        emit BalancerV2Deployed(address(vault), address(factory), address(woas), address(smp));

        return (vault, IWeightedPoolFactory(address(factory)), woas, smp);
    }

    /**
     * @inheritdoc IBalancerV2Helper
     */
    function createPool(IWeightedPoolFactory factory, PoolConfig memory cfg) external override returns (IBasePool) {
        if (cfg.swapFeePercentage < MIN_SWAP_FEE_PERCENTAGE) {
            cfg.swapFeePercentage = MIN_SWAP_FEE_PERCENTAGE;
        }

        // Token addresses must be sorted in ascending order
        IERC20[] memory tokens = new IERC20[](2);
        if (cfg.tokenA < cfg.tokenB) {
            tokens[0] = cfg.tokenA;
            tokens[1] = cfg.tokenB;
        } else {
            tokens[0] = cfg.tokenB;
            tokens[1] = cfg.tokenA;
        }

        // Deploy mock rate providers for each token (required by WeightedPoolFactory)
        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        rateProviders[0] = IRateProvider(new MockRateProvider());
        rateProviders[1] = IRateProvider(new MockRateProvider());

        address pool =
            factory.create(cfg.name, cfg.symbol, tokens, equalWeights, rateProviders, cfg.swapFeePercentage, cfg.owner);
        emit PoolCreated(cfg.name, cfg.symbol, pool);

        return WeightedPool(pool);
    }

    /**
     * @inheritdoc IBalancerV2Helper
     */
    function addInitialLiquidity(
        IVault vault,
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts
    ) external payable override {
        _addLiquidity(vault, pool, sender, recipient, tokens, amounts, JoinKind.INIT);
    }

    /**
     * @inheritdoc IBalancerV2Helper
     */
    function addLiquidity(
        IVault vault,
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts
    ) external payable override {
        _addLiquidity(vault, pool, sender, recipient, tokens, amounts, JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT);
    }

    /**
     * @inheritdoc IBalancerV2Helper
     */
    function swap(
        IVault vault,
        IBasePool pool,
        address sender,
        address payable recipient,
        IERC20 tokenIn,
        uint256 amountIn
    ) external payable override returns (uint256 amountOut) {
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

        // Execute swap with or without native OAS value
        if (isOAS) {
            amountOut = vault.swap{value: msg.value}(singleSwap, funds, limit, deadline);
        } else {
            amountOut = vault.swap(singleSwap, funds, limit, deadline);
        }
    }

    /**
     * @notice Internal function to add liquidity to a pool
     */
    function _addLiquidity(
        IVault vault,
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts,
        JoinKind kind
    ) internal {
        // When adding native OAS, tokens array contains zero address, so we cannot use
        // vault-retrieved sorted tokens like in swap. Manual sorting is required.
        IERC20[] memory sortedTokens = new IERC20[](2);
        uint256[] memory sortedAmounts = new uint256[](2);

        (uint8 a, uint8 b) = tokens[0] < tokens[1] ? (0, 1) : (1, 0);
        (sortedTokens[0], sortedTokens[1]) = (tokens[a], tokens[b]);
        (sortedAmounts[0], sortedAmounts[1]) = (amounts[a], amounts[b]);

        // Build userdata to JoinKind specification
        // Reference: https://docs-v2.balancer.fi/reference/joins-and-exits/pool-joins.html
        bytes memory userdata;
        if (kind == JoinKind.INIT) {
            // Initial liquidity provision (first join)
            userdata = abi.encode(kind, sortedAmounts);
        } else if (kind == JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT) {
            // Proportional join with exact token amounts
            uint256 minimumBPT = 0; // No minimum BPT requirement
            userdata = abi.encode(kind, sortedAmounts, minimumBPT);
        } else {
            revert("Invalid JoinKind");
        }

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: _asIAsset(sortedTokens),
            maxAmountsIn: sortedAmounts,
            userData: userdata,
            fromInternalBalance: false
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
     * @notice Convert IERC20 array to IAsset array
     */
    function _asIAsset(IERC20[] memory tokens) internal pure returns (IAsset[] memory) {
        IAsset[] memory assets = new IAsset[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
        }
        return assets;
    }
}
