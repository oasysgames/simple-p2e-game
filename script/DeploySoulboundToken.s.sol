// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Script} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SoulboundToken} from "../contracts/SoulboundToken.sol";

/**
 * @title DeploySoulboundToken
 * @notice Deploys the SoulboundToken implementation and proxy.
 */
contract DeploySoulboundToken is Script {
    function run() external returns (TransparentUpgradeableProxy proxy) {
        string memory name = vm.envString("NAME");
        string memory symbol = vm.envString("SYMBOL");
        string memory baseURI = vm.envString("BASE_URI");
        address owner = vm.envAddress("OWNER");
        address admin = vm.envAddress("PROXY_ADMIN");

        vm.startBroadcast();

        SoulboundToken implementation = new SoulboundToken();
        proxy = new TransparentUpgradeableProxy(
            address(implementation),
            admin,
            abi.encodeWithSelector(
                SoulboundToken.initialize.selector,
                name,
                symbol,
                baseURI,
                owner
            )
        );

        vm.stopBroadcast();
    }
}
