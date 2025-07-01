# simple-p2e-game
A Play-to-Earn (P2E) project where players earn SMP (Simple) Tokens—a cryptocurrency—by playing a simple game that uses Cards, which are Soulbound Tokens (SBTs) with expiration dates.

## Getting Started
- For DApp developers: Navigate to the [hardhat](./hardhat) directory, which contains bindings for a TypeScript-based DApp.
- For smart contract developers: Work from the root directory. Follow the instructions below.
  - Note: This project uses [Foundry](https://getfoundry.sh/). Please make sure Foundry is installed beforehand.
```sh
# Install dependencies
npm install

# Compile contracts
npm run build

# Run tests
npm test
```

## Contracts
- SimpleGame
  - The main contract that users interact with to play the game. (Not yet implemented.)
- [SimpleP2E](./contracts/SimpleP2E.sol)
  - A sales contract for minting SBTs (Soulbound Tokens).Supports payment in SMP Token, native OAS, Wrapped OAS, and pOAS.
  - The price of each SBT is denominated in SMP tokens. When other tokens are used for payment, they are swapped to SMP via the Gaming DEX.
- [SoulboundToken](./contracts/SoulboundToken.sol)
  - An SBT (Soulbound Token) contract representing "Cards" used in the game.
  - The token itself does not have an expiration date. Ownership is permanent once minted, as with typical soulbound tokens. Expiration is handled separately by the game contract, not the token itself.
- SMP
  - An ERC-20 token used to purchase SBT Cards.
  - Deployed using the [L1StandardERC20Factory](https://docs.oasys.games/docs/architecture/hub-layer/contract#preset-contracts).

## Gaming Dex
A DEX built on the Oasys Hub, used for swapping SMP tokens. Gaming DEX is a fork of [Balancer V2](https://github.com/balancer/balancer-v2-monorepo).
- [testnet](https://testnet.gaming-dex.com/#/oasys-testnet/swap)
- [mainnet](https://www.gaming-dex.com/#/defiverse/swap)
