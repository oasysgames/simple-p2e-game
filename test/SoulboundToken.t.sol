// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {SoulboundToken} from "../contracts/SoulboundToken.sol";
import {SoulboundTokenV2} from "../contracts/SoulboundTokenV2.sol";

contract SoulboundTokenTest is Test {
    // Storage slot for EIP-1967 proxy admin
    bytes32 constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    SoulboundToken sbt;
    TransparentUpgradeableProxy proxy;
    address owner;
    address user;
    uint256 defaultExpiration = 100;
    string constant BASE_URI = "https://token/";

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");

        SoulboundToken implementation = new SoulboundToken();
        vm.prank(owner);
        proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,
            abi.encodeWithSelector(
                SoulboundToken.initialize.selector,
                "Soulbound",
                "SBT",
                BASE_URI,
                owner,
                defaultExpiration
            )
        );
        sbt = SoulboundToken(address(proxy));
    }

    function _proxyAdmin() internal view returns (ProxyAdmin) {
        address admin = address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT))));
        return ProxyAdmin(admin);
    }

    function _upgrade(address newImpl) internal {
        vm.prank(owner);
        _proxyAdmin().upgradeAndCall(ITransparentUpgradeableProxy(payable(address(proxy))), newImpl, bytes(""));
    }

    function test_initialize_sets_roles() public {
        assertTrue(sbt.hasRole(sbt.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(sbt.hasRole(sbt.MINTER_ROLE(), owner));
        assertEq(sbt.name(), "Soulbound");
        assertEq(sbt.symbol(), "SBT");
    }

    function test_safeMint_sets_expiration() public {
        vm.warp(1000);
        vm.prank(owner);
        sbt.safeMint(user, 1, "");
        assertEq(sbt.ownerOf(1), user);
        assertEq(sbt.expirationOf(1), 1000 + defaultExpiration);
    }

    function test_safeMint_restricted() public {
        vm.prank(user);
        vm.expectRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        sbt.safeMint(user, 1, "");
    }

    function test_safeMintWithExpiration_invalid() public {
        vm.prank(owner);
        vm.expectRevert(SoulboundToken.InvalidExpiration.selector);
        sbt.safeMintWithExpiration(user, 1, block.timestamp - 1, "");
    }

    function test_safeMintWithExpiration_custom() public {
        vm.warp(50);
        vm.prank(owner);
        sbt.safeMintWithExpiration(user, 1, 200, "");
        assertEq(sbt.expirationOf(1), 200);
    }

    function test_burn_by_owner() public {
        vm.prank(owner);
        sbt.safeMint(owner, 1, "");
        vm.prank(owner);
        sbt.burn(1);
        assertEq(sbt.expirationOf(1), 0);
    }

    function test_burn_unauthorized() public {
        vm.prank(owner);
        sbt.safeMint(owner, 1, "");
        vm.prank(user);
        vm.expectRevert(SoulboundToken.Unauthorized.selector);
        sbt.burn(1);
    }

    function test_tokenURI_and_baseURI_update() public {
        vm.prank(owner);
        sbt.safeMint(owner, 1, "");
        assertEq(sbt.tokenURI(1), string.concat(BASE_URI, "1"));
        string memory newURI = "ipfs://new/";
        vm.prank(owner);
        sbt.setBaseURI(newURI);
        vm.prank(owner);
        sbt.safeMint(owner, 2, "");
        assertEq(sbt.tokenURI(2), string.concat(newURI, "2"));
    }

    function test_setDefaultExpiration() public {
        vm.prank(owner);
        sbt.setDefaultExpiration(200);
        vm.warp(10);
        vm.prank(owner);
        sbt.safeMint(owner, 1, "");
        assertEq(sbt.expirationOf(1), 10 + 200);
    }

    function test_isExpired() public {
        vm.prank(owner);
        sbt.safeMint(owner, 1, "");
        vm.warp(block.timestamp + defaultExpiration + 1);
        assertTrue(sbt.isExpired(1));
    }

    function test_non_transferable() public {
        vm.prank(owner);
        sbt.safeMint(owner, 1, "");
        vm.expectRevert(SoulboundToken.Soulbound.selector);
        sbt.transferFrom(owner, user, 1);
        vm.expectRevert(SoulboundToken.Soulbound.selector);
        sbt.approve(user, 1);
        vm.expectRevert(SoulboundToken.Soulbound.selector);
        sbt.setApprovalForAll(user, true);
    }

    function test_supportsInterface() public {
        assertTrue(sbt.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(sbt.supportsInterface(type(IERC721).interfaceId));
        assertFalse(sbt.supportsInterface(0x12345678));
    }

    function test_upgrade_and_assignTokenId() public {
        // mint token id 1 using v1 implementation
        vm.prank(owner);
        sbt.safeMint(user, 1, "");

        // deploy v2 and upgrade
        SoulboundTokenV2 newImpl = new SoulboundTokenV2();
        _upgrade(address(newImpl));
        SoulboundTokenV2 sbtV2 = SoulboundTokenV2(address(proxy));

        // version function exists only in V2
        assertEq(sbtV2.version(), 2);

        // assign token id should skip existing id 1
        vm.prank(owner);
        uint256 assigned = sbtV2.assignTokenId();
        assertEq(assigned, 2);
    }
}
