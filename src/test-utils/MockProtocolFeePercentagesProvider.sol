// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IProtocolFeePercentagesProvider} from
    "../../lib/balancer-v2-monorepo/pkg/interfaces/contracts/standalone-utils/IProtocolFeePercentagesProvider.sol";

/**
 * @title MockProtocolFeePercentagesProvider
 * @dev Mock implementation for testing
 */
contract MockProtocolFeePercentagesProvider is IProtocolFeePercentagesProvider {
    mapping(uint256 => bool) private _validFeeTypes;
    mapping(uint256 => uint256) private _feePercentages;
    mapping(uint256 => uint256) private _maximumPercentages;
    mapping(uint256 => string) private _feeNames;

    constructor() {
        // Register basic fee types
        _registerFeeType(0, "SWAP", 1e17, 0); // 10% max, 0% initial
        _registerFeeType(1, "FLASH_LOAN", 1e17, 0); // 10% max, 0% initial
        _registerFeeType(2, "YIELD", 1e17, 0); // 10% max, 0% initial
        _registerFeeType(3, "AUM", 1e17, 0); // 10% max, 0% initial
    }

    function _registerFeeType(uint256 feeType, string memory name, uint256 maximumValue, uint256 initialValue)
        internal
    {
        _validFeeTypes[feeType] = true;
        _feePercentages[feeType] = initialValue;
        _maximumPercentages[feeType] = maximumValue;
        _feeNames[feeType] = name;
    }

    function registerFeeType(uint256 feeType, string memory name, uint256 maximumValue, uint256 initialValue)
        external
        override
    {
        _registerFeeType(feeType, name, maximumValue, initialValue);
    }

    function isValidFeeType(uint256 feeType) external view override returns (bool) {
        return _validFeeTypes[feeType];
    }

    function isValidFeeTypePercentage(uint256 feeType, uint256 value) external view override returns (bool) {
        return _validFeeTypes[feeType] && value <= _maximumPercentages[feeType];
    }

    function setFeeTypePercentage(uint256 feeType, uint256 newValue) external override {
        require(_validFeeTypes[feeType], "Invalid fee type");
        require(newValue <= _maximumPercentages[feeType], "Exceeds maximum");
        _feePercentages[feeType] = newValue;
    }

    function getFeeTypePercentage(uint256 feeType) external view override returns (uint256) {
        return _feePercentages[feeType];
    }

    function getFeeTypeMaximumPercentage(uint256 feeType) external view override returns (uint256) {
        return _maximumPercentages[feeType];
    }

    function getFeeTypeName(uint256 feeType) external view override returns (string memory) {
        return _feeNames[feeType];
    }
}
