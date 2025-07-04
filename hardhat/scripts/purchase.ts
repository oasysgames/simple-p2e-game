import { config as loadEnv } from "dotenv";
import hre from "hardhat";
import {
  Address,
  encodeFunctionData,
  decodeFunctionResult,
  zeroAddress,
} from "viem";

// Friendly script demonstrating how to buy SBTs with different tokens.

loadEnv();

const SBTSALE_ADDRESS = process.env.SBTSALE_ADDRESS as Address | undefined;
const SBT_ADDRESS = process.env.SBT_ADDRESS as Address | undefined;
const SMP_ADDRESS = process.env.SMP_ADDRESS as Address | undefined;
const POAS_ADDRESS = process.env.POAS_ADDRESS as Address | undefined;

if (!SBTSALE_ADDRESS || !SBT_ADDRESS || !SMP_ADDRESS || !POAS_ADDRESS) {
  throw new Error(
    "Missing environment variables. Please set SBTSALE_ADDRESS, SBT_ADDRESS, SMP_ADDRESS and POAS_ADDRESS"
  );
}

async function queryPrice(token: Address): Promise<bigint> {
  const sbtSale = await hre.viem.getContractAt("ISBTSale", SBTSALE_ADDRESS);
  const data = encodeFunctionData({
    abi: sbtSale.abi,
    functionName: "queryPrice",
    args: [[SBT_ADDRESS], token],
  });
  const raw = (await hre.network.provider.request({
    method: "eth_call",
    params: [
      {
        to: SBTSALE_ADDRESS,
        data,
      },
      "latest",
    ],
  })) as string;
  const [price] = decodeFunctionResult({
    abi: sbtSale.abi,
    functionName: "queryPrice",
  }, raw);
  return price as bigint;
}

async function purchaseWith(token: Address, sendValue = false) {
  const sbtSale = await hre.viem.getContractAt("ISBTSale", SBTSALE_ADDRESS);
  const sbt = await hre.viem.getContractAt("ISBTSaleERC721", SBT_ADDRESS);
  const smp = await hre.viem.getContractAt("ISMP", SMP_ADDRESS);
  const poas = await hre.viem.getContractAt("IPOAS", POAS_ADDRESS);
  const [wallet] = await hre.viem.getWalletClients();
  const account = wallet.account.address;

  const price = await queryPrice(token);
  console.log(`Price for token ${token}: ${price}`);

  if (token === SMP_ADDRESS) {
    await smp.write.approve([SBTSALE_ADDRESS, price], { account });
  } else if (token === POAS_ADDRESS) {
    await poas.write.approve([SBTSALE_ADDRESS, price], { account });
  }

  await sbtSale.write.purchase(
    [[SBT_ADDRESS], token, price],
    sendValue ? { account, value: price } : { account }
  );
  const balance = await sbt.read.balanceOf([account]);
  console.log(`SBT balance after purchase: ${balance}`);
}

async function main() {
  await purchaseWith(SMP_ADDRESS);
  await purchaseWith(POAS_ADDRESS);
  await purchaseWith(zeroAddress, true);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
