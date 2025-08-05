import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

// Function to safely get configuration variables
function getVar(name: string): string | undefined {
  try {
    return vars.get(name);
  } catch (error) {
    return undefined;
  }
}

// Optional external network configuration - only used if API keys are provided
const INFURA_API_KEY = getVar("INFURA_API_KEY");
const SEPOLIA_PRIVATE_KEY = getVar("SEPOLIA_PRIVATE_KEY");
const ETHEREUM_PRIVATE_KEY = getVar("ETHEREUM_PRIVATE_KEY");

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    // Local hardhat network is always available for testing
    hardhat: {
      // This is the default local network, no configuration needed
    },
    // External networks only if API keys are provided
    ...(INFURA_API_KEY && SEPOLIA_PRIVATE_KEY ? {
      sepolia: {
        url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
        accounts: [SEPOLIA_PRIVATE_KEY],
      },
    } : {}),
    ...(INFURA_API_KEY && ETHEREUM_PRIVATE_KEY ? {
      ethereum: {
        url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
        accounts: [ETHEREUM_PRIVATE_KEY],
      },
    } : {}),
  },
  etherscan: {
    apiKey: "WX8IX4SEZ2E5GHYY1FBXY8WU1WEXHRRGG3",
  },
};

export default config;
