import { defineChain } from "viem";

export const oasysTestnet = defineChain({
  id: 9372,
  name: "Oasys Testnet",
  network: "oasys-testnet",
  nativeCurrency: {
    name: "OAS",
    symbol: "OAS",
    decimals: 18,
  },
  rpcUrls: {
    default: { http: ["https://rpc.testnet.oasys.games"] },
    public:  { http: ["https://rpc.testnet.oasys.games"] },
  },
  blockExplorers: {
    default: { name: "Oasys Testnet Explorer", url: "https://explorer.testnet.oasys.games" },
  },
  testnet: true,
});
