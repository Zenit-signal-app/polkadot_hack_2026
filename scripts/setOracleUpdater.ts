import { ethers } from "hardhat";
import { config as loadEnv } from "dotenv";

loadEnv({ path: "keeper/.env" });
loadEnv({ path: "frontend/.env" });

/**
 * Set the updater address on ZenitOracle to the keeper wallet.
 * Run: npx hardhat run scripts/setOracleUpdater.ts --network polkadotTestnet
 *
 * Requires in env:
 * - ORACLE_ADDRESS or VITE_ORACLE_ADDRESS
 * - KEEPER_PRIVATE_KEY (keeper wallet)
 * - PRIVATE_KEY (owner key - must be oracle owner)
 */
async function main() {
  const oracleAddress =
    process.env.ORACLE_ADDRESS ||
    process.env.VITE_ORACLE_ADDRESS;
  if (!oracleAddress) throw new Error("ORACLE_ADDRESS or VITE_ORACLE_ADDRESS required");

  const keeperKey = process.env.KEEPER_PRIVATE_KEY?.trim();
  if (!keeperKey) throw new Error("KEEPER_PRIVATE_KEY required");
  const keeperAddress = new ethers.Wallet(keeperKey).address;

  console.log("Oracle:", oracleAddress);
  console.log("Keeper address:", keeperAddress);

  const oracle = await ethers.getContractAt("ZenitOracle", oracleAddress);
  const current = await oracle.updater();
  if (String(current).toLowerCase() === keeperAddress.toLowerCase()) {
    console.log("Updater already set. No change.");
    return;
  }

  const tx = await oracle.setUpdater(keeperAddress);
  await tx.wait();
  console.log("setUpdater tx:", tx.hash);
  console.log("Updater set successfully.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

