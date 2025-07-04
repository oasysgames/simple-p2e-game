# Hardhat Scripts

This folder contains TypeScript utilities for interacting with the contracts from this repository.

## Purchase Example

`scripts/purchase.ts` demonstrates how to acquire SBTs using the `purchase` function of the `SBTSale` contract with three different payment methods: SMP, pOAS and native OAS.

### Setup

1. Install dependencies within the `hardhat` directory:

```sh
cd hardhat
npm install
```

2. Create an `.env` file in this directory based on `.env.sample` and fill in the required addresses.

```
SBTSALE_ADDRESS=0x...
SBT_ADDRESS=0x...
SMP_ADDRESS=0x...
POAS_ADDRESS=0x...
```

### Running the script

Execute the script using Hardhat:

```sh
npx hardhat run scripts/purchase.ts --network hardhat
```

The script performs the following steps for each payment method:

1. Queries the price by calling `queryPrice` via an explicit `eth_call`.
2. Approves the necessary token amount when paying with SMP or pOAS.
3. Calls `purchase` to buy the SBT.
4. Reads the SBT balance to confirm the purchase.
