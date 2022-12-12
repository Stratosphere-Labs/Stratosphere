import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { Contract, BigNumber } from "ethers";

describe("Migration", () => {
  let migration: Contract;
  let dummyV1: Contract;
  let dummyV2: Contract;

  beforeEach(async () => {
    const DummyV1 = await ethers.getContractFactory("Dummy");
    dummyV1 = await DummyV1.deploy();
    await dummyV1.deployed();
    const DummyV2 = await ethers.getContractFactory("Dummy");
    dummyV2 = await DummyV2.deploy();
    await dummyV2.deployed();
    const Migration = await ethers.getContractFactory("StratMigration");
    migration = await Migration.deploy(dummyV1.address, dummyV2.address);
    await migration.deployed();
  });

  it("Migration should not work if no tokens in contract", async () => {
    await expect(migration.migrate()).to.be.revertedWith(
      "Not enough Strat in contract"
    );
  });
  it("Migration should not work if not enough tokens in contract", async () => {
    await dummyV2.transfer(migration.address, "1000000000000000000");
    await expect(migration.migrate()).to.be.revertedWith(
      "Not enough Strat in contract"
    );
  });
  it("Migration should work if enough tokens in contract", async () => {
    const [signer] = await ethers.getSigners();
    const addr = await signer.getAddress();
    await dummyV1.approve(migration.address, "2000000000000000000");
    await dummyV2.transfer(migration.address, "2000000000000000000");
    await migration.migrate();
    expect(await dummyV1.balanceOf(addr)).to.equal("0");
    expect(await dummyV2.balanceOf(addr)).to.equal("2000000000000000000");
    expect(await dummyV2.balanceOf(migration.address)).to.equal("0");
  });
  it("Migration with less than 100% should work", async () => {
    const [s1, s2] = await ethers.getSigners();
    const addr2 = await s2.getAddress();

    await dummyV2
      .connect(s1)
      .transfer(migration.address, "1000000000000000000");
    await dummyV1.connect(s1).transfer(addr2, "1000000000000000");
    await dummyV1.connect(s2).approve(migration.address, "1000000000000000");
    await migration.connect(s2).migrate();

    expect(await dummyV1.balanceOf(addr2)).to.equal("0");
    expect(await dummyV2.balanceOf(addr2)).to.equal("1000000000000000");
    expect(await dummyV2.balanceOf(migration.address)).to.equal(
      ethers.utils.parseUnits("999000000", 9)
    );
  });
});
