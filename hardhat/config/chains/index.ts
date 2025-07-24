import { hardhat } from 'viem/chains';
import { oasysTestnet } from './definitions/oasysTestnet';

export const chains = [
  hardhat,
  oasysTestnet,
];

export const getChain = (chainId: number) => {
  return chains.find((chain) => {
    return chain.id === chainId;
  });
};
