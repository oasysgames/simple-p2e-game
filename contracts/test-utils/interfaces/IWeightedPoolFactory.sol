// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";

/**
 * @title IWeightedPoolFactory
 * @notice Interface for Balancer V2 Weighted Pool Factory
 */
interface IWeightedPoolFactory {
    /**
     * @notice Create a new weighted pool with specified parameters
     * @dev Deploys a new WeightedPool contract with the given configuration.
     *      All arrays (tokens, normalizedWeights, rateProviders) must have the same length.
     *      Token addresses must be sorted in ascending order.
     * @param name Pool token name (e.g., "50WOAS-50SMP")
     * @param symbol Pool token symbol (e.g., "50WOAS-50SMP")
     * @param tokens Array of token addresses in the pool (must be sorted)
     * @param normalizedWeights Array of token weights (must sum to 1e18, i.e., 100%)
     * @param rateProviders Array of rate providers for each token (can be zero address)
     * @param swapFeePercentage Swap fee percentage (1e18 = 100%, typical range: 1e12 to 1e17)
     * @param owner Address that will own the pool and can change parameters
     * @return Address of the newly created weighted pool
     */
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory normalizedWeights,
        IRateProvider[] memory rateProviders,
        uint256 swapFeePercentage,
        address owner
    ) external returns (address);
}
