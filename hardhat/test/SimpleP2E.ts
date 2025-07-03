import { expect } from "chai";
import hre from "hardhat";
import { ContractTypesMap } from "hardhat/types/artifacts";
import { Address, checksumAddress, parseEther } from "viem";

import {
  deploySimpleP2E,
  deployMockERC721,
} from "@oasysgames/simple-p2e-game-hardhat/test-utils";

describe("TestSimpleP2E", () => {
  let p2e: ContractTypesMap["ISimpleP2E"];
  let woas: ContractTypesMap["IWOAS"];
  let poasMinter: ContractTypesMap["MockPOASMinter"];
  let poas: ContractTypesMap["MockPOAS"];
  let smp: ContractTypesMap["MockSMP"];
  let nfts: ContractTypesMap["MockSimpleP2EERC721"][];

  let nativeOAS: Address;
  let buyer: Address;
  let lpRecipient: Address;
  let revenueRecipient: Address;
  let nftAddrs: Address[];

  // Helper function to verify NFT ownership after purchase
  const expectNFTsOwner = async (tokenId: number) => {
    const owners = await Promise.all(
      nfts.map((x) => x.read.ownerOf([BigInt(tokenId)]))
    );
    expect(owners).to.eql(owners.map((_) => buyer));
  };

  before(async () => {
    // Set up test accounts for different roles
    const [buyerWallet, lpRecipientWallet, revenueRecipientWallet] =
      await hre.viem.getWalletClients();
    buyer = checksumAddress(buyerWallet.account.address);
    lpRecipient = checksumAddress(lpRecipientWallet.account.address);
    revenueRecipient = checksumAddress(revenueRecipientWallet.account.address);

    // Deploy SimpleP2E ecosystem with Balancer V2 pool and initial liquidity
    ({ woas, poasMinter, poas, smp, p2e, nativeOAS } = await deploySimpleP2E({
      initialLiquidity: {
        woas: parseEther("1000"), // Initial WOAS liquidity
        smp: parseEther("4000"), // Initial SMP liquidity (4:1 ratio)
      },
      p2e: {
        lpRecipient: lpRecipient, // LP token recipient
        revenueRecipient: revenueRecipient, // Revenue recipient
      },
    }));

    // Deploy mock NFT contracts for P2E game testing
    nfts = await deployMockERC721(p2e.address, 3);
    nftAddrs = nfts.map((x) => x.address);

    // Mint tokens to the buyer for testing different payment methods
    // WOAS: Wrap native OAS to get WOAS tokens
    await woas.write.deposit({ account: buyer, value: parseEther("1000") });

    // POAS: Mint POAS tokens (requires native OAS collateral)
    await poasMinter.write.mint([buyer, parseEther("1000")], {
      account: buyer,
      value: parseEther("1000"),
    });

    // SMP: Mint SMP tokens for direct payment testing
    await smp.write.mint([buyer, parseEther("1000")], { account: buyer });
  });

  it("should purchase NFTs using native OAS", async () => {
    // Query price and execute purchase with native OAS payment
    const totalPrice = (await p2e.simulate.queryPrice([nftAddrs, nativeOAS]))
      .result;
    await p2e.write.purchase([nftAddrs, nativeOAS, totalPrice], {
      account: buyer,
      value: totalPrice,
    });
    await expectNFTsOwner(0);
  });

  it("should purchase NFTs using WOAS", async () => {
    // Query price, approve WOAS spending, and execute purchase
    const totalPrice = (await p2e.simulate.queryPrice([nftAddrs, woas.address]))
      .result;
    await woas.write.approve([p2e.address, totalPrice], { account: buyer });
    await p2e.write.purchase([nftAddrs, woas.address, totalPrice], {
      account: buyer,
    });
    await expectNFTsOwner(1);
  });

  it("should purchase NFTs using POAS", async () => {
    // Query price, approve POAS spending, and execute purchase
    const totalPrice = (await p2e.simulate.queryPrice([nftAddrs, poas.address]))
      .result;
    await poas.write.approve([p2e.address, totalPrice], { account: buyer });
    await p2e.write.purchase([nftAddrs, poas.address, totalPrice], {
      account: buyer,
    });
    await expectNFTsOwner(2);
  });

  it("should purchase NFTs using SMP", async () => {
    // Query price, approve SMP spending, and execute purchase
    const totalPrice = (await p2e.simulate.queryPrice([nftAddrs, smp.address]))
      .result;
    await smp.write.approve([p2e.address, totalPrice], { account: buyer });
    await p2e.write.purchase([nftAddrs, smp.address, totalPrice], {
      account: buyer,
    });
    await expectNFTsOwner(3);
  });
});
