import { ethers } from "hardhat";

async function main() {
  const StratosphereV2 = await ethers.getContractFactory("StratosphereV2");
  const stratospherev2 = await StratosphereV2.deploy();
  await stratospherev2.deployed();
  console.log("stratospherev2 deployed to:", stratospherev2.address);
  console.log("initilize stratospherev2");
  const nullAddress = "0x0000000000000000000000000000000000000000";
  await stratospherev2.initialize(
    "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
    nullAddress
  );
  console.log("stratospherev2 initialized");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
