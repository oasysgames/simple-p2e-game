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
import {VaultDeployer, IMinimumAuthorizer} from "../contracts/test-utils/deployers/VaultDeployer.sol";
import {WeightedPoolFactoryDeployer} from "../contracts/test-utils/deployers/WeightedPoolFactoryDeployer.sol";
import {BalancerV2HelperDeployer} from "../contracts/test-utils/deployers/BalancerV2HelperDeployer.sol";
import {IBalancerV2Helper} from "../contracts/test-utils/interfaces/IBalancerV2Helper.sol";
import {IMockSMP} from "../contracts/test-utils/interfaces/IMockSMP.sol";
import {IWeightedPoolFactory} from "../contracts/test-utils/interfaces/IWeightedPoolFactory.sol";
import {IWOAS} from "../contracts/test-utils/interfaces/IWOAS.sol";
import {MockSMP} from "../contracts/test-utils/MockSMPv7.sol";
import {BalancerV2Helper} from "../contracts/test-utils/BalancerV2Helper.sol";

contract BalancerV2HelperTest is Test {
    IBalancerV2Helper public helper;
    IVault vault;
    IWeightedPoolFactory factory;
    IWOAS woas;
    IMockSMP smp;
    IERC20 nativeOAS; // address(0) = native OAS
    IERC20[2] sortedTokens;

    address public deployer; // Deploys all contracts
    address public poolOwner; // Owns and manages pools
    address public sender; // Sends tokens in operations
    address public recipient; // Receives tokens/BPT from operations

    uint256 initialBalance = 1000 ether;

    function setUp() public {
        // Create test accounts
        deployer = makeAddr("deployer");
        poolOwner = makeAddr("poolOwner");
        sender = makeAddr("sender");
        recipient = makeAddr("recipient");

        // Deploy complete Balancer V2 ecosystem
        {
            vm.startPrank(deployer);

            // Use deterministic salt for consistent deployment addresses
            bytes32 salt = keccak256(abi.encode("DEPLOYER_SALT"));

            // Deploy core Balancer V2 contracts
            VaultDeployer vaultDeployer = new VaultDeployer(salt);
            WeightedPoolFactoryDeployer poolFactoryDeployer =
                new WeightedPoolFactoryDeployer(salt, vaultDeployer.vault());
            BalancerV2HelperDeployer bv2deployer =
                new BalancerV2HelperDeployer(salt, vaultDeployer.vault(), poolFactoryDeployer.poolFactory());

            // Store contract references
            vault = IVault(vaultDeployer.vault());
            factory = IWeightedPoolFactory(poolFactoryDeployer.poolFactory());
            woas = IWOAS(vaultDeployer.woas());
            smp = IMockSMP(address(new MockSMP()));
            helper = IBalancerV2Helper(bv2deployer.helper());
            helper = new BalancerV2Helper(vault, factory);

            // Grant relayer roles to helper contract
            vaultDeployer.grantRelayerRolesToHelper(address(helper));

            vm.stopPrank();
        }

        // Configure test account with tokens and permissions
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

        // Sort tokens by address for Balancer V2 compatibility
        (uint8 a, uint8 b) = address(woas) < address(smp) ? (0, 1) : (1, 0);
        sortedTokens[a] = IERC20(address(woas));
        sortedTokens[b] = IERC20(address(smp));
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
        assertEq(address(tokens[0]), address(sortedTokens[0]));
        assertEq(address(tokens[1]), address(sortedTokens[1]));
    }

    /**
     * @notice Test initial liquidity addition to a newly created pool
     * @dev Verifies that initial liquidity can be added and pool balances are correct
     */
    function test_addInitialLiquidity() public {
        vm.startPrank(sender);

        IBasePool pool = _createPool();
        _addInitialLiquidity(pool, 1 ether, 2 ether);
        _assertPoolBalances(pool, 1 ether, 2 ether);
    }

    /**
     * @notice Test liquidity addition to existing pools with various scenarios
     * @dev Tests multiple liquidity addition patterns including single-token adds and native OAS
     */
    function test_addLiquidity() public {
        vm.startPrank(sender);

        // Provide initial liquidity
        IBasePool pool = _createPool();
        _addInitialLiquidity(pool, 1 ether, 2 ether);

        // Add both WOAS and SMP
        woas.approve(address(vault), 1 ether);
        smp.approve(address(vault), 1 ether);
        helper.addLiquidity(pool, sender, recipient, sortedTokens, _sortedAmounts(1 ether, 1 ether));
        _assertPoolBalances(pool, 2 ether, 3 ether);

        // Add WOAS only
        woas.approve(address(vault), 1 ether);
        helper.addLiquidity(pool, sender, recipient, sortedTokens, _sortedAmounts(1 ether, 0 ether));
        _assertPoolBalances(pool, 3 ether, 3 ether);

        // Add SMP only
        smp.approve(address(vault), 1 ether);
        helper.addLiquidity(pool, sender, recipient, sortedTokens, _sortedAmounts(0 ether, 1 ether));
        _assertPoolBalances(pool, 3 ether, 4 ether);

        // Add native OAS
        IERC20[2] memory tokens = sortedTokens;
        uint256[2] memory amounts;
        uint8 woasIdx = address(sortedTokens[0]) == address(woas) ? 0 : 1;
        tokens[woasIdx] = nativeOAS;
        amounts[woasIdx] = 1 ether;

        vm.deal(sender, 1 ether);
        helper.addLiquidity{value: 1 ether}(pool, sender, recipient, tokens, amounts);
        _assertPoolBalances(pool, 4 ether, 4 ether);
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
        uint256 amountIn = 1 ether;
        woas.approve(address(vault), amountIn);
        uint256 smpOut1 = helper.swap(pool, sender, payable(recipient), _asIERC20(woas), _asIERC20(smp), amountIn);
        assertGe(smpOut1, 0.99 ether);
        assertEq(smpOut1, smp.balanceOf(recipient));

        // Swap SMP to WOAS
        smp.approve(address(vault), amountIn);
        uint256 woasOut = helper.swap(pool, sender, payable(recipient), _asIERC20(smp), _asIERC20(woas), amountIn);
        assertGe(woasOut, 0.99 ether);
        assertEq(woasOut, woas.balanceOf(recipient));

        // Swap native OAS to SMP
        vm.deal(sender, amountIn);
        uint256 smpOut2 =
            helper.swap{value: amountIn}(pool, sender, payable(recipient), nativeOAS, _asIERC20(smp), amountIn);
        assertGe(smpOut2, 0.99 ether);
        assertEq(smpOut1 + smpOut2, smp.balanceOf(recipient));

        // Swap SMP to native OAS
        smp.approve(address(vault), amountIn);
        uint256 oasOut = helper.swap(pool, sender, payable(recipient), _asIERC20(smp), nativeOAS, amountIn);
        assertGe(oasOut, 0.99 ether);
        assertEq(oasOut, recipient.balance);
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
        return helper.createPool(cfg);
    }

    /**
     * @notice Helper function to sort token amounts according to token address order
     * @dev Returns amounts in the same order as sortedTokens array
     * @param _woas Amount of WOAS tokens
     * @param _smp Amount of SMP tokens
     * @return amounts Array with amounts sorted by token address
     */
    function _sortedAmounts(uint256 _woas, uint256 _smp) internal returns (uint256[2] memory amounts) {
        (uint8 a, uint8 b) = address(woas) < address(smp) ? (0, 1) : (1, 0);
        amounts[a] = _woas;
        amounts[b] = _smp;
    }

    /**
     * @notice Helper function to add initial liquidity to a pool
     */
    function _addInitialLiquidity(IBasePool pool, uint256 _woas, uint256 _smp) internal {
        woas.approve(address(vault), _woas);
        smp.approve(address(vault), _smp);
        helper.addInitialLiquidity(pool, sender, recipient, sortedTokens, _sortedAmounts(_woas, _smp));
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

    /**
     * @notice Assert that pool balances match expected amounts
     * @dev Handles token order automatically by checking addresses
     * @param pool The pool to check balances for
     * @param _woas Expected WOAS balance in the pool
     * @param _smp Expected SMP balance in the pool
     */
    function _assertPoolBalances(IBasePool pool, uint256 _woas, uint256 _smp) internal {
        (IERC20[] memory tokens, uint256[] memory balances,) = vault.getPoolTokens(pool.getPoolId());

        // Check balances based on token address order
        if (address(tokens[0]) == address(woas)) {
            assertEq(balances[0], _woas, "WOAS balance mismatch");
            assertEq(balances[1], _smp, "SMP balance mismatch");
        } else {
            assertEq(balances[1], _woas, "WOAS balance mismatch");
            assertEq(balances[0], _smp, "SMP balance mismatch");
        }
    }
}
