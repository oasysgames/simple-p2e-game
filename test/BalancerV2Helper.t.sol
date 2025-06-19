// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

// Foundry Test Framework
import {Test, console} from "forge-std/Test.sol";

// Balancer V2 Interfaces
import {IBasePool} from "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

// Local Test Utilities
import {BalancerV2Helper} from "../src/test-utils/BalancerV2Helper.sol";
import {IBalancerV2Helper} from "../src/test-utils/interfaces/IBalancerV2Helper.sol";
import {IMockSMP} from "../src/test-utils/interfaces/IMockSMP.sol";
import {IWeightedPoolFactory} from "../src/test-utils/interfaces/IWeightedPoolFactory.sol";
import {IWOAS} from "../src/test-utils/interfaces/IWOAS.sol";

contract BalancerV2HelperTest is Test {
    BalancerV2Helper public helper;
    IVault vault;
    IWeightedPoolFactory factory;
    IWOAS woas;
    IMockSMP smp;

    address public deployer;
    address public poolOwner;
    address public sender;
    address public recipient;

    uint256 initialBalance = 1000 ether;

    function setUp() public {
        // Deployment and initial setup
        deployer = makeAddr("deployer");
        poolOwner = makeAddr("poolOwner");
        sender = makeAddr("sender");
        recipient = makeAddr("recipient");

        {
            vm.startPrank(deployer);

            helper = new BalancerV2Helper();
            (vault, factory, woas, smp) = helper.deployBalancerV2();

            vm.stopPrank();
        }

        {
            vm.startPrank(sender);

            // Grant relayer approval to helper contract
            vault.setRelayerApproval(sender, address(helper), true);

            // Mint WOAS by depositing native OAS
            vm.deal(sender, initialBalance);
            woas.deposit{value: initialBalance}();

            // Mint SMP tokens
            smp.mint(sender, initialBalance);

            vm.stopPrank();
        }
    }

    /**
     * @notice Test pool creation functionality
     * @dev Verifies that a weighted pool can be created with correct token configuration
     */
    function test_createPool() public {
        IBasePool pool = _createPool();

        bytes32 poolId = pool.getPoolId();
        assertNotEq(poolId, 0x0);

        (IERC20[] memory tokens,,) = vault.getPoolTokens(poolId);
        assertEq(address(tokens[0]), address(woas));
        assertEq(address(tokens[1]), address(smp));
    }

    /**
     * @notice Test initial liquidity addition to a newly created pool
     * @dev Verifies that initial liquidity can be added and pool balances are correct
     */
    function test_addInitialLiquidity() public {
        vm.startPrank(sender);

        IBasePool pool = _createPool();
        _addInitialLiquidity(pool, 1 ether, 2 ether);

        (, uint256[] memory balances,) = vault.getPoolTokens(pool.getPoolId());
        assertEq(balances[0], 1 ether);
        assertEq(balances[1], 2 ether);
    }

    /**
     * @notice Test liquidity addition to existing pools with various scenarios
     * @dev Tests multiple liquidity addition patterns including single-token adds and native OAS
     */
    function test_addLiquidity() public {
        vm.startPrank(sender);

        // Provide initial liquidity
        IBasePool pool = _createPool();
        (IERC20[2] memory tokens, uint256[2] memory amounts) = _addInitialLiquidity(pool, 1 ether, 2 ether);

        // Add both WOAS and SMP
        amounts[0] = 1 ether;
        amounts[1] = 1 ether;
        woas.approve(address(vault), 1 ether);
        smp.approve(address(vault), 1 ether);
        helper.addLiquidity(vault, pool, sender, recipient, tokens, amounts);

        (, uint256[] memory balances,) = vault.getPoolTokens(pool.getPoolId());
        assertEq(balances[0], 2 ether);
        assertEq(balances[1], 3 ether);

        // Add WOAS only
        amounts[0] = 1 ether;
        amounts[1] = 0 ether;
        woas.approve(address(vault), 1 ether);
        helper.addLiquidity(vault, pool, sender, recipient, tokens, amounts);

        (, balances,) = vault.getPoolTokens(pool.getPoolId());
        assertEq(balances[0], 3 ether);
        assertEq(balances[1], 3 ether);

        // Add SMP only
        amounts[0] = 0 ether;
        amounts[1] = 1 ether;
        smp.approve(address(vault), 1 ether);
        helper.addLiquidity(vault, pool, sender, recipient, tokens, amounts);

        (, balances,) = vault.getPoolTokens(pool.getPoolId());
        assertEq(balances[0], 3 ether);
        assertEq(balances[1], 4 ether);

        // Add WOAS with reversed token order
        IERC20[2] memory reversed;
        reversed[0] = tokens[1];
        reversed[1] = tokens[0];
        amounts[0] = 0 ether;
        amounts[1] = 1 ether;
        woas.approve(address(vault), 1 ether);
        helper.addLiquidity(vault, pool, sender, recipient, reversed, amounts);

        (, balances,) = vault.getPoolTokens(pool.getPoolId());
        assertEq(balances[0], 4 ether);
        assertEq(balances[1], 4 ether);

        // Add native OAS
        tokens[0] = IERC20(address(0));
        amounts[0] = 1 ether;
        amounts[1] = 0 ether;
        vm.deal(sender, 1 ether);
        helper.addLiquidity{value: 1 ether}(vault, pool, sender, recipient, tokens, amounts);

        (, balances,) = vault.getPoolTokens(pool.getPoolId());
        assertEq(balances[0], 5 ether);
        assertEq(balances[1], 4 ether);
    }

    /**
     * @notice Test token swapping functionality with various token pairs
     * @dev Tests WOAS<->SMP swaps and native OAS swapping with slippage checks
     */
    function test_swap() public {
        vm.startPrank(sender);

        IBasePool pool = _createPool();
        _addInitialLiquidity(pool, 100 ether, 100 ether);

        // Swap WOAS to SMP
        IERC20 tokenIn = _asIERC20(woas);
        uint256 amountIn = 1 ether;
        woas.approve(address(vault), amountIn);

        uint256 smpOut1 = helper.swap(vault, pool, sender, payable(recipient), tokenIn, amountIn);
        assertGe(smpOut1, 0.99 ether);
        assertEq(smpOut1, smp.balanceOf(recipient));

        // Swap SMP to WOAS
        tokenIn = _asIERC20(smp);
        amountIn = 1 ether;
        smp.approve(address(vault), amountIn);

        uint256 woasOut = helper.swap(vault, pool, sender, payable(recipient), tokenIn, amountIn);
        assertGe(woasOut, 0.99 ether);
        assertEq(woasOut, woas.balanceOf(recipient));

        // Swap native OAS to SMP
        tokenIn = IERC20(address(0));
        amountIn = 1 ether;
        vm.deal(sender, amountIn);

        uint256 smpOut2 = helper.swap{value: amountIn}(vault, pool, sender, payable(recipient), tokenIn, amountIn);
        assertGe(smpOut2, 0.99 ether);
        assertEq(smpOut1 + smpOut2, smp.balanceOf(recipient));
    }

    /**
     * @notice Helper function to create a test pool with default configuration
     */
    function _createPool() internal returns (IBasePool) {
        IBalancerV2Helper.PoolConfig memory cfg = IBalancerV2Helper.PoolConfig({
            owner: poolOwner,
            name: "50WOAS-50SMP",
            symbol: "50WOAS-50SMP",
            swapFeePercentage: 0,
            tokenA: _asIERC20(woas),
            tokenB: _asIERC20(smp)
        });
        return helper.createPool(factory, cfg);
    }

    /**
     * @notice Helper function to add initial liquidity to a pool
     */
    function _addInitialLiquidity(IBasePool pool, uint256 _woas, uint256 _smp)
        internal
        returns (IERC20[2] memory tokens, uint256[2] memory amounts)
    {
        tokens[0] = _asIERC20(woas);
        tokens[1] = _asIERC20(smp);

        amounts[0] = _woas;
        amounts[1] = _smp;

        woas.approve(address(vault), _woas);
        smp.approve(address(vault), _smp);

        helper.addInitialLiquidity(vault, pool, sender, recipient, tokens, amounts);
    }

    /**
     * @notice Convert IWOAS interface to IERC20 for Balancer operations
     */
    function _asIERC20(IWOAS woas) internal returns (IERC20) {
        return IERC20(address(woas));
    }

    /**
     * @notice Convert IMockSMP interface to IERC20 for Balancer operations
     */
    function _asIERC20(IMockSMP smp) internal returns (IERC20) {
        return IERC20(address(smp));
    }
}
