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

[リリースページ](./releases)から最新Verのコントラクトパッケージをインストール。
```shell
npm install --save-dev https://github.com/oasysgames/simple-p2e-game/releases/download/vX.X.X/oasysgames-simple-p2e-game-X.X.X.tgz
```

Hardhat統合用の追加パッケージをインストール。
```shell
npm install --save-dev https://github.com/oasysgames/simple-p2e-game/releases/download/vX.X.X/oasysgames-simple-p2e-game-hardhat-X.X.X.tgz
```

インストールしただけではコンパイル対象にならないためインポート用コードを配置してコンパイラに存在を認識させる。
```bash
cp node_modules/@oasysgames/simple-p2e-game-hardhat/contracts/SimpleP2ETestUtils.sol contracts/
```

テストコードをコピーして動作チェック。
```shell
cp node_modules/@oasysgames/simple-p2e-game-hardhat/test/* test/

npx hardhat test
```

基本的な使い方をテストコードから抜粋。
```typescript
import { deploySimpleP2E, deployMockERC721 } from "@oasysgames/simple-p2e-game-hardhat/test-utils";

describe("TestMyContract", () => {
  it("TestCase", async() => {
    // Deploy SimpleP2E ecosystem with Balancer V2 pool and initial liquidity
    const { woas, poas, smp, p2e, nativeOAS } = await deploySimpleP2E({
      initialLiquidity: {
        woas: parseEther("1000"), // Initial WOAS liquidity
        smp: parseEther("4000"), // Initial SMP liquidity (4:1 ratio)
      },
      p2e: {
        lpRecipient: lpRecipient, // LP token recipient
        revenueRecipient: revenueRecipient, // Revenue recipient
      },
    });

    // Deploy mock NFT contracts for P2E game testing
    const nfts = await deployMockNFTs(p2e.address, 3);
    const nftAddrs = nfts.map((nft) => nft.address);

    // Query price and execute purchase with native OAS payment
    const totalPrice = (await p2e.simulate.queryPrice([nftAddrs, nativeOAS])).result;
    await p2e.write.purchase([nftAddrs, nativeOAS, totalPrice], { value: totalPrice });
  })
})
```