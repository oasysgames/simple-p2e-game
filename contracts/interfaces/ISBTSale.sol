// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import {ISBTSaleERC721} from "./ISBTSaleERC721.sol";

/**
 * @title ISBTSale
 * @notice Contract for acquiring NFT assets by paying tokens.
 *
 * Basic Specifications
 * - Supports 4 payment token types:
 *   - Native OAS
 *   - WOAS (contracts/test-utils/interfaces/IWOAS.sol)
 *   - POAS (contracts/interfaces/IPOAS.sol)
 *   - SMP (contracts/interfaces/ISMP.sol)
 * - Single payment method supports all token types
 * - SMP token requires a Balancer V2 compliant liquidity pool (LP) with WOAS
 * - Multiple NFTs can be acquired in a single payment, but only one payment token type per transaction
 * - NFT pricing is based on SMP token with a current fixed price of 50 SMP
 *
 */
interface ISBTSale {
    // Errors
    error InvalidPaymentToken(); // 0x56e7ec5f
    error InvalidRecipient(); // 0x9c8d2cd2
    error InvalidPaymentAmount(); // 0xfc512fde
    error InvalidProtocolValue(); // 0x3c88b7e9
    error InvalidPool(); // 0x2083cd40
    error InvalidAddress(); // 0xe6c4247b
    error InvalidSwap(string message); // 0x3bea1958
    error NoItems(); // 0x0483ac36
    error ArrayLengthMismatch(); // 0xa24a13a6
    error TransferFailed(); // 0x90b8ec18

    // Events
    /// @dev Emitted when NFTs are purchased with complete protocol information
    /// @param buyer Address of the buyer
    /// @param nfts Array of NFT contracts purchased
    /// @param paymentToken Token used for payment
    /// @param actualAmount Amount actually used for payment
    /// @param refundAmount Amount refunded to the buyer
    /// @param burnSMP Amount of SMP burned
    /// @param liquiditySMP Amount of SMP provided to liquidity pool
    /// @param revenueSMP Amount of SMP allocated for revenue
    /// @param revenueOAS Amount of OAS transferred to revenue recipient
    /// @param revenueRecipient Address receiving the OAS revenue
    /// @param lpRecipient Address receiving the LP tokens
    event Purchased(
        address buyer,
        ISBTSaleERC721[] nfts,
        address paymentToken,
        uint256 actualAmount,
        uint256 refundAmount,
        uint256 burnSMP,
        uint256 liquiditySMP,
        uint256 revenueSMP,
        uint256 revenueOAS,
        address revenueRecipient,
        address lpRecipient
    );

    /**
     * @dev Query total required token amount for purchasing specified NFTs
     *
     * This method calculates the total payment amount needed for the specified NFTs:
     * - Takes an array of NFT contract addresses to purchase
     * - Takes the payment token address to be used
     * - For non-SMP tokens, queries the LP for the required token amount due to swap requirements
     *
     * Note: This method is not a 'view' function due to Balancer V2 design constraints.
     *       Therefore, callers must explicitly use `eth_call` to call it.
     *
     * @param nfts Array of NFT contracts to get pricing for
     * @param token Token address for payment (native OAS: 0x0, WOAS, POAS, or SMP)
     * @return price Total required token amount for all NFTs
     */
    function queryPrice(ISBTSaleERC721[] calldata nfts, address token)
        external
        returns (uint256 price);

    /**
     * @dev Purchase NFTs using any supported token
     *
     * Payment Process:
     * 1. User initiates payment with the following parameters:
     *    - Array of NFT contract addresses to purchase
     *    - Payment token address (ERC20.approve required for non-native OAS)
     *    - Payment amount in the specified token (not SMP amount)
     *    - Excess payments are refunded using the same token type
     * 2. For non-native OAS payments, receives tokens via ERC20.transferFrom
     *    - POAS payments are received as native OAS
     * 3. Calculates required SMP token amount for the purchase
     * 4. For non-SMP payments, swaps to required SMP amount using LP.
     *    Excess payment tokens are refunded at this stage.
     * 5. Burns SMP at pre-configured ratio
     * 6. Provides SMP to LP at pre-configured ratio
     *    - LP tokens are sent to pre-configured dedicated address
     * 7. Swaps remaining SMP to OAS via LP and sends to pre-configured address
     * 8. Mints and transfers NFTs to msg.sender
     * 9. Refunds excess payment tokens remaining from step 4 swap
     *
     * @param nfts Array of NFT contracts to purchase
     * @param token Token address for payment:
     *              - 0x0000000000000000000000000000000000000000 for native OAS
     *              - 0x5200000000000000000000000000000000000001 for WOAS
     *              - Dynamic addresses for POAS and SMP (must be registered)
     * @param amount Total payment amount in the specified token for all NFTs.
     *               Note: Obtain this value beforehand using queryPrice.
     */
    function purchase(ISBTSaleERC721[] calldata nfts, address token, uint256 amount)
        external
        payable;

    // View functions

    /**
     * @dev Get WOAS address
     * @return woas WOAS token address
     */
    function getWOAS() external view returns (address woas);

    /**
     * @dev Get current POAS address
     * @return poas Current POAS token address
     */
    function getPOAS() external view returns (address poas);

    /**
     * @dev Get current SMP address
     * @return smp SMP token address
     */
    function getSMP() external view returns (address smp);

    /**
     * @dev Get current POASMinter contract address
     * @return poasMinter Current POASMinter contract address
     */
    function getPOASMinter() external view returns (address poasMinter);

    /**
     * @dev Get Balancer V2 pool address
     * @return pool Address of the Balancer V2 pool for WOAS-SMP
     */
    function getLiquidityPool() external view returns (address pool);

    /**
     * @dev Get LP token recipient address
     * @return recipient Address receiving LP tokens (BPT)
     */
    function getLPRecipient() external view returns (address recipient);

    /**
     * @dev Get revenue recipient address
     * @return recipient Address receiving OAS revenue
     */
    function getRevenueRecipient() external view returns (address recipient);

    /**
     * @dev Get SMP burn ratio
     * @return burnRatio SMP burn ratio in basis points
     */
    function getSMPBurnRatio() external view returns (uint256 burnRatio);

    /**
     * @dev Get SMP liquidity provision ratio
     * @return liquidityRatio SMP liquidity provision ratio in basis points
     */
    function getSMPLiquidityRatio() external view returns (uint256 liquidityRatio);
}
