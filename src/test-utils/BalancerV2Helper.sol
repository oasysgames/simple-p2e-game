// SPDX-License-Identifier: MIT
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {Vault} from "@balancer-labs/v2-vault/contracts/Vault.sol";
import {MockBasicAuthorizer} from "@balancer-labs/v2-vault/contracts/test/MockBasicAuthorizer.sol";
import {WeightedPoolFactory} from "@balancer-labs/v2-pool-weighted/contracts/WeightedPoolFactory.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IBasePool} from "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import {IBasePoolFactory} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IBasePoolFactory.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import {MockRateProvider} from "@balancer-labs/v2-pool-utils/contracts/test/MockRateProvider.sol";
import {ERC20} from "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";
import {WeightedPool} from "@balancer-labs/v2-pool-weighted/contracts/WeightedPool.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import {IAsset} from "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";

import {IWOAS} from "./interfaces/IWOAS.sol";
import {IMockSMP} from "./interfaces/IMockSMP.sol";
import {IBalancerV2Helper} from "./interfaces/IBalancerV2Helper.sol";
import {IWeightedPoolFactory} from "./interfaces/IWeightedPoolFactory.sol";
import {WOAS} from "./WOAS.sol";
import {MockSMP} from "./MockSMP.sol";
import {MockProtocolFeePercentagesProvider} from "./MockProtocolFeePercentagesProvider.sol";

/**
 * @title BalancerV2Helper
 * @dev TOOD
 */
contract BalancerV2Helper is IBalancerV2Helper {
    uint256 constant MIN_SWAP_FEE_PERCENTAGE = 1e12; // 0.0001%

    uint256[] equalWeights = [0.5e18, 0.5e18]; // 50%-50%

    function deployBalancerV2() external override returns (IVault, IWeightedPoolFactory, IWOAS, IMockSMP) {
        IWOAS woas = IWOAS(address(new WOAS()));
        IMockSMP smp = IMockSMP(address(new MockSMP()));

        MockBasicAuthorizer authorizer = new MockBasicAuthorizer();
        Vault vault = new Vault(authorizer, woas, 90 days, 30 days);

        MockProtocolFeePercentagesProvider protocolFeeProvider = new MockProtocolFeePercentagesProvider();
        WeightedPoolFactory factory = new WeightedPoolFactory(vault, protocolFeeProvider, 90 days, 30 days);

        // 中継に必要な権限を付与
        authorizer.grantRole(vault.getActionId(vault.joinPool.selector), address(this));
        authorizer.grantRole(vault.getActionId(vault.exitPool.selector), address(this));
        authorizer.grantRole(vault.getActionId(vault.swap.selector), address(this));

        emit BalancerV2Deployed(address(vault), address(factory), address(woas), address(smp));

        return (vault, IWeightedPoolFactory(address(factory)), woas, smp);
    }

    function createPool(IWeightedPoolFactory factory, PoolConfig memory cfg) external override returns (IBasePool) {
        if (cfg.swapFeePercentage < MIN_SWAP_FEE_PERCENTAGE) {
            cfg.swapFeePercentage = MIN_SWAP_FEE_PERCENTAGE;
        }

        IERC20[] memory tokens = new IERC20[](2);
        if (cfg.tokenA < cfg.tokenB) {
            tokens[0] = cfg.tokenA;
            tokens[1] = cfg.tokenB;
        } else {
            tokens[0] = cfg.tokenB;
            tokens[1] = cfg.tokenA;
        }

        // Deploy MockRateProviders for each token
        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        rateProviders[0] = IRateProvider(new MockRateProvider());
        rateProviders[1] = IRateProvider(new MockRateProvider());

        address pool =
            factory.create(cfg.name, cfg.symbol, tokens, equalWeights, rateProviders, cfg.swapFeePercentage, cfg.owner);
        emit PoolCreated(cfg.name, cfg.symbol, pool);

        return WeightedPool(pool);
    }

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

    function swap(
        IVault vault,
        IBasePool pool,
        address sender,
        address payable recipient,
        IERC20 tokenIn,
        uint256 amountIn
    ) external payable override returns (uint256 amountOut) {
        // Get sorted tokens
        bytes32 poolId = pool.getPoolId();
        (IERC20[] memory sortedTokens,,) = vault.getPoolTokens(poolId);

        // Determine asset indices for swap
        bool isNativeToken = address(tokenIn) == address(0);
        uint8 tokenOutIndex;
        if (isNativeToken) {
            // For native token swap, find the non-WOAS token as output
            tokenOutIndex = address(sortedTokens[0]) == address(vault.WETH()) ? 1 : 0;
        } else {
            // For regular token swap
            tokenOutIndex = tokenIn == sortedTokens[0] ? 1 : 0;
        }

        // Configure swap
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
        uint256 limit = 0;
        uint256 deadline = block.timestamp + 300;

        // Execute swap (with value if ETH swap)
        if (isNativeToken) {
            // 内部で自動的にラップされる
            amountOut = vault.swap{value: msg.value}(singleSwap, funds, limit, deadline);
        } else {
            amountOut = vault.swap(singleSwap, funds, limit, deadline);
        }
    }

    function _addLiquidity(
        IVault vault,
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts,
        JoinKind kind
    ) internal {
        IERC20[] memory sortedTokens = new IERC20[](2);
        uint256[] memory sortedAmounts = new uint256[](2);

        (uint8 a, uint8 b) = tokens[0] < tokens[1] ? (0, 1) : (1, 0);
        (sortedTokens[0], sortedTokens[1]) = (tokens[a], tokens[b]);
        (sortedAmounts[0], sortedAmounts[1]) = (amounts[a], amounts[b]);

        // https://docs-v2.balancer.fi/reference/joins-and-exits/pool-joins.html
        bytes memory userdata;
        if (kind == JoinKind.INIT) {
            userdata = abi.encode(kind, sortedAmounts);
        } else if (kind == JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT) {
            uint256 minimumBPT = 0;
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

        // bool isNativeToken = address(tokens[0]) == address(0) || address(tokens[1]) == address(0);
        bytes32 poolId = pool.getPoolId();
        if (msg.value > 0) {
            // 内部で自動的にラップされる
            vault.joinPool{value: msg.value}(poolId, sender, recipient, request);
        } else {
            vault.joinPool(poolId, sender, recipient, request);
        }
    }

    function _asIAsset(IERC20[] memory tokens) internal pure returns (IAsset[] memory) {
        IAsset[] memory assets = new IAsset[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
        }
        return assets;
    }
}
