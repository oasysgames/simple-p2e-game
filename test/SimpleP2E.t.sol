// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
pragma experimental ABIEncoderV2;

// Foundry Test Framework
import {Test} from "forge-std/Test.sol";

// Balancer V2 Interfaces
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

// Local contracts and interfaces
import {SimpleP2E} from "../contracts/SimpleP2E.sol";
import {ISimpleP2E} from "../contracts/interfaces/ISimpleP2E.sol";
import {IVaultPool} from "../contracts/interfaces/IVaultPool.sol";
import {ISimpleP2EERC721} from "../contracts/interfaces/ISimpleP2EERC721.sol";
import {IPOAS} from "../contracts/interfaces/IPOAS.sol";
import {IPOASMinter} from "../contracts/interfaces/IPOASMinter.sol";
import {IWOAS} from "../contracts/interfaces/IWOAS.sol";

// Test utilities
import {VaultDeployer} from "../contracts/test-utils/deployers/VaultDeployer.sol";
import {WeightedPoolFactoryDeployer} from
    "../contracts/test-utils/deployers/WeightedPoolFactoryDeployer.sol";
import {BalancerV2HelperDeployer} from
    "../contracts/test-utils/deployers/BalancerV2HelperDeployer.sol";
import {IBalancerV2Helper} from "../contracts/test-utils/interfaces/IBalancerV2Helper.sol";
import {MockSMP} from "../contracts/test-utils/MockSMPv8.sol";
import {MockPOASMinter} from "../contracts/test-utils/MockPOASMinter.sol";
import {MockSimpleP2EERC721} from "../contracts/test-utils/MockSimpleP2EERC721.sol";

