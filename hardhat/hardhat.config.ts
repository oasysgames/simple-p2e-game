import dotenv from "dotenv";
import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";

dotenv.config({ override: true });

const PRIVATE_KEY: string = process.env.PRIVATE_KEY || "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    testnet: {
      url: "https://rpc.testnet.oasys.games",
      accounts: [PRIVATE_KEY],
    },
  },
};

export default config;
