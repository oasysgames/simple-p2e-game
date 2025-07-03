// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

// OpenZeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// BalancerV2
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IAsset} from "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import {IERC20 as BalancerV2IERC20} from
    "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {WeightedPoolUserData} from
    "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

// Local interfaces
import {ISBTSale} from "./interfaces/ISBTSale.sol";
import {IVaultPool} from "./interfaces/IVaultPool.sol";
import {ISBTSaleERC721} from "./interfaces/ISBTSaleERC721.sol";
import {IPOAS} from "./interfaces/IPOAS.sol";
import {IPOASMinter} from "./interfaces/IPOASMinter.sol";

/**
 * @title SBTSale
 * @dev Contract for selling SBTs using multiple payment tokens. Handles SMP burning,
 *      liquidity provision and revenue distribution.
 */
contract SBTSale is ISBTSale, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @dev Data structure for swap operation
    struct SwapData {
        address tokenIn; // Token to swap from
        address tokenOut; // Token to swap to
        uint256 amountIn; // Amount to swap
        uint256 amountOut; // Minimum amount to receive (0 = protocol determined)
        address recipient; // Address to receive the swapped tokens
    }

    // Native OAS and WOAS addresses
    address private constant NATIVE_OAS = address(0);

    // Basis points for ratio calculations (10000 = 100%)
    uint256 public constant MAX_BASIS_POINTS = 10_000;

    // Immutable configuration
    address private immutable _vault;
    address private immutable _woas;
    address private immutable _poasMinter;
    address private immutable _smp;
    address private immutable _liquidityPool;
    address private immutable _lpRecipient;
    address private immutable _revenueRecipient;
    uint256 private immutable _smpBasePrice;
    uint256 private immutable _smpBurnRatio;
    uint256 private immutable _smpLiquidityRatio;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address poasMinter,
        address liquidityPool,
        address lpRecipient,
        address revenueRecipient,
        uint256 smpBasePrice,
        uint256 smpBurnRatio,
        uint256 smpLiquidityRatio
    ) {
        if (_isZeroAddress(poasMinter) || _isZeroAddress(liquidityPool)) {
            revert InvalidPaymentToken();
        }
        if (_isZeroAddress(lpRecipient) || _isZeroAddress(revenueRecipient)) {
            revert InvalidRecipient();
        }
        if (smpBasePrice == 0) {
            revert InvalidPaymentAmount();
        }
        if (smpBurnRatio + smpLiquidityRatio > MAX_BASIS_POINTS) {
            revert InvalidProtocolValue();
        }

        // Get vault and pool tokens from liquidityPool
        IVaultPool pool = IVaultPool(liquidityPool);
        IVault vault = pool.getVault();
        (BalancerV2IERC20[] memory poolTokens,,) = vault.getPoolTokens(pool.getPoolId());
        if (poolTokens.length != 2) {
            revert InvalidPool();
        }

        // Get WOAS from vault.WETH() and determine SMP
        address woas = address(vault.WETH());
        address smp;
        if (address(poolTokens[0]) == woas) {
            smp = address(poolTokens[1]);
        } else if (address(poolTokens[1]) == woas) {
            smp = address(poolTokens[0]);
        } else {
            revert InvalidPool();
        }

        _vault = address(vault);
        _woas = woas;
        _poasMinter = poasMinter;
        _smp = smp;
        _liquidityPool = liquidityPool;
        _lpRecipient = lpRecipient;
        _revenueRecipient = revenueRecipient;
        _smpBurnRatio = smpBurnRatio;
        _smpLiquidityRatio = smpLiquidityRatio;
        _smpBasePrice = smpBasePrice;

        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();
    }

    /// @inheritdoc ISBTSale
    function getWOAS() external view returns (address poas) {
        return _woas;
    }

    /// @inheritdoc ISBTSale
    function getPOAS() external view returns (address poas) {
        return IPOASMinter(_poasMinter).poas();
    }

    /// @inheritdoc ISBTSale
    function getSMP() external view returns (address smp) {
        return _smp;
    }

    /// @inheritdoc ISBTSale
    function getPOASMinter() external view returns (address poasMinter) {
        return _poasMinter;
    }

    /// @inheritdoc ISBTSale
    function getLiquidityPool() external view returns (address pool) {
        return _liquidityPool;
    }

    /// @inheritdoc ISBTSale
    function getLPRecipient() external view returns (address recipient) {
        return _lpRecipient;
    }

    /// @inheritdoc ISBTSale
    function getRevenueRecipient() external view returns (address recipient) {
        return _revenueRecipient;
    }

    /// @inheritdoc ISBTSale
    function getSMPBurnRatio() external view returns (uint256 burnRatio) {
        return _smpBurnRatio;
    }

    /// @inheritdoc ISBTSale
    function getSMPLiquidityRatio() external view returns (uint256 liquidityRatio) {
        return _smpLiquidityRatio;
    }

    /// @inheritdoc ISBTSale
    /// @dev Note: This method is not a 'view' function due to Balancer V2 design constraints.
    ///            Therefore, callers must explicitly use `eth_call` to call it.
    function queryPrice(ISBTSaleERC721[] calldata nfts, address paymentToken)
        public
        returns (uint256 price)
    {
        /// Note: Do not check msg.sender's token balances in this method or related methods.
        /// This method must return the same price regardless of who the caller is.
        /// `IVault.queryBatchSwap` is also designed to not depend on msg.sender's WOAS/SMP balances.

        if (nfts.length == 0) {
            revert NoItems();
        }
        if (!_isValidPaymentToken(paymentToken)) {
            revert InvalidPaymentToken();
        }

        uint256 smpPrice = _getTotalSMPPrice(nfts);
        return _isSMP(paymentToken) ? smpPrice : _getRequiredOASFromLP(paymentToken, smpPrice);
    }

    /// @inheritdoc ISBTSale
    function purchase(ISBTSaleERC721[] calldata nfts, address paymentToken, uint256 amount)
        external
        payable
        nonReentrant
    {
        // Note: Do not call _getRequiredOASFromLP within this method.
        // More precisely, do not call `IVault.queryBatchSwap` within methods that perform actual token swaps.
        // This makes the contract vulnerable to sandwich attacks that exploit the mempool.
        // Reference: https://docs-v2.balancer.fi/reference/swaps/batch-swaps.html#querybatchswap

        if (nfts.length == 0) {
            revert NoItems();
        }
        if (!_isValidPaymentToken(paymentToken)) {
            revert InvalidPaymentToken();
        }

        // Receive payment token from buyer
        _receiveToken(msg.sender, paymentToken, amount);

        // Calculate total SMP price required for all NFTs
        uint256 requiredSMP = _getTotalSMPPrice(nfts);

        // Swap payment token to SMP
        uint256 actualAmount = _payWithSwapToSMP(paymentToken, amount, requiredSMP);
        uint256 refundAmount = amount - actualAmount;

        // Burn configured percentage of SMP
        uint256 burnSMP = _burnSMP(requiredSMP);

        // Provide configured percentage of SMP to liquidity pool
        uint256 liquiditySMP = _provideLiquidity(requiredSMP);

        // Swap remaining SMP to OAS for protocol revenue
        uint256 revenueSMP = requiredSMP - burnSMP - liquiditySMP;
        uint256 revenueOAS;
        if (revenueSMP > 0) {
            revenueOAS = _swapSMPtoOASForRevenueRecipient(revenueSMP);
        }

        // Mint NFTs to buyer
        _mintNFTs(msg.sender, nfts);

        // Refund excess native OAS/WOAS/POAS
        if (refundAmount > 0) {
            _refundAnyOAS(msg.sender, paymentToken, refundAmount);
        }

        // Emit comprehensive purchase event
        emit Purchased(
            msg.sender,
            nfts,
            paymentToken,
            actualAmount,
            refundAmount,
            burnSMP,
            liquiditySMP,
            revenueSMP,
            revenueOAS,
            _revenueRecipient,
            _lpRecipient
        );
    }

    /// @dev Check if the address is zero
    function _isZeroAddress(address addr) internal pure returns (bool) {
        return addr == address(0);
    }

    /// @dev Check if the token is native OAS
    function _isNativeOAS(address paymentToken) internal pure returns (bool) {
        return paymentToken == NATIVE_OAS;
    }

    /// @dev Check if the token is WOAS
    function _isWOAS(address paymentToken) internal view returns (bool) {
        return paymentToken == _woas;
    }

    /// @dev Check if the token is POAS
    function _isPOAS(address paymentToken) internal view returns (bool) {
        return paymentToken == IPOASMinter(_poasMinter).poas();
    }

    /// @dev Check if the token is SMP
    function _isSMP(address paymentToken) internal view returns (bool) {
        return paymentToken == _smp;
    }

    /// @dev Validate if the payment token is supported
    function _isValidPaymentToken(address paymentToken) internal view returns (bool) {
        return _isNativeOAS(paymentToken) || _isWOAS(paymentToken) || _isPOAS(paymentToken)
            || _isSMP(paymentToken);
    }

    /// @dev Convert IERC20 array to IAsset array for Balancer V2 compatibility
    /// @return assets Converted IAsset array
    /// @return woasIndex Index of WOAS in the assets array
    /// @return smpIndex Index of SMP in the assets array
    function _getPoolAssets()
        internal
        view
        returns (IAsset[] memory assets, uint8 woasIndex, uint8 smpIndex)
    {
        assets = new IAsset[](2);
        woasIndex = _woas < _smp ? 0 : 1;
        smpIndex = woasIndex ^ 1; // 0->1, 1->0
        assets[woasIndex] = IAsset(_woas);
        assets[smpIndex] = IAsset(_smp);
    }

    /// @dev Get the balance of a token in this contract
    /// @param paymentToken Token address
    /// @return Token balance held by this contract
    function _getBalance(address paymentToken) internal view returns (uint256) {
        // Native OAS and POAS use contract's OAS balance
        if (_isNativeOAS(paymentToken) || _isPOAS(paymentToken)) {
            return address(this).balance;
        } else {
            // ERC20 tokens use standard balanceOf
            return IERC20(paymentToken).balanceOf(address(this));
        }
    }

    /// @dev Get the total SMP price for a list of NFTs
    /// @param nfts Array of NFT contracts to calculate price for
    /// @return totalSMPPrice Total SMP required (nfts.length × base price)
    function _getTotalSMPPrice(ISBTSaleERC721[] calldata nfts)
        internal
        view
        returns (uint256 totalSMPPrice)
    {
        uint256 length = nfts.length;

        // Calculate total: each NFT costs the base SMP price
        for (uint256 i = 0; i < length; ++i) {
            if (_isZeroAddress(address(nfts[i]))) {
                revert InvalidAddress();
            }
            totalSMPPrice += _smpBasePrice;
        }
    }

    /// @dev Receive token from buyer and validate amount
    /// @param from Address of the buyer
    /// @param paymentToken Payment token address
    /// @param amount Expected amount to receive
    function _receiveToken(address from, address paymentToken, uint256 amount) internal {
        // Native OAS: validate msg.value
        if (_isNativeOAS(paymentToken)) {
            if (msg.value != amount) {
                revert InvalidPaymentAmount();
            }
            return;
        }

        // ERC20 tokens: msg.value must be zero
        if (msg.value != 0) {
            revert InvalidPaymentAmount();
        }

        // Execute ERC20 transfer and validate received amount
        // Note: POAS burns tokens and sends equivalent OAS to this contract
        uint256 beforeBalance = _getBalance(paymentToken);
        IERC20(paymentToken).transferFrom(from, address(this), amount);
        if (_getBalance(paymentToken) - beforeBalance != amount) {
            revert InvalidPaymentAmount();
        }
    }

    /// @dev Execute token swap via WOAS-SMP pool
    /// @param swapData Swap configuration data
    /// @return actualIn Actual input token amount swapped
    /// @return actualOut Actual output token amount swapped
    function _swap(SwapData memory swapData)
        internal
        returns (uint256 actualIn, uint256 actualOut)
    {
        if (swapData.amountIn == 0) {
            revert InvalidPaymentAmount();
        }

        (IAsset[] memory assets, uint8 woasIndex, uint8 smpIndex) = _getPoolAssets();
        if (
            _isNativeOAS(swapData.tokenIn) // Native OAS -> SMP
                || _isPOAS(swapData.tokenIn) // Native OAS (converted from POAS) -> SMP
                || _isNativeOAS(swapData.tokenOut) // SMP -> Native OAS
        ) {
            assets[woasIndex] = IAsset(NATIVE_OAS);
        }

        // Map tokens to pool asset indices
        uint8 tokenInIndex = _isSMP(swapData.tokenIn) ? smpIndex : woasIndex;
        uint8 tokenOutIndex = tokenInIndex ^ 1; // Flip index: 0->1, 1->0

        // Configure swap parameters
        IVault.FundManagement memory funds = IVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(swapData.recipient),
            toInternalBalance: false
        });

        // Configure swap parameters based on whether exact output is required
        IVault.SwapKind swapKind;
        IVault.BatchSwapStep[] memory swaps;
        int256[] memory limits = new int256[](2);

        // Set maximum input limit for both swap types
        limits[tokenInIndex] = int256(swapData.amountIn);

        if (swapData.amountOut > 0) {
            // GIVEN_OUT: Specify exact output amount (e.g., exactly 150 SMP)
            // Used when we need precise output amount for protocol calculations
            swapKind = IVault.SwapKind.GIVEN_OUT;
            swaps = _createSwapSteps(swapData.amountOut, tokenInIndex, tokenOutIndex);
            limits[tokenOutIndex] = -int256(swapData.amountOut); // Negative = exact output required
        } else {
            // GIVEN_IN: Specify exact input amount (e.g., swap all available SMP)
            // Used when we want to swap all of a token without caring about exact output
            swapKind = IVault.SwapKind.GIVEN_IN;
            swaps = _createSwapSteps(swapData.amountIn, tokenInIndex, tokenOutIndex);
            limits[tokenOutIndex] = int256(0); // Zero = no minimum output constraint
        }

        // Execute swap with 5-minute deadline
        uint256 deadline = block.timestamp + 5 minutes;

        int256[] memory deltas;
        if (_isNativeOAS(swapData.tokenIn) || _isPOAS(swapData.tokenIn)) {
            // Native OAS swap requires msg.value
            deltas = IVault(_vault).batchSwap{value: swapData.amountIn}({
                kind: swapKind,
                swaps: swaps,
                assets: assets,
                funds: funds,
                limits: limits,
                deadline: deadline
            });
        } else {
            // ERC20 token swap
            deltas = IVault(_vault).batchSwap({
                kind: swapKind,
                swaps: swaps,
                assets: assets,
                funds: funds,
                limits: limits,
                deadline: deadline
            });
        }

        if (deltas[tokenInIndex] < 0 || deltas[tokenOutIndex] > 0) {
            revert InvalidSwap("Unexpected balance changes");
        }
        actualIn = uint256(deltas[tokenInIndex]);
        actualOut = uint256(-deltas[tokenOutIndex]);

        if (actualIn > swapData.amountIn) {
            revert InvalidSwap("Input token exceeded limit");
        }
        if (swapData.amountOut > 0 && actualOut != swapData.amountOut) {
            revert InvalidSwap("Output token below required amount");
        }
    }

    /// @dev Swap payment tokens to SMP via WOAS-SMP liquidity pool
    /// @param paymentToken Token to swap from (NATIVE_OAS/WOAS/POAS)
    /// @param paymentAmount Payment token amount used for swap input
    /// @param requiredSMP SMP token amount required for swap output
    /// @return actualIn Actual input token amount used in swap
    function _payWithSwapToSMP(address paymentToken, uint256 paymentAmount, uint256 requiredSMP)
        internal
        returns (uint256 actualIn)
    {
        uint256 actualOut;
        if (_isSMP(paymentToken)) {
            // Already SMP, no swap needed
            (actualIn, actualOut) = (paymentAmount, paymentAmount);
        } else {
            if (_isWOAS(paymentToken)) {
                IERC20(paymentToken).approve(_vault, paymentAmount);
            }

            // Execute swap: OAS/WOAS -> SMP
            (actualIn, actualOut) = _swap(
                SwapData({
                    tokenIn: paymentToken, // Native OAS (including converted POAS) is passed as address(0)
                    tokenOut: _smp,
                    amountIn: paymentAmount,
                    amountOut: requiredSMP, // Expect exactly this amount (GIVEN_OUT)
                    recipient: address(this)
                })
            );
        }

        // Verify we received the exact SMP amount needed for the purchase
        if (actualOut != requiredSMP) {
            revert InvalidPaymentAmount();
        }
    }

    /// @dev Create BatchSwapStep for token swap
    /// @param amount Amount to swap
    /// @param tokenInIndex Index of input token in assets array
    /// @param tokenOutIndex Index of output token in assets array
    /// @return swaps BatchSwapStep array
    function _createSwapSteps(uint256 amount, uint8 tokenInIndex, uint8 tokenOutIndex)
        internal
        view
        returns (IVault.BatchSwapStep[] memory swaps)
    {
        swaps = new IVault.BatchSwapStep[](1);
        swaps[0] = IVault.BatchSwapStep({
            poolId: IVaultPool(_liquidityPool).getPoolId(),
            assetInIndex: tokenInIndex,
            assetOutIndex: tokenOutIndex,
            amount: amount,
            userData: ""
        });
    }

    /// @dev Get required OAS amount from LP to obtain specific SMP amount
    ///      Note: that this function is not 'view' (due to implementation details)
    /// @param paymentToken Token to swap from (OAS/WOAS/POAS)
    /// @param requiredSMP Required SMP amount to obtain
    /// @return requiredOAS Required OAS/WOAS amount to swap via LP
    function _getRequiredOASFromLP(address paymentToken, uint256 requiredSMP)
        internal
        returns (uint256 requiredOAS)
    {
        (IAsset[] memory assets, uint8 woasIndex, uint8 smpIndex) = _getPoolAssets();
        if (_isNativeOAS(paymentToken) || _isPOAS(paymentToken)) {
            assets[woasIndex] = IAsset(NATIVE_OAS); // Use native OAS for swap
        }

        // Create swap steps for GIVEN_OUT query
        IVault.BatchSwapStep[] memory swaps = _createSwapSteps(requiredSMP, woasIndex, smpIndex);
        IVault.FundManagement memory funds = IVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        // Query batch swap to get required input amount
        int256[] memory deltas = IVault(_vault).queryBatchSwap({
            kind: IVault.SwapKind.GIVEN_OUT,
            swaps: swaps,
            assets: assets,
            funds: funds
        });

        // Get required OAS amount (will be positive)
        requiredOAS = uint256(deltas[woasIndex]);
    }

    /// @dev Burn SMP tokens according to configured burn ratio
    /// @param totalSMP Total SMP amount to be processed
    /// @return burnedSMP Actual amount of SMP burned
    function _burnSMP(uint256 totalSMP) internal returns (uint256 burnedSMP) {
        burnedSMP = (totalSMP * _smpBurnRatio) / MAX_BASIS_POINTS;
        ERC20Burnable(_smp).burn(burnedSMP);
    }

    /// @dev Provide configured ratio of SMP to LP as single-sided liquidity
    /// @param totalSMP Total SMP amount to be processed
    /// @return providedSMP Actual amount of SMP provided to LP
    function _provideLiquidity(uint256 totalSMP) internal returns (uint256 providedSMP) {
        // Calculate liquidity provision amount based on configured ratio
        providedSMP = (totalSMP * _smpLiquidityRatio) / MAX_BASIS_POINTS;

        // Setup pool interaction parameters
        (IAsset[] memory assets, uint8 woasIndex, uint8 smpIndex) = _getPoolAssets();
        uint256[] memory maxAmountsIn = new uint256[](2);
        maxAmountsIn[woasIndex] = 0; // No WOAS
        maxAmountsIn[smpIndex] = providedSMP; // Only SMP

        // Execute pool join with single-sided SMP liquidity
        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: assets,
            maxAmountsIn: maxAmountsIn,
            userData: abi.encode(
                WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, 0
            ),
            fromInternalBalance: false
        });

        // Approve vault to spend SMP
        IVault vault = IVault(_vault);
        IERC20(_smp).approve(address(vault), providedSMP);

        // Provide liquidity to the pool
        vault.joinPool({
            poolId: IVaultPool(_liquidityPool).getPoolId(),
            sender: address(this),
            recipient: _lpRecipient, // LP tokens sent directly to LP recipient
            request: request
        });
    }

    /// @dev Swap SMP to OAS and send to revenue recipient
    /// @param revenueSMP Amount of SMP to swap for revenue
    /// @return revenueOAS Amount of OAS received from swap
    function _swapSMPtoOASForRevenueRecipient(uint256 revenueSMP)
        internal
        returns (uint256 revenueOAS)
    {
        IERC20(_smp).approve(_vault, revenueSMP);

        // Execute swap: SMP -> native OAS
        (, revenueOAS) = _swap(
            SwapData({
                tokenIn: _smp,
                tokenOut: NATIVE_OAS,
                amountIn: revenueSMP,
                amountOut: 0, // Accept any amount out (GIVEN_IN)
                recipient: _revenueRecipient // OAS sent directly to revenue recipient
            })
        );

        if (revenueOAS == 0) {
            revert InvalidPaymentAmount();
        }
    }

    /// @dev Mint NFTs to buyer for each contract in the array
    /// @param to Address to receive the minted NFTs
    /// @param nfts Array of NFT contracts to mint from
    function _mintNFTs(address to, ISBTSaleERC721[] calldata nfts) internal {
        uint256 length = nfts.length;
        for (uint256 i = 0; i < length; ++i) {
            nfts[i].mint(to);
        }
    }

    /// @dev Refund excess payment tokens (native OAS/WOAS/POAS) using the same token type
    function _refundAnyOAS(address to, address paymentToken, uint256 amount) internal {
        if (_isNativeOAS(paymentToken)) {
            Address.sendValue(payable(to), amount);
        } else if (_isPOAS(paymentToken)) {
            IPOASMinter(_poasMinter).mint{value: amount}(to, amount);
        } else if (_isWOAS(paymentToken)) {
            IERC20(paymentToken).transfer(to, amount);
        }
    }

    receive() external payable {}
}
