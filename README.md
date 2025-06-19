# simple-p2e-game
暗号資産であるSMP(Simple) Tokenと有効期限つきSBTであるCardを使ったシンプルなゲームでSMP Tokenを獲得するP2Eプロジェクト
## 依頼内容
企画もと
https://docs.google.com/presentation/d/1rEIT8Q7S2ltjRv4ucLROBgWpdMMuG67yhcUf1ajIv24/edit?slide=id.p#slide=id.p

L1 testnetのGaming DEXがあるので
https://testnet.gaming-dex.com/#/oasys-testnet/swap

- SMPトークンを発行
- OAS / SMPのペアを作成
- SMPを払って自動スワップ OAS/SMP LPを追加、NFTを発行
- OASを払って自動スワップ OAS/SMP LPを追加、NFTを発行
- pOASを払って自動スワップ OAS/SMP LPを追加、NFTを発行

あたりのコントラクトを作ってもらえませんか？

## Gaming Dex

### UI
- [testnet](https://testnet.gaming-dex.com/#/oasys-testnet/swap): ExploreでVerifyされていない
- [mainnet](https://www.gaming-dex.com/#/defiverse/swap): ExploreでVerify済み

### コントラクト
[balancer-v2](https://github.com/balancer/balancer-v2-monorepo/tree/master)を使ってる
- Swapは[batchSwap](https://github.com/balancer/balancer-v2-monorepo/blob/master/pkg/vault/contracts/Swaps.sol#L109)あたりが参考になるとのこと
- [Vault](https://scan-testnet.defi-verse.org/address/0x2Da016a77E290fb82F5af7051198304d57779f5d?tab=contract)コントラクトのアドレスを渡された。何なのか不明だが、肝に違いない。


## Hardhatとの統合手順

Hardhatプロジェクトを初期化。
```shell
mkdir simple-p2e-game-hh
cd simple-p2e-game-hh

npm init -y
npm install --save-dev hardhat

npx hardhat init

# Note1: プロジェクトタイプは`Create a TypeScript project (with Viem)`を選択
# Note2: `@nomicfoundation/hardhat-toolbox-viem`のインストールを選択
```

リリースページから最新Verのtarballパッケージをインストール。
```shell
npm install --save-dev https://github.com/oasysgames/simple-p2e-game/releases/download/vX.X.X/oasysgames-simple-p2e-game-X.X.X.tgz
```

インストールしただけではコンパイル対象にならないため`contracts/SimpleP2E.sol`等にインポート処理を追加してコンパイラに存在を伝える。
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@oasysgames/simple-p2e-game/contracts/test-utils/TestUtilsImporter.sol";
```

[このテストコード](hardhat/test/TestSimpleP2E.ts)を`test/TestSimpleP2E.ts`へコピーして動作チェック。
```shell
npx hardhat test test/TestSimpleP2E.ts
```

基本的な使い方をテストコードから抜粋。
```typescript
// Viemのフィクスチャローダー
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";

// テストコードからBalancerV2を利用可能にするフィクスチャ
import { testUtilsFixture } from "@oasysgames/simple-p2e-game/hardhat/fixtures";

describe("TestMyContract", () => {
  it("TestCase", async() => {
    const { vault, helper, woas, smp } = await loadFixture(testUtilsFixture);

    // 流動性プールを作成
    await helper.write.createPool(...)

    // 初期流動性を提供
    await helper.write.addInitialLiquidity(...)

    // 追加流動性を提供
    await helper.write.addLiquidity(...)

    // トークンスワップ
    await helper.write.swap(...)
  })
})
```