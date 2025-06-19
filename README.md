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
