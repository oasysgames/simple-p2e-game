// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import {Script, console} from "forge-std/Script.sol";
import {Vault} from "@balancer-labs/v2-vault/contracts/Vault.sol";
import {MockBasicAuthorizer} from "@balancer-labs/v2-vault/contracts/test/MockBasicAuthorizer.sol";
import {WeightedPoolFactory} from
    "@balancer-labs/v2-pool-weighted/contracts/WeightedPoolFactory.sol";

import {WOAS} from "../contracts/test-utils/WOAS.sol";
import {MockProtocolFeePercentagesProvider} from
    "../contracts/test-utils/MockProtocolFeePercentagesProvider.sol";
import {BalancerV2Helper} from "../contracts/test-utils/BalancerV2Helper.sol";

/**
 * @title GenerateDeployers
 * @notice Script to generate deployer contracts for Balancer V2 components using CREATE2
 * @dev This script generates deployer contracts that use CREATE2 instead of the `new` operator
 *      for deploying Balancer V2 contracts. This is necessary because Balancer V2 code only
 *      supports Solidity ^0.7.0, which can cause compatibility issues in dApps development.
 *      The deployer contracts enable deterministic deployments with modern Solidity versions.
 */
contract GenerateDeployers is Script {
    bytes vaultCode = type(Vault).creationCode;
    bytes authorizerCode = type(MockBasicAuthorizer).creationCode;
    bytes woasCode = type(WOAS).creationCode;

    bytes poolFactoryCode = type(WeightedPoolFactory).creationCode;
    bytes feeProviderCode = type(MockProtocolFeePercentagesProvider).creationCode;

    bytes helperCode = type(BalancerV2Helper).creationCode;

    function run() public {
        _VaultDeployer();
        _WeightedPoolFactoryDeployer();
        _BalancerV2HelperDeployer();
    }

    function _VaultDeployer() internal {
        string memory code = _getTemplate("VaultDeployer");
        code = vm.replace(code, "__VAULT_CODE__", _bytesToStringWithTrim0x(vaultCode));
        code = vm.replace(code, "__AUTHORIZER_CODE__", _bytesToStringWithTrim0x(authorizerCode));
        code = vm.replace(code, "__WOAS_CODE__", _bytesToStringWithTrim0x(woasCode));
        _writeFile("VaultDeployer", code);
    }

    function _WeightedPoolFactoryDeployer() internal {
        string memory code = _getTemplate("WeightedPoolFactoryDeployer");
        code = vm.replace(code, "__POOL_FACTORY_CODE__", _bytesToStringWithTrim0x(poolFactoryCode));
        code = vm.replace(code, "__FEE_PROVIDER_CODE__", _bytesToStringWithTrim0x(feeProviderCode));
        _writeFile("WeightedPoolFactoryDeployer", code);
    }

    function _BalancerV2HelperDeployer() internal {
        string memory code = _getTemplate("BalancerV2HelperDeployer");
        code = vm.replace(code, "__HELPER_CODE__", _bytesToStringWithTrim0x(helperCode));
        _writeFile("BalancerV2HelperDeployer", code);
    }

    function _getTemplate(string memory name) internal returns (string memory) {
        return vm.readFile(vm.replace("script/templates/__REPL__.sol.template", "__REPL__", name));
    }

    function _writeFile(string memory name, string memory deployCode) internal {
        vm.writeFile(
            vm.replace("src/test-utils/deployers/__REPL__.sol", "__REPL__", name), deployCode
        );
    }

    function _bytesToStringWithTrim0x(bytes memory creationCode) internal returns (string memory) {
        return vm.replace(vm.toString(creationCode), "0x", "");
    }
}
