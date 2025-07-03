// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SoulboundToken} from "../contracts/SoulboundToken.sol";

contract SoulboundTokenTest is Test {
    SoulboundToken sbt;
    TransparentUpgradeableProxy proxy;
    ProxyAdmin proxyAdmin;
    address owner;
    address user;
    address minter;
    string constant BASE_URI = "https://token/";

    // Get role constants before vm.expectRevert to avoid revert interference
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x0;
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        owner = makeAddr("owner");
        console.log("owner", owner);
        user = makeAddr("user");
        console.log("user", user);
        minter = makeAddr("minter");
        console.log("minter", minter);

        SoulboundToken implementation = new SoulboundToken();
        console.log("implementation", address(implementation));

        vm.prank(owner);
        proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,
            abi.encodeWithSelector(
                SoulboundToken.initialize.selector, "Soulbound", "SBT", BASE_URI, owner
            )
        );

        // get proxy admin address in proxy
        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        proxyAdmin = ProxyAdmin(address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT)))));
        console.log("admin", address(proxyAdmin));

        sbt = SoulboundToken(address(proxy));
        console.log("sbt", address(sbt));
        console.log("msg.sender", msg.sender);
    }

    function test_initialize_sets_roles() public {
        assertTrue(sbt.hasRole(DEFAULT_ADMIN_ROLE, owner));
        assertTrue(sbt.hasRole(MINTER_ROLE, owner));
        assertEq(sbt.name(), "Soulbound");
        assertEq(sbt.symbol(), "SBT");
    }

    function test_safeMint_sets_mintedAt() public {
        vm.warp(1000);
        vm.prank(owner);
        sbt.safeMint(user, 1, "");
        assertEq(sbt.ownerOf(1), user);
        assertEq(sbt.mintTimeOf(1), block.timestamp);
    }

    function test_safeMint_restricted() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, MINTER_ROLE
            )
        );
        vm.prank(user);
        sbt.mint(user);
    }

    function test_mint() public {
        vm.warp(500);
        vm.prank(owner);
        uint256 tokenId = sbt.mint(user);

        assertEq(tokenId, 0);
        assertEq(sbt.ownerOf(tokenId), user);
        assertEq(sbt.mintTimeOf(tokenId), 500);
        assertEq(sbt.balanceOf(user), 1);
    }

    function test_burn_holder() public {
        vm.prank(owner);
        sbt.safeMint(user, 1, "");
        vm.prank(user);
        sbt.burn(1);
        assertEq(sbt.mintTimeOf(1), 0);
    }

    function test_burn_unauthorized() public {
        vm.prank(owner);
        sbt.safeMint(user, 1, "");
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, owner, 1)
        );
        vm.prank(owner);
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

    function test_supportsInterface() public view {
        assertTrue(sbt.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(sbt.supportsInterface(type(IERC721).interfaceId));
        assertFalse(sbt.supportsInterface(0x12345678));
    }

    function test_grantRole() public {
        vm.prank(owner);
        sbt.grantRole(MINTER_ROLE, minter);
        assertTrue(sbt.hasRole(MINTER_ROLE, minter));
        vm.prank(minter);
        sbt.mint(minter);
        assertEq(sbt.ownerOf(0), minter);
    }

    function test_grantRole_restricted() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, DEFAULT_ADMIN_ROLE
            )
        );
        sbt.grantRole(MINTER_ROLE, minter);
    }

    function test_assignTokenId() public {
        // first mint token id 0
        vm.prank(owner);
        sbt.mint(user);

        // second mint token id 1, 2, 3
        for (uint256 i = 1; i < 4; ++i) {
            vm.prank(owner);
            sbt.safeMint(user, i, "");
        }

        // third mint token id 4
        vm.prank(owner);
        sbt.mint(user);
        assertEq(sbt.ownerOf(4), user);
        assertEq(sbt.mintTimeOf(4), block.timestamp);
        assertEq(sbt.balanceOf(user), 5);
    }

    function test_upgrade() public {
        // mint token id 0
        vm.prank(owner);
        sbt.mint(user);
        uint256 mintedAt = sbt.mintTimeOf(0);

        // deploy v2 and upgrade
        SoulboundToken newImpl = new SoulboundToken();
        vm.prank(owner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)), address(newImpl), ""
        );

        // check token id 0
        assertEq(sbt.ownerOf(0), user);
        assertEq(sbt.mintTimeOf(0), mintedAt);

        // mint token id 1
        vm.prank(owner);
        sbt.mint(user);

        // check token id 1
        assertEq(sbt.ownerOf(1), user);
        assertEq(sbt.mintTimeOf(1), block.timestamp);
    }

    function test_upgrade_restricted() public {
        // mint token id 1 using v1 implementation
        vm.prank(owner);
        sbt.safeMint(user, 1, "");

        // deploy v2 and upgrade
        SoulboundToken newImpl = new SoulboundToken();
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        vm.prank(user);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)), address(newImpl), ""
        );
    }
}
