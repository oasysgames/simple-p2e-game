import hre from "hardhat";
import { parseEther, Address, fromHex, checksumAddress } from "viem";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";

import { testUtilsFixture } from "@oasysgames/simple-p2e-game/hardhat/fixtures";

describe("TestSimpleP2E", () => {
  it("BalancerV2Helper: Test pool creation, initial liquidity, additional liquidity, and token swapping", async () => {
    // Load the test fixture with deployed contracts
    const { vault, helper, woas, smp } = await loadFixture(testUtilsFixture);

    // Set up test accounts (using owner for all roles in this test)
    const [owner] = await hre.viem.getWalletClients();
    const poolOwner = owner.account.address;
    const sender = owner.account.address;
    const recipient = owner.account.address;

    // Prepare test tokens for liquidity operations
    await woas.write.deposit({ value: parseEther("1000") });
    await smp.write.mint([sender, parseEther("1000")]);

    // Authorize helper contract as a relayer for the sender
    // This allows the helper to perform operations on behalf of the sender
    await vault.write.setRelayerApproval([sender, helper.address, true]);

    // Create a 50/50 weighted pool with WOAS and SMP tokens
    await helper.write.createPool([
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
    const { pool: poolAddr } = (await helper.getEvents.PoolCreated())[0].args;
    const pool = await hre.viem.getContractAt("IBasePool", poolAddr!);

    // Token addresses must be sorted in ascending order for Balancer V2 compatibility
    const woasIdx =
      fromHex(woas.address, "bigint") < fromHex(smp.address, "bigint") ? 0 : 1;
    const smpIdx = woasIdx ^ 1; // Bitwise XOR to get the opposite index

    // Create sorted token array
    const tokens = Array(2) as [Address, Address];
    tokens[woasIdx] = checksumAddress(woas.address);
    tokens[smpIdx] = checksumAddress(smp.address);

    // Add initial liquidity to the pool (first join)
    const amounts = Array(2) as [bigint, bigint];
    amounts[woasIdx] = parseEther("100"); // 100 WOAS
    amounts[smpIdx] = parseEther("200"); // 200 SMP

    // Approve vault to spend tokens
    await woas.write.approve([vault.address, parseEther("100")]);
    await smp.write.approve([vault.address, parseEther("200")]);

    // Perform initial liquidity addition
    await helper.write.addInitialLiquidity([
      pool.address,
      sender,
      recipient,
      tokens,
      amounts,
    ]);

    // Verify the pool balance was updated correctly
    let pbcev = (await vault.getEvents.PoolBalanceChanged())[0];
    expect(pbcev.args.tokens).to.deep.equal(tokens);
    expect(pbcev.args.deltas).to.deep.equal(amounts);

    // Add additional liquidity to the existing pool (subsequent join)
    amounts[woasIdx] = parseEther("2"); // 2 more WOAS
    amounts[smpIdx] = parseEther("1"); // 1 more SMP

    // Approve vault to spend additional tokens
    await woas.write.approve([vault.address, parseEther("2")]);
    await smp.write.approve([vault.address, parseEther("1")]);

    // Add liquidity to existing pool
    await helper.write.addLiquidity([
      pool.address,
      sender,
      recipient,
      tokens,
      amounts,
    ]);

    // Verify the additional liquidity was added correctly
    pbcev = (await vault.getEvents.PoolBalanceChanged())[0];
    expect(pbcev.args.tokens).to.deep.equal(tokens);
    expect(pbcev.args.deltas).to.deep.equal(amounts);

    // Perform token swap: WOAS → SMP
    await woas.write.approve([vault.address, parseEther("1")]);

    // Execute swap through helper contract
    await helper.write.swap([
      pool.address,
      sender,
      recipient,
      woas.address,
      parseEther("1"), // Swap 1 WOAS
    ]);

    // Verify swap was executed correctly
    const swapev = (await vault.getEvents.Swap())[0];
    expect(swapev.args.amountIn).to.equal(parseEther("1"));

    // Expect to receive at least 1.9 SMP (accounting for slippage and fees)
    expect(Number(swapev.args.amountOut)).to.gte(Number(parseEther("1.9")));
  });
});
