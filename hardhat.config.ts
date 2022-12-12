import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-contract-sizer";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";

//dotenv
import dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.6",
      },
      {
        version: "0.5.16",
      },
      {
        version: "0.4.18",
      },
    ],
  },
  networks: {
    hardhat: {
      blockGasLimit: 100000000429720,
      allowUnlimitedContractSize: true,
      accounts: {
        accountsBalance: "10000000000000000000000000",
      },
    },
    localhost: {
      blockGasLimit: 100000000429720,
      allowUnlimitedContractSize: true,
    },
    bsc: {
      url: "https://bsc-dataseed1.binance.org/",
      chainId: 56,
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    poly: {
      url: "https://polygonapi.terminet.io/rpc",
      chainId: 137,
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    mumbai: {
      url: process.env.MUMBAI_URL || "",
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    bsctestnet: {
      url: process.env.BSCTESTNET_URL || "",
      accounts: [process.env.PRIVATE_KEY || ""],
    },
  },
};
export default config;