contract SimpleP2ETest is Test {
    ISimpleP2E p2e;
    address p2eAddr;

    IBalancerV2Helper bv2helper;
    IVault vault;
    IVaultPool pool;
    IERC20 woas;
    IERC20 smp;
    IPOAS poas;
    IPOASMinter poasMinter;
    address nativeOAS = address(0);

    address deployer; // Deploys all contracts
    address lpRecipient;
    address revenueRecipient;
    address sender;

    uint256 woasSMPPriceRatio = 4;
    uint256 initialWOASLiquidity = 10_000 ether;
    uint256 initialSMPLiquidity = initialWOASLiquidity * woasSMPPriceRatio;

    uint256 smpBasePrice = 50 ether;
    uint256 userInitialBalance = smpBasePrice * 10;

    ISimpleP2EERC721[] triNFTs;
    uint256 triNFT_SMP_Price = 150 ether; // 3 NFTs × 50 SMP
    uint256 triNFT_SMP_Burn = 75 ether; // 50% of 150 SMP
    uint256 triNFT_SMP_Liquidity = 60 ether; // 40% of 150 SMP
    uint256 triNFT_SMP_Revenue = 15 ether; // 10% of 150 SMP
    uint256 triNFT_OAS_Price = triNFT_SMP_Price / woasSMPPriceRatio;
    uint256 purchaseGasLimit = 1_000_000;

    // ERC20 standard events
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // WOAS events
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    // POAS events
    event Paid(address indexed from, address indexed recipient, uint256 amount);

    // BalancerV2 events
    event Swap(
        bytes32 indexed poolId,
        IERC20 indexed tokenIn,
        IERC20 indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    function setUp() public {
        // Create test accounts
        deployer = makeAddr("deployer");
        lpRecipient = makeAddr("lpRecipient");
        revenueRecipient = makeAddr("revenueRecipient");
        sender = makeAddr("sender");

        // Deploy BalancerV2 test utilities
        vm.startPrank(deployer);
        bytes32 salt = keccak256(abi.encode("DEPLOYER_SALT"));
        VaultDeployer vaultDeployer = new VaultDeployer(salt);
        WeightedPoolFactoryDeployer poolFactoryDeployer =
            new WeightedPoolFactoryDeployer(salt, vaultDeployer.vault());
        BalancerV2HelperDeployer bv2deployer = new BalancerV2HelperDeployer(
            salt, vaultDeployer.vault(), poolFactoryDeployer.poolFactory()
        );

        bv2helper = IBalancerV2Helper(bv2deployer.helper());
        vault = IVault(vaultDeployer.vault());

        // Deploy payment tokens
        IWOAS _woas = IWOAS(vaultDeployer.woas());
        MockSMP _smp = new MockSMP();
        poasMinter = IPOASMinter(new MockPOASMinter());

        // Create the BalancerV2 Pool
        pool = bv2helper.createPool(
            IBalancerV2Helper.PoolConfig({
                owner: address(this),
                name: "WOAS-SMP",
                symbol: "WOAS-SMP",
                swapFeePercentage: 0,
                tokenA: IERC20(address(_woas)),
                tokenB: IERC20(address(_smp))
            })
        );

        SimpleP2E _p2e = new SimpleP2E({
            poasMinter: address(poasMinter),
            liquidityPool: address(pool),
            lpRecipient: lpRecipient,
            revenueRecipient: revenueRecipient,
            smpBasePrice: smpBasePrice,
            smpBurnRatio: 5000,
            smpLiquidityRatio: 4000
        });

        p2eAddr = address(_p2e);
        p2e = ISimpleP2E(p2eAddr);
        woas = IERC20(address(_woas));
        poas = IPOAS(poasMinter.poas());
        smp = IERC20(address(_smp));

        // Grant relayer roles to helper contract
        vaultDeployer.grantRelayerRolesToHelper(address(bv2helper));
        vault.setRelayerApproval(deployer, address(bv2helper), true);

        // Add initial liquidity to the pool
        IERC20[2] memory tokens;
        uint256[2] memory amounts;
        if (woas < smp) {
            tokens[0] = woas;
            tokens[1] = smp;
            amounts[0] = initialWOASLiquidity;
            amounts[1] = initialSMPLiquidity;
        } else {
            tokens[0] = smp;
            tokens[1] = woas;
            amounts[0] = initialSMPLiquidity;
            amounts[1] = initialWOASLiquidity;
        }
        vm.deal(deployer, initialWOASLiquidity);
        _woas.deposit{value: initialWOASLiquidity}();
        _woas.approve(address(vault), initialWOASLiquidity);
        _smp.mint(deployer, initialSMPLiquidity);
        _smp.approve(address(vault), initialSMPLiquidity);
        bv2helper.addInitialLiquidity(pool, deployer, deployer, tokens, amounts);

        // Deploy MockSimpleP2EERC721 contracts
        triNFTs = new ISimpleP2EERC721[](3);
        triNFTs[0] = new MockSimpleP2EERC721("NFT1", "NFT1", p2eAddr);
        triNFTs[1] = new MockSimpleP2EERC721("NFT2", "NFT2", p2eAddr);
        triNFTs[2] = new MockSimpleP2EERC721("NFT3", "NFT3", p2eAddr);

        vm.stopPrank();

        // Mint tokens
        {
            vm.startPrank(sender);

            // for WOAS payment
            vm.deal(sender, userInitialBalance);
            _woas.deposit{value: userInitialBalance}();

            // for POAS payment
            vm.deal(sender, userInitialBalance);
            poasMinter.mint{value: userInitialBalance}(sender, userInitialBalance);

            // for SMP Payment
            vm.deal(sender, userInitialBalance);
            _smp.mint(sender, userInitialBalance);

            // for native OAS payment
            vm.deal(sender, userInitialBalance);

            vm.stopPrank();
        }
    }

    function test_getWOAS() public view {
        address woasAddr = p2e.getWOAS();
        assertEq(woasAddr, address(woas), "getWOAS should return correct WOAS address");
    }

    function test_getPOAS() public view {
        address poasAddr = p2e.getPOAS();
        assertEq(poasAddr, address(poas), "getPOAS should return correct POAS address");
    }

    function test_getSMP() public view {
        address smpAddr = p2e.getSMP();
        assertEq(smpAddr, address(smp), "getSMP should return correct SMP address");
    }

    function test_getPOASMinter() public view {
        address poasMinterAddr = p2e.getPOASMinter();
        assertEq(
            poasMinterAddr,
            address(poasMinter),
            "getPOASMinter should return correct POASMiner address"
        );
    }

    function test_getLiquidityPool() public view {
        address poolAddr = p2e.getLiquidityPool();
        assertEq(poolAddr, address(pool), "getLiquidityPool should return correct pool address");
    }

    function test_getLPRecipient() public view {
        address recipient = p2e.getLPRecipient();
        assertEq(
            recipient, lpRecipient, "getLPRecipient should return correct LP recipient address"
        );
    }

    function test_getRevenueRecipient() public view {
        address recipient = p2e.getRevenueRecipient();
        assertEq(
            recipient,
            revenueRecipient,
            "getRevenueRecipient should return correct revenue recipient address"
        );
    }

    function test_getSMPBurnRatio() public view {
        uint256 burnRatio = p2e.getSMPBurnRatio();
        assertEq(burnRatio, 5000, "getSMPBurnRatio should return 5000 (50% in basis points)");
    }

    function test_getSMPLiquidityRatio() public view {
        uint256 liquidityRatio = p2e.getSMPLiquidityRatio();
        assertEq(
            liquidityRatio, 4000, "getSMPLiquidityRatio should return 4000 (40% in basis points)"
        );
    }

    function test_queryPrice() public {
        // Test price calculation for all supported token types
        // Expected: 3 NFTs × 50 SMP each = 150 SMP base price
        // OAS price should include swap slippage: ~37.5 OAS + fees

        uint256 oasPrice = p2e.queryPrice(triNFTs, nativeOAS);
        assertGe(
            oasPrice, triNFT_OAS_Price, "OAS price should be greater than or equal to 37.5 OAS"
        );
        assertLe(
            oasPrice,
            triNFT_OAS_Price + 1.5 ether,
            "OAS price should be less than or equal to 39.0 OAS"
        );

        uint256 woasPrice = p2e.queryPrice(triNFTs, address(woas));
        assertEq(woasPrice, oasPrice, "WOAS price should equal native OAS price");

        uint256 poasPrice = p2e.queryPrice(triNFTs, address(poas));
        assertEq(poasPrice, oasPrice, "POAS price should equal native OAS price");

        uint256 smpPrice = p2e.queryPrice(triNFTs, address(smp));
        assertEq(smpPrice, triNFT_SMP_Price, "SMP price should be base price (3 x 50 SMP)");
    }

    function test_purchase_OAS() public {
        // Test P2E payment flow with native OAS
        // Payment flow: OAS -> swap to SMP -> burn 50% + LP 40% + revenue 10% (swapped back to OAS)
        vm.startPrank(sender);

        uint256 expectedLP = 30_101_582_090_568_717_949; // Expected BPT from 60 SMP liquidity
        uint256 expectedRevenue = 3_771_182_651_759_514_905; // Expected OAS from 15 SMP swap

        uint256 actualAmount = p2e.queryPrice(triNFTs, nativeOAS);
        uint256 refundAmount = 0.1 ether;
        uint256 paymentAmount = actualAmount + refundAmount;

        // Set up event expectations for the complete payment flow
        _expect_receive_token_events(nativeOAS, paymentAmount);
        _expect_swap_oas_to_smp_events(nativeOAS, actualAmount, paymentAmount);
        _expect_burn_smp_events();
        _expect_provide_liquidity_events(expectedLP);
        _expect_revenue_events(expectedRevenue);
        _expect_purchased_event(sender, nativeOAS, actualAmount, refundAmount, expectedRevenue);

        // Execute purchase with native OAS
        p2e.purchase{gas: purchaseGasLimit, value: paymentAmount}(triNFTs, nativeOAS, paymentAmount);

        // Verify that NFTs were minted to the sender
        _expect_minted_nfts(sender);

        // Verify final balances for all parties
        _expect_balances({
            _account: sender,
            _native: userInitialBalance - actualAmount,
            _woas: userInitialBalance,
            _poas: userInitialBalance,
            _smp: userInitialBalance,
            _lp: 0
        });
        _expect_balances({_account: p2eAddr, _native: 0, _woas: 0, _poas: 0, _smp: 0, _lp: 0});
        _expect_balances({
            _account: lpRecipient,
            _native: 0,
            _woas: 0,
            _poas: 0,
            _smp: 0,
            _lp: expectedLP
        });
        _expect_balances({
            _account: revenueRecipient,
            _native: expectedRevenue,
            _woas: 0,
            _poas: 0,
            _smp: 0,
            _lp: 0
        });
    }

    function test_purchase_WOAS() public {
        // Test P2E payment flow with WOAS tokens (wrapped OAS)
        // Payment flow: WOAS -> swap to SMP -> burn 50% + LP 40% + revenue 10% (swapped back to OAS)
        // Should produce identical results to native OAS payment
        vm.startPrank(sender);

        uint256 expectedLP = 30_101_582_090_568_717_949; // Same as native OAS
        uint256 expectedRevenue = 3_771_182_651_759_514_905; // Same as native OAS

        uint256 actualAmount = p2e.queryPrice(triNFTs, address(woas));
        uint256 refundAmount = 0.1 ether;
        uint256 paymentAmount = actualAmount + refundAmount;
        woas.approve(p2eAddr, paymentAmount);

        // Set up event expectations (same flow as native OAS)
        _expect_receive_token_events(address(woas), paymentAmount);
        _expect_swap_oas_to_smp_events(address(woas), actualAmount, paymentAmount);
        _expect_burn_smp_events();
        _expect_provide_liquidity_events(expectedLP);
        _expect_revenue_events(expectedRevenue);
        _expect_purchased_event(sender, address(woas), actualAmount, refundAmount, expectedRevenue);

        // Execute purchase with WOAS
        p2e.purchase{gas: purchaseGasLimit}(triNFTs, address(woas), paymentAmount);

        // Verify that NFTs were minted to the sender
        _expect_minted_nfts(sender);

        // Verify final balances (WOAS deducted instead of native OAS)
        _expect_balances({
            _account: sender,
            _native: userInitialBalance,
            _woas: userInitialBalance - actualAmount,
            _poas: userInitialBalance,
            _smp: userInitialBalance,
            _lp: 0
        });
        _expect_balances({_account: p2eAddr, _native: 0, _woas: 0, _poas: 0, _smp: 0, _lp: 0});
        _expect_balances({
            _account: lpRecipient,
            _native: 0,
            _woas: 0,
            _poas: 0,
            _smp: 0,
            _lp: expectedLP
        });
        _expect_balances({
            _account: revenueRecipient,
            _native: expectedRevenue,
            _woas: 0,
            _poas: 0,
            _smp: 0,
            _lp: 0
        });
    }

    function test_purchase_POAS() public {
        // Test P2E payment flow with POAS tokens (collateralized OAS)
        // Payment flow: POAS burn + OAS payment -> swap to SMP -> burn 50% + LP 40% + revenue 10% (swapped back to OAS)
        // Should produce identical results to native OAS payment
        vm.startPrank(sender);

        uint256 expectedLP = 30_101_582_090_568_717_949; // Same as native OAS
        uint256 expectedRevenue = 3_771_182_651_759_514_905; // Same as native OAS

        uint256 actualAmount = p2e.queryPrice(triNFTs, address(poas));
        uint256 refundAmount = 0.1 ether;
        uint256 paymentAmount = actualAmount + refundAmount;
        poas.approve(p2eAddr, paymentAmount);

        // Set up event expectations (POAS has unique burn + payment flow)
        _expect_receive_token_events(address(poas), paymentAmount);
        _expect_swap_oas_to_smp_events(address(poas), actualAmount, paymentAmount);
        _expect_burn_smp_events();
        _expect_provide_liquidity_events(expectedLP);
        _expect_revenue_events(expectedRevenue);
        _expect_purchased_event(sender, address(poas), actualAmount, refundAmount, expectedRevenue);

        // Execute purchase with POAS
        p2e.purchase{gas: purchaseGasLimit}(triNFTs, address(poas), paymentAmount);

        // Verify that NFTs were minted to the sender
        _expect_minted_nfts(sender);

        // Verify final balances (POAS burned, but same end result)
        _expect_balances({
            _account: sender,
            _native: userInitialBalance,
            _woas: userInitialBalance,
            _poas: userInitialBalance - actualAmount,
            _smp: userInitialBalance,
            _lp: 0
        });
        _expect_balances({_account: p2eAddr, _native: 0, _woas: 0, _poas: 0, _smp: 0, _lp: 0});
        _expect_balances({
            _account: lpRecipient,
            _native: 0,
            _woas: 0,
            _poas: 0,
            _smp: 0,
            _lp: expectedLP
        });
        _expect_balances({
            _account: revenueRecipient,
            _native: expectedRevenue,
            _woas: 0,
            _poas: 0,
            _smp: 0,
            _lp: 0
        });
    }

    function test_purchase_SMP() public {
        // Test P2E payment flow with SMP tokens (direct payment)
        // Payment flow: SMP direct -> burn 50% + LP 40% + revenue 10% (swapped back to OAS)
        // No initial swap needed since SMP is already the target token
        vm.startPrank(sender);

        uint256 expectedLP = 29_988_743_440_434_520_206; // Slightly different from OAS due to no swap slippage
        uint256 expectedRevenue = 3_742_978_167_339_850_000; // Different from OAS due to direct SMP usage

        uint256 actualAmount = triNFT_SMP_Price; // Direct SMP price (3 × 50 SMP)
        smp.approve(p2eAddr, actualAmount + 1);

        // Excess or shortage is not allowed for SMP payments
        vm.expectRevert(ISimpleP2E.InvalidPaymentAmount.selector);
        p2e.purchase{gas: purchaseGasLimit}(triNFTs, address(smp), actualAmount + 1);
        vm.expectRevert(ISimpleP2E.InvalidPaymentAmount.selector);
        p2e.purchase{gas: purchaseGasLimit}(triNFTs, address(smp), actualAmount - 1);

        // Set up event expectations (no initial swap, direct SMP processing)
        _expect_receive_token_events(address(smp), actualAmount);
        // Note: _expect_swap_oas_to_smp_events will skip for SMP tokens
        _expect_swap_oas_to_smp_events(address(smp), actualAmount, actualAmount);
        _expect_burn_smp_events();
        _expect_provide_liquidity_events(expectedLP);
        _expect_revenue_events(expectedRevenue);
        _expect_purchased_event(sender, address(smp), actualAmount, 0, expectedRevenue);

        // Execute purchase with SMP
        p2e.purchase{gas: purchaseGasLimit}(triNFTs, address(smp), actualAmount);

        // Verify that NFTs were minted to the sender
        _expect_minted_nfts(sender);

        // Verify final balances (SMP deducted directly)
        _expect_balances({
            _account: sender,
            _native: userInitialBalance,
            _woas: userInitialBalance,
            _poas: userInitialBalance,
            _smp: userInitialBalance - actualAmount,
            _lp: 0
        });
        _expect_balances({_account: p2eAddr, _native: 0, _woas: 0, _poas: 0, _smp: 0, _lp: 0});
        _expect_balances({
            _account: lpRecipient,
            _native: 0,
            _woas: 0,
            _poas: 0,
            _smp: 0,
            _lp: expectedLP
        });
        _expect_balances({
            _account: revenueRecipient,
            _native: expectedRevenue,
            _woas: 0,
            _poas: 0,
            _smp: 0,
            _lp: 0
        });
    }

    function _expect_receive_token_events(address tokenIn, uint256 expectedReceived) internal {
        if (tokenIn == nativeOAS) {
            return; // No events for native OAS
        }

        // Standard ERC20 tokens (WOAS, SMP): expect transfer from sender to contract
        if (tokenIn == address(woas) || tokenIn == address(smp)) {
            vm.expectEmit(tokenIn);
            emit Transfer(sender, p2eAddr, expectedReceived);
        }

        // POAS tokens: expect burn (transfer to zero) and payment event
        if (tokenIn == address(poas)) {
            // Expect POAS burn: sender -> address(0)
            vm.expectEmit(tokenIn);
            emit Transfer(sender, address(0), expectedReceived);

            // Expect POAS payment: native OAS sent to contract
            vm.expectEmit(tokenIn);
            emit Paid(sender, p2eAddr, expectedReceived);
        }
    }

    function _expect_swap_oas_to_smp_events(
        address tokenIn,
        uint256 actualAmount,
        uint256 paymentAmount
    ) internal {
        if (tokenIn == address(smp)) {
            return; // No swap needed if SMP can be used directly
        }

        if (tokenIn == address(woas)) {
            // Expect WOAS approval for swap: P2E -> Vault
            vm.expectEmit(address(woas));
            emit Approval(p2eAddr, address(vault), paymentAmount);
        }

        // Expect swap: tokenIn -> SMP (always results in triNFT_SMP_Price SMP)
        vm.expectEmit(address(vault));
        emit Swap(pool.getPoolId(), woas, smp, actualAmount, triNFT_SMP_Price);

        if (tokenIn == address(woas)) {
            // Expect WOAS transfer for swap: P2E -> Vault
            vm.expectEmit(address(woas));
            emit Transfer(p2eAddr, address(vault), actualAmount);
        }
    }

    function _expect_burn_smp_events() internal {
        // Expect SMP burn
        vm.expectEmit(address(smp));
        emit Transfer(p2eAddr, address(0), triNFT_SMP_Burn);
    }

    function _expect_provide_liquidity_events(uint256 expectedLPout) internal {
        // Expect SMP approval for liquidity provision
        vm.expectEmit(address(smp));
        emit Approval(p2eAddr, address(vault), triNFT_SMP_Liquidity);

        // Expect BPT transfer: LP tokens to LP recipient (minted from address(0))
        vm.expectEmit(address(pool));
        emit Transfer(address(0), lpRecipient, expectedLPout);

        // Expect SMP transfer for liquidity provision to vault
        vm.expectEmit(address(smp));
        emit Transfer(p2eAddr, address(vault), triNFT_SMP_Liquidity);
    }

    function _expect_revenue_events(uint256 expectedOASout) internal {
        // Expect SMP approval for revenue swap
        vm.expectEmit(address(smp));
        emit Approval(p2eAddr, address(vault), triNFT_SMP_Revenue);

        // Expect revenue swap: SMP -> WOAS
        vm.expectEmit(address(vault));
        emit Swap(pool.getPoolId(), smp, woas, triNFT_SMP_Revenue, expectedOASout);

        // Expect WOAS burn to native OAS (vault burns WOAS)
        vm.expectEmit(address(woas));
        emit Transfer(address(vault), address(0), expectedOASout);

        // Expect WOAS withdrawal to native OAS (sent to revenue recipient)
        vm.expectEmit(address(woas));
        emit Withdrawal(address(vault), expectedOASout);

        // Expect SMP transfer for revenue swap to vault
        vm.expectEmit(address(smp));
        emit Transfer(p2eAddr, address(vault), triNFT_SMP_Revenue);
    }

    function _expect_purchased_event(
        address buyer,
        address paymentToken,
        uint256 actualAmount,
        uint256 refundAmount,
        uint256 expectedRevenueOAS
    ) internal {
        vm.expectEmit(p2eAddr);
        emit ISimpleP2E.Purchased(
            buyer,
            triNFTs,
            paymentToken,
            actualAmount,
            refundAmount,
            triNFT_SMP_Burn,
            triNFT_SMP_Liquidity,
            triNFT_SMP_Revenue,
            expectedRevenueOAS,
            revenueRecipient,
            lpRecipient
        );
    }

    function _expect_balances(
        address _account,
        uint256 _native,
        uint256 _woas,
        uint256 _poas,
        uint256 _smp,
        uint256 _lp
    ) internal view {
        assertEq(_account.balance, _native);
        assertEq(woas.balanceOf(_account), _woas);
        assertEq(poas.balanceOf(_account), _poas);
        assertEq(smp.balanceOf(_account), _smp);
        assertEq(IERC20(address(pool)).balanceOf(_account), _lp);
    }

    function _expect_minted_nfts(address _account) internal view {
        for (uint256 i = 0; i < triNFTs.length; i++) {
            assertEq(triNFTs[i].ownerOf(0), _account);
        }
    }
}
