import hre from "hardhat";
import { keccak256, stringToBytes } from "viem";

export async function testUtilsFixture() {
  const { deployContract, getContractAt } = hre.viem;

  // Use deterministic salt for consistent deployment addresses
  const salt = keccak256(stringToBytes("DEPLOYERS_SALT"));

  // Deploy Balancer V2 Vault, Authorizer, and WOAS contracts
  const vaultDeployer = await deployContract("VaultDeployer", [salt]);
  const vault = await getContractAt("IVault", await vaultDeployer.read.vault());
  const woas = await getContractAt("IWOAS", await vaultDeployer.read.woas());

  // Deploy WeightedPoolFactory for creating weighted pools
  const poolFactoryDeployer = await deployContract(
    "WeightedPoolFactoryDeployer",
    [salt, vault.address]
  );
  const poolFactory = await getContractAt(
    "IWeightedPoolFactory",
    await poolFactoryDeployer.read.poolFactory()
  );

  // Deploy BalancerV2Helper for simplified pool interactions
  const helperDeployer = await deployContract("BalancerV2HelperDeployer", [
    salt,
    vault.address,
    poolFactory.address,
  ]);
  const helper = await getContractAt(
    "IBalancerV2Helper",
    await helperDeployer.read.helper()
  );

  // Grant relayer permissions to helper contract for vault operations
  await vaultDeployer.write.grantRelayerRolesToHelper([helper.address]);

  // Deploy SMP token
  const smp = await deployContract("MockSMP");

  return { vault, poolFactory, helper, woas, smp };
}
