// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

// Balancer V2 Interfaces
import {IBasePool} from "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

// Local Interfaces
import {IMockSMP} from "./IMockSMP.sol";
import {IWeightedPoolFactory} from "./IWeightedPoolFactory.sol";
import {IWOAS} from "./IWOAS.sol";

/**
 * @title IBalancerV2Helper
 * @notice Test helper interface for Balancer V2 ecosystem
 * @dev Provides liquidity pool creation, liquidity management, and swap functionality
 */
interface IBalancerV2Helper {
    /// @notice Event emitted when Balancer V2 components are deployed
    event BalancerV2Deployed(address vault, address factory, address woas, address smp);

    /// @notice Event emitted when a pool is created
    event PoolCreated(string name, string symbol, address pool);

    /**
     * @notice Enum defining pool join types
     * @dev INIT: Initial liquidity provision, EXACT_TOKENS_IN_FOR_BPT_OUT: Exact token amounts for BPT
     */
    enum JoinKind {
        INIT,
        EXACT_TOKENS_IN_FOR_BPT_OUT,
        TOKEN_IN_FOR_EXACT_BPT_OUT,
        ALL_TOKENS_IN_FOR_EXACT_BPT_OUT
    }

    /**
     * @notice Enum defining swap types
     * @dev GIVEN_IN: Input amount specified, GIVEN_OUT: Output amount specified
     */
    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    /**
     * @notice Pool creation configuration parameters
     * @param owner Pool owner address
     * @param name Pool token name
     * @param symbol Pool token symbol
     * @param swapFeePercentage Swap fee percentage (1e18 = 100%)
     * @param tokenA First token in the pool
     * @param tokenB Second token in the pool
     */
    struct PoolConfig {
        address owner;
        string name;
        string symbol;
        uint256 swapFeePercentage;
        IERC20 tokenA;
        IERC20 tokenB;
    }

    /**
     * @notice Deploy the entire Balancer V2 ecosystem
     * @return vault The core Balancer V2 vault contract
     * @return factory The weighted pool factory
     * @return woas Wrapped OAS token
     * @return smp Mock SMP token
     */
    function deployBalancerV2() external returns (IVault, IWeightedPoolFactory, IWOAS, IMockSMP);

    /**
     * @notice Create a weighted pool
     * @param factory Pool factory instance
     * @param cfg Pool creation configuration parameters
     * @return Created pool instance
     */
    function createPool(IWeightedPoolFactory factory, PoolConfig memory cfg) external returns (IBasePool);

    /**
     * @notice Add initial liquidity to a pool
     *         The `sender` must have pre-approved the Vault for `ERC20.approve(...)`
     * @param vault Balancer V2 vault
     * @param pool Target pool
     * @param sender Token sender address
     * @param recipient Address to receive BPT (LP tokens)
     * @param tokens The two tokens to add
     * @param amounts Amount of each token to add
     */
    function addInitialLiquidity(
        IVault vault,
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts
    ) external payable;

    /**
     * @notice Add liquidity to a pool (for existing pools)
     *         The `sender` must have pre-approved the Vault for `ERC20.approve(...)`
     * @param vault Balancer V2 vault
     * @param pool Target pool
     * @param sender Token sender address
     * @param recipient Address to receive BPT (LP tokens)
     * @param tokens The two tokens to add
     * @param amounts Amount of each token to add
     */
    function addLiquidity(
        IVault vault,
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts
    ) external payable;

    /**
     * @notice Swap tokens within a pool
     *         The `sender` must have pre-approved the Vault for `ERC20.approve(...)`
     * @param vault Balancer V2 vault
     * @param pool Target pool
     * @param sender Token sender address
     * @param recipient Address to receive swap result
     * @param tokenIn Input token
     * @param amountIn Amount of input token
     * @return amountOut Amount of output token received
     */
    function swap(
        IVault vault,
        IBasePool pool,
        address sender,
        address payable recipient,
        IERC20 tokenIn,
        uint256 amountIn
    ) external payable returns (uint256 amountOut);
}
