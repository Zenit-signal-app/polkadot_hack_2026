import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config({ path: "frontend/.env" });

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.27",
    settings: { evmVersion: "cancun" },
  },
  networks: {
    polkadotTestnet: {
      url: process.env.POLKADOT_TESTNET_RPC_URL,
      chainId: 420420417,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY.trim()] : [],
    },
  },
};

export default config;
