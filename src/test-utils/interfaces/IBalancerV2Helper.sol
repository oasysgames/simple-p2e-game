// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

// Balancer V2 Interfaces
import {IBasePool} from "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

// Local Interfaces
import {IWeightedPoolFactory} from "./IWeightedPoolFactory.sol";

/**
 * @title IBalancerV2Helper
 * @notice Test helper interface for Balancer V2 ecosystem integration
 * @dev Provides comprehensive functionality for:
 *      - Weighted pool creation with custom parameters
 *      - Initial and ongoing liquidity provision
 *      - Token swapping with native OAS support
 */
interface IBalancerV2Helper {
    /// @notice Event emitted when a new pool is created
    /// @param name The pool token name
    /// @param symbol The pool token symbol
    /// @param pool The created pool contract address
    event PoolCreated(string name, string symbol, address pool);

    /**
     * @notice Pool creation configuration parameters
     * @param owner Pool owner address (has management privileges)
     * @param name Pool token name (for the BPT - Balancer Pool Token)
     * @param symbol Pool token symbol (for the BPT)
     * @param swapFeePercentage Swap fee percentage in 18-decimal format (1e18 = 100%, 1e16 = 1%)
     * @param tokenA First token in the pool (order will be automatically sorted)
     * @param tokenB Second token in the pool (order will be automatically sorted)
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
     * @notice Create a new weighted pool with 50/50 token distribution
     * @dev Creates a Balancer V2 weighted pool with equal weights for both tokens.
     *      Automatically deploys mock rate providers required by the factory.
     *      Enforces minimum swap fee if provided fee is too low.
     * @param cfg Pool creation configuration parameters
     * @return pool The created pool instance implementing IBasePool
     */
    function createPool(PoolConfig memory cfg) external returns (IBasePool);

    /**
     * @notice Add initial liquidity to a newly created pool (first join)
     * @dev This function should be used for the very first liquidity provision to a pool.
     *      Uses WeightedPoolUserData.JoinKind.INIT for proper initialization.
     *      For native OAS, use address(0) in tokens array and send OAS as msg.value.
     *      The `sender` must have pre-approved the Vault for ERC20 tokens.
     * @param pool Target pool to add liquidity to
     * @param sender Token sender address (must have sufficient balances)
     * @param recipient Address to receive BPT (Balancer Pool Tokens)
     * @param tokens The two tokens to add (use address(0) for WOAS index to enable native OAS)
     * @param amounts Amount of each token to add (must match token order)
     */
    function addInitialLiquidity(
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts
    ) external payable;

    /**
     * @notice Add liquidity to an existing pool
     * @dev This function should be used for adding liquidity to pools that already have liquidity.
     *      Uses WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT for proportional joins.
     *      For native OAS, use address(0) in tokens array and send OAS as msg.value.
     *      The `sender` must have pre-approved the Vault for ERC20 tokens.
     * @param pool Target pool to add liquidity to
     * @param sender Token sender address (must have sufficient balances)
     * @param recipient Address to receive BPT (Balancer Pool Tokens)
     * @param tokens The two tokens to add (use address(0) for WOAS index to enable native OAS)
     * @param amounts Amount of each token to add (must match token order)
     */
    function addLiquidity(
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts
    ) external payable;

    /**
     * @notice Swap tokens within a pool using exact input amount
     * @dev Executes a single swap operation through the Balancer V2 Vault.
     *      Automatically determines the output token (the other token in the pool).
     *      For native OAS swaps, use address(0) as tokenIn and send OAS as msg.value.
     *      For ERC20 swaps, the `sender` must have pre-approved the Vault.
     *      Uses a 60-second deadline and no slippage protection for testing.
     * @param pool Target pool to execute swap in
     * @param sender Token sender address (must have sufficient balance)
     * @param recipient Address to receive the output tokens (can be payable for native OAS)
     * @param tokenIn Input token address (use address(0) for native OAS)
     * @param amountIn Amount of input token to swap
     * @return amountOut Amount of output token received from the swap
     */
    function swap(IBasePool pool, address sender, address payable recipient, IERC20 tokenIn, uint256 amountIn)
        external
        payable
        returns (uint256 amountOut);
}
