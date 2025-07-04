# Binding Smart Contracts with TypeScript
This project helps dApp developers integrate and interact with smart contracts using TypeScript.

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

## Sample Code
- [scripts/purchase.ts](./scripts/purchase.ts)
  - Demonstrates how to buy SBTs by calling the `purchase` function of the SBTSale contract using three different payment methods: `SMP`, `pOAS`, and `native OAS`.

## How to create your project
1. Initialize a hardhat project
```sh
mkdir simple-p2e-game-hh
cd simple-p2e-game-hh

npm init -y
npm install --save-dev hardhat

npx hardhat init

# Note1: Select `Create a TypeScript project (with Viem)` as the project type
# Note2: Choose to install `@nomicfoundation/hardhat-toolbox-viem`
```

2. Install the latest contract package from the [Release Page](https://github.com/oasysgames/simple-p2e-game/releases)
```sh
npm install --save-dev https://github.com/oasysgames/simple-p2e-game/releases/download/vX.X.X/oasysgames-simple-p2e-game-hardhat-X.X.X.tgz
```

3. Make the contracts visible to the compiler. Just installing is not enough — copy an import file so that the compiler recognizes the contracts:
```sh
cp node_modules/@oasysgames/simple-p2e-game-hardhat/contracts/SimpleP2ETestUtils.sol contracts/
```

4. Copy and run the test code
```sh
cp node_modules/@oasysgames/simple-p2e-game-hardhat/test/* test/

npx hardhat test
```
