import { ethers } from "hardhat";

async function main() {
  const Staking = await ethers.getContractFactory("StratStake");
  /*
        IBEP20 _stakedToken,
        IBEP20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        uint256 _poolLimitPerUser,
        address _admin
  */
  const staking = await Staking.deploy();
  await staking.deployed();
  console.log("Staking deployed to:", staking.address);
  console.log("Initializing staking contract");
  await staking.initialize(
    "0x23Fc254cD060Be3C9AC5B9364B67b5f64fB3aB66", // staked token
    "0x23Fc254cD060Be3C9AC5B9364B67b5f64fB3aB66", // reward token
    "2739197531", // reward per block
    "36833871", // start block
    "42665871", // bonus end block
    "0", // pool limit per user
    "0x54Ba0B75a13bc4253E28a2c9C90972b5aFb1a81D" // admin
  );
  console.log("Staking contract initialized");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
