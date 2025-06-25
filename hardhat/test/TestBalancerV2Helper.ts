import hre from "hardhat";
import { ContractTypesMap } from "hardhat/types/artifacts";
import { parseEther, Address, fromHex, checksumAddress } from "viem";
import { expect } from "chai";

import { deployBalancerV2 } from "@oasysgames/simple-p2e-game/hardhat/test/utils";

describe("TestBalancerV2Helper", () => {
  let poolOwner: Address;
  let sender: Address;
  let recipient: Address;

  let vault: ContractTypesMap["IVault"];
  let bv2helper: ContractTypesMap["IBalancerV2Helper"];
  let woas: ContractTypesMap["IWOAS"];
  let smp: ContractTypesMap["MockSMP"];
  let pool: ContractTypesMap["IVaultPool"];

  let tokens: [Address, Address], woasIdx: number, smpIdx: number;

  before(async () => {
    // Deploy BalancerV2 ecosystem
    ({ vault, bv2helper, woas } = await deployBalancerV2());

    // Set up test accounts (using owner for all roles in this test)
    const [owner] = await hre.viem.getWalletClients();
    poolOwner = owner.account.address;
    sender = owner.account.address;
    recipient = owner.account.address;

    // Deploy SMP token
    smp = await hre.viem.deployContract("MockSMP");

    // Prepare test tokens for liquidity operations
    await woas.write.deposit({ value: parseEther("1000") });
    await smp.write.mint([sender, parseEther("1000")]);

    // Authorize helper contract as a relayer for the sender
    // This allows the helper to perform operations on behalf of the sender
    await vault.write.setRelayerApproval([sender, bv2helper.address, true]);

    // Create a 50/50 weighted pool with WOAS and SMP tokens
    await bv2helper.write.createPool([
      {
        owner: poolOwner,
        name: "50WOAS-50SMP",
        symbol: "50WOAS-50SMP",
        swapFeePercentage: 0n, // Will use default minimum 0.0001%
        tokenA: woas.address,
        tokenB: smp.address,
      },
    ]);

    // Get the created pool address from the emitted event
    const { pool: poolAddr } = (await bv2helper.getEvents.PoolCreated())[0]
      .args;
    pool = await hre.viem.getContractAt("IVaultPool", poolAddr!);

    // Token addresses must be sorted in ascending order for Balancer V2 compatibility
    woasIdx =
      fromHex(woas.address, "bigint") < fromHex(smp.address, "bigint") ? 0 : 1;
    smpIdx = woasIdx ^ 1; // Bitwise XOR to get the opposite index

    // Create sorted token array
    tokens = Array(2) as [Address, Address];
    tokens[woasIdx] = checksumAddress(woas.address);
    tokens[smpIdx] = checksumAddress(smp.address);
  });

  it("should create a weighted pool successfully", async () => {
    // Verify pool was created successfully
    expect(await pool.read.getPoolId()).to.be.not.empty;
  });

  it("should add initial liquidity to the pool", async () => {
    // Add initial liquidity to the pool (first join)
    const amounts = Array(2) as [bigint, bigint];
    amounts[woasIdx] = parseEther("100"); // 100 WOAS
    amounts[smpIdx] = parseEther("200"); // 200 SMP

    // Approve vault to spend tokens
    await woas.write.approve([vault.address, parseEther("100")]);
    await smp.write.approve([vault.address, parseEther("200")]);

    // Perform initial liquidity addition
    await bv2helper.write.addInitialLiquidity([
      pool.address,
      sender,
      recipient,
      tokens,
      amounts,
    ]);

    // Verify the pool balance was updated correctly
    const pbcev = (await vault.getEvents.PoolBalanceChanged())[0];
    expect(pbcev.args.tokens).to.deep.equal(tokens);
    expect(pbcev.args.deltas).to.deep.equal(amounts);
  });

  it("should add additional liquidity to existing pool", async () => {
    // Add additional liquidity to the existing pool (subsequent join)
    let amounts = Array(2) as [bigint, bigint];
    amounts[woasIdx] = parseEther("2"); // 2 more WOAS
    amounts[smpIdx] = parseEther("1"); // 1 more SMP

    // Approve vault to spend additional tokens
    await woas.write.approve([vault.address, parseEther("2")]);
    await smp.write.approve([vault.address, parseEther("1")]);

    // Add liquidity to existing pool
    await bv2helper.write.addLiquidity([
      pool.address,
      sender,
      recipient,
      tokens,
      amounts,
    ]);

    // Verify the additional liquidity was added correctly
    const pbcev = (await vault.getEvents.PoolBalanceChanged())[0];
    expect(pbcev.args.tokens).to.deep.equal(tokens);
    expect(pbcev.args.deltas).to.deep.equal(amounts);
  });

  it("should perform token swap successfully", async () => {
    // Perform token swap: WOAS → SMP
    await woas.write.approve([vault.address, parseEther("1")]);
    await bv2helper.write.swap([
      pool.address,
      sender,
      recipient,
      woas.address,
      smp.address,
      parseEther("1"), // Swap 1 WOAS
    ]);

    // Verify swap was executed correctly
    const swapev = (await vault.getEvents.Swap())[0];
    expect(swapev.args.amountIn).to.equal(parseEther("1"));

    // Expect to receive at least 1.9 SMP (accounting for slippage and fees)
    expect(Number(swapev.args.amountOut)).to.gte(Number(parseEther("1.9")));
  });
});
