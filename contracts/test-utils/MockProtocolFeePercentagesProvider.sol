// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import {IProtocolFeePercentagesProvider} from
    "../../lib/balancer-v2-monorepo/pkg/interfaces/contracts/standalone-utils/IProtocolFeePercentagesProvider.sol";

/**
 * @title MockProtocolFeePercentagesProvider
 * @notice Mock implementation of Balancer V2 protocol fee percentages provider for testing
 */
contract MockProtocolFeePercentagesProvider is IProtocolFeePercentagesProvider {
    /// @dev Mapping to track valid fee types
    mapping(uint256 => bool) private _validFeeTypes;
    /// @dev Mapping to store current fee percentages for each fee type
    mapping(uint256 => uint256) private _feePercentages;
    /// @dev Mapping to store maximum allowed percentages for each fee type
    mapping(uint256 => uint256) private _maximumPercentages;
    /// @dev Mapping to store human-readable names for each fee type
    mapping(uint256 => string) private _feeNames;

    /**
     * @notice Initialize the mock fee provider with standard Balancer V2 fee types
     * @dev Registers 4 standard fee types with 10% maximum and 0% initial values for testing
     */
    constructor() {
        // Register standard Balancer V2 fee types with zero initial fees for testing
        _registerFeeType(0, "SWAP", 1e17, 0); // 10% max, 0% initial
        _registerFeeType(1, "FLASH_LOAN", 1e17, 0); // 10% max, 0% initial
        _registerFeeType(2, "YIELD", 1e17, 0); // 10% max, 0% initial
        _registerFeeType(3, "AUM", 1e17, 0); // 10% max, 0% initial
    }

    /**
     * @notice Internal function to register a new fee type
     * @dev Sets up all necessary mappings for a fee type
     * @param feeType Unique identifier for the fee type
     * @param name Human-readable name for the fee type
     * @param maximumValue Maximum allowed percentage (1e18 = 100%)
     * @param initialValue Initial percentage value (1e18 = 100%)
     */
    function _registerFeeType(
        uint256 feeType,
        string memory name,
        uint256 maximumValue,
        uint256 initialValue
    ) internal {
        _validFeeTypes[feeType] = true;
        _feePercentages[feeType] = initialValue;
        _maximumPercentages[feeType] = maximumValue;
        _feeNames[feeType] = name;
    }

    /**
     * @inheritdoc IProtocolFeePercentagesProvider
     */
    function registerFeeType(
        uint256 feeType,
        string memory name,
        uint256 maximumValue,
        uint256 initialValue
    ) external override {
        _registerFeeType(feeType, name, maximumValue, initialValue);
    }

    /**
     * @inheritdoc IProtocolFeePercentagesProvider
     */
    function isValidFeeType(uint256 feeType) external view override returns (bool) {
        return _validFeeTypes[feeType];
    }

    /**
     * @inheritdoc IProtocolFeePercentagesProvider
     */
    function isValidFeeTypePercentage(uint256 feeType, uint256 value)
        external
        view
        override
        returns (bool)
    {
        return _validFeeTypes[feeType] && value <= _maximumPercentages[feeType];
    }

    /**
     * @inheritdoc IProtocolFeePercentagesProvider
     */
    function setFeeTypePercentage(uint256 feeType, uint256 newValue) external override {
        require(_validFeeTypes[feeType], "Invalid fee type");
        require(newValue <= _maximumPercentages[feeType], "Exceeds maximum");
        _feePercentages[feeType] = newValue;
    }

    /**
     * @inheritdoc IProtocolFeePercentagesProvider
     */
    function getFeeTypePercentage(uint256 feeType) external view override returns (uint256) {
        return _feePercentages[feeType];
    }

    /**
     * @inheritdoc IProtocolFeePercentagesProvider
     */
    function getFeeTypeMaximumPercentage(uint256 feeType)
        external
        view
        override
        returns (uint256)
    {
        return _maximumPercentages[feeType];
    }

    /**
     * @inheritdoc IProtocolFeePercentagesProvider
     */
    function getFeeTypeName(uint256 feeType) external view override returns (string memory) {
        return _feeNames[feeType];
    }
}
