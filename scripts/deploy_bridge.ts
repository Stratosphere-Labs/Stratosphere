import { ethers } from "hardhat";

async function main() {
  const Bridge = await ethers.getContractFactory("Bridge");
  const bridge = await Bridge.deploy(
    "0x47eCc41855Fe6B23583de1466453DFC498598ee6", // bridge address
    "0x4B097e737f431AdC79924D32ea94a5564e2fDe1f", // token address
    "10000000000000", // min bridge amount
    "20000000000000000", // max bridge amount
    "10000000000000000", // bridge fee
    "10000000000000000" // claim fee
  );
  await bridge.deployed();
  console.log("Bridge deployed to:", bridge.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
