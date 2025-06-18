// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IBasePool} from "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

import {IWOAS} from "./IWOAS.sol";
import {IMockSMP} from "./IMockSMP.sol";
import {IWeightedPoolFactory} from "./IWeightedPoolFactory.sol";

interface IBalancerV2Helper {
    event BalancerV2Deployed(address vault, address factory, address woas, address smp);
    event PoolCreated(string name, string symbol, address pool);

    enum JoinKind {
        INIT,
        EXACT_TOKENS_IN_FOR_BPT_OUT,
        TOKEN_IN_FOR_EXACT_BPT_OUT,
        ALL_TOKENS_IN_FOR_EXACT_BPT_OUT
    }
    enum ExitKind {
        EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
        EXACT_BPT_IN_FOR_TOKENS_OUT,
        BPT_IN_FOR_EXACT_TOKENS_OUT
    }
    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct PoolConfig {
        address owner;
        string name;
        string symbol;
        uint256 swapFeePercentage;
        IERC20 tokenA;
        IERC20 tokenB;
    }

    function deployBalancerV2() external returns (IVault, IWeightedPoolFactory, IWOAS, IMockSMP);

    function createPool(IWeightedPoolFactory factory, PoolConfig memory cfg) external returns (IBasePool);

    function addInitialLiquidity(
        IVault vault,
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts
    ) external payable;

    function addLiquidity(
        IVault vault,
        IBasePool pool,
        address sender,
        address recipient,
        IERC20[2] calldata tokens,
        uint256[2] calldata amounts
    ) external payable;

    function swap(
        IVault vault,
        IBasePool pool,
        address sender,
        address payable recipient,
        IERC20 tokenIn,
        uint256 amountIn
    ) external payable returns (uint256 amountOut);
}
