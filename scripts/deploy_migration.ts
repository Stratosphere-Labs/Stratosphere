import { ethers } from "hardhat";

async function main() {
  const Migration = await ethers.getContractFactory("StratMigration");
  const migration = await Migration.deploy(
    "0x037A36e09FA2C2A2775C67b864C55EEa1db755cA",
    "0x4B097e737f431AdC79924D32ea94a5564e2fDe1f"
  );
  await migration.deployed();
  console.log("Migration deployed to:", migration.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
