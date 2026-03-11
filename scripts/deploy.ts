import { ethers } from "hardhat";

const ZUSDC_ADDRESS = process.env.zUSDC_Smartcontract || process.env.ZUSDC_ADDRESS || "0x277E42B9454fB36A7Eaa52D4cE332bEF71dd017a";

async function main() {
  const zusdc = ZUSDC_ADDRESS;
  if (!zusdc) {
    throw new Error("ZUSDC_ADDRESS or zUSDC_Smartcontract required in .env");
  }

  console.log("Using zUSDC at:", zusdc);

  const RewardContract = await ethers.getContractFactory("RewardContract");
  const reward = await RewardContract.deploy(zusdc);
  await reward.waitForDeployment();
  const rewardAddress = await reward.getAddress();
  console.log("RewardContract deployed to:", rewardAddress);

  const PerpetualDEX = await ethers.getContractFactory("PerpetualDEX");
  const dex = await PerpetualDEX.deploy(zusdc, rewardAddress);
  await dex.waitForDeployment();
  const dexAddress = await dex.getAddress();
  console.log("PerpetualDEX deployed to:", dexAddress);

  const tx = await reward.setDEXContractAddress(dexAddress);
  await tx.wait();
  console.log("RewardContract.setDEXContractAddress called");

  console.log("\n--- Add to frontend/.env ---");
  console.log(`VITE_DEX_ADDRESS=${dexAddress}`);
  console.log(`VITE_TOKEN_ADDRESS=${zusdc}`);
  console.log(`VITE_REWARD_ADDRESS=${rewardAddress}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
