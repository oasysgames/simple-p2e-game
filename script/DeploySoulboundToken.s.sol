// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SoulboundToken} from "../contracts/SoulboundToken.sol";

/**
 * @title DeploySoulboundToken
 * @notice Deploys the SoulboundToken implementation and proxy.
 */
contract DeploySoulboundToken is Script {
    function run() external returns (TransparentUpgradeableProxy proxy) {
        string memory name = vm.envString("SBT_NAME");
        string memory symbol = vm.envString("SBT_SYMBOL");
        string memory baseURI = vm.envString("SBT_BASE_URI");
        address admin = vm.envAddress("SBT_ADMIN");

        // print deployment config
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Base URI:", baseURI);
        console.log("Admin:", admin);

        vm.startBroadcast();

        SoulboundToken implementation = new SoulboundToken();
        proxy = new TransparentUpgradeableProxy(
            address(implementation),
            admin,
            abi.encodeWithSelector(SoulboundToken.initialize.selector, name, symbol, baseURI, admin)
        );

        // print deployment result
        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        console.log("--------------------------------");
        console.log("SoulboundToken(implementation):", address(implementation));
        console.log("ProxyAdmin:", address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT)))));
        console.log("Proxy:", address(proxy));

        vm.stopBroadcast();
    }
}
