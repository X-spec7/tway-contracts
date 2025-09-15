import { expect } from "chai";
import { ethers } from "hardhat";
import { FundraisingToken, RewardTracking, IEO } from "../typechain-types";

describe("Fundraising System Integration", function () {
  let token: FundraisingToken;
  let rewardTracking: RewardTracking;
  let ieo: IEO;
  let owner: any;
  let investor1: any;
  let investor2: any;
  let admin: any;

  beforeEach(async function () {
    [owner, investor1, investor2, admin] = await ethers.getSigners();

    // Deploy contracts in correct order
    token = await ethers.deployContract("FundraisingToken", [
      "FundraisingToken",
      "FRT",
      18,
      ethers.parseEther("1000000") // 1M initial supply
    ]);

    ieo = await ethers.deployContract("IEO", [
      await token.getAddress(),
      admin.address
    ]);

    rewardTracking = await ethers.deployContract("RewardTracking", [
      await token.getAddress(),
      await ieo.getAddress()
    ]);

    // Set cross-references
    await token.setRewardTrackingAddress(await rewardTracking.getAddress());
    await ieo.setRewardTrackingAddress(await rewardTracking.getAddress());

    // Add contracts to whitelist
    await token.addToWhitelist(await ieo.getAddress());
    await token.addToWhitelist(await rewardTracking.getAddress());
  });

  it("Should deploy all contracts successfully", async function () {
    expect(await token.name()).to.equal("FundraisingToken");
    expect(await token.symbol()).to.equal("FRT");
    expect(await token.decimals()).to.equal(18);
    expect(await token.totalSupply()).to.equal(ethers.parseUnits("1000000", 18));
  });

  it("Should have correct initial states", async function () {
    const poolInfo = await rewardTracking.getPoolInfo();
    expect(poolInfo[0]).to.equal(0n); // totalTokenSold
    expect(poolInfo[1]).to.equal(0n); // accumulatedRewardPerToken
    expect(poolInfo[2]).to.be.greaterThan(0n); // lastRewardBlock

    expect(await ieo.ieoActive()).to.be.false;
    expect(await ieo.totalRaised()).to.equal(0n);
    expect(await ieo.totalTokensSold()).to.equal(0n);
  });

  it("Should have reward tracking enabled after setup", async function () {
    expect(await token.isRewardTrackingEnabled()).to.be.true;
    expect(await ieo.isRewardTrackingEnabled()).to.be.true;
  });

  it("Should allow owner to start IEO", async function () {
    const duration = 7 * 24 * 60 * 60; // 7 days
    await ieo.startIEO(duration);
    
    expect(await ieo.ieoActive()).to.be.true;
    expect(await ieo.ieoStartTime()).to.be.greaterThan(0);
    expect(await ieo.ieoEndTime()).to.be.greaterThan(await ieo.ieoStartTime());
  });

  it("Should have correct contract relationships", async function () {
    expect(await token.rewardTrackingAddress()).to.equal(await rewardTracking.getAddress());
    expect(await ieo.rewardTrackingAddress()).to.equal(await rewardTracking.getAddress());
    expect(await rewardTracking.tokenAddress()).to.equal(await token.getAddress());
    expect(await rewardTracking.ieoContract()).to.equal(await ieo.getAddress());
  });
});