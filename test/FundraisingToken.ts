import { expect } from "chai";
import { ethers } from "hardhat";
import { FundraisingToken } from "../typechain-types";

describe("FundraisingToken", function () {
  let token: FundraisingToken;
  let owner: any;
  let user1: any;
  let user2: any;
  let user3: any;

  beforeEach(async function () {
    [owner, user1, user2, user3] = await ethers.getSigners();
    token = await ethers.deployContract("FundraisingToken", ["FundraisingToken", "FRT", 18, ethers.parseEther("1000000")]);
  });

  it("Should have correct initial supply", async function () {
    const totalSupply = await token.totalSupply();
    const ownerBalance = await token.balanceOf(owner.address);

    expect(totalSupply).to.equal(ethers.parseUnits("1000000", 18));
    expect(ownerBalance).to.equal(ethers.parseUnits("1000000", 18));
  });

  it("Should have correct name, symbol, and decimals", async function () {
    expect(await token.name()).to.equal("FundraisingToken");
    expect(await token.symbol()).to.equal("FRT");
    expect(await token.decimals()).to.equal(18);
  });

  it("Should have owner whitelisted initially", async function () {
    expect(await token.isWhitelisted(owner.address)).to.be.true;
  });

  it("Should have mint authority frozen after deployment", async function () {
    expect(await token.isMintAuthorityFrozen()).to.be.true;
  });

  it("Should have reward tracking disabled initially", async function () {
    expect(await token.isRewardTrackingEnabled()).to.be.false;
  });

  it("Should add address to whitelist", async function () {
    await token.addToWhitelist(user1.address);
    expect(await token.isWhitelisted(user1.address)).to.be.true;
  });

  it("Should remove address from whitelist", async function () {
    await token.addToWhitelist(user1.address);
    expect(await token.isWhitelisted(user1.address)).to.be.true;
    
    await token.removeFromWhitelist(user1.address);
    expect(await token.isWhitelisted(user1.address)).to.be.false;
  });

  it("Should batch add addresses to whitelist", async function () {
    const addresses = [user1.address, user2.address, user3.address];
    await token.batchAddToWhitelist(addresses);
    
    expect(await token.isWhitelisted(user1.address)).to.be.true;
    expect(await token.isWhitelisted(user2.address)).to.be.true;
    expect(await token.isWhitelisted(user3.address)).to.be.true;
  });

  it("Should batch remove addresses from whitelist", async function () {
    const addresses = [user1.address, user2.address, user3.address];
    await token.batchAddToWhitelist(addresses);
    
    await token.batchRemoveFromWhitelist(addresses);
    
    expect(await token.isWhitelisted(user1.address)).to.be.false;
    expect(await token.isWhitelisted(user2.address)).to.be.false;
    expect(await token.isWhitelisted(user3.address)).to.be.false;
  });

  it("Should require both sender and recipient whitelisted for transfer", async function () {
    await token.addToWhitelist(user1.address);
    await token.addToWhitelist(user2.address);
    
    const transferAmount = ethers.parseEther("100");
    
    // Should succeed when both are whitelisted
    await token.transfer(user2.address, transferAmount);
    expect(await token.balanceOf(user2.address)).to.equal(transferAmount);
    
    // Should fail when recipient is not whitelisted
    await expect(
      token.transfer(user3.address, transferAmount)
    ).to.be.revertedWithCustomError(token, "RecipientNotWhitelisted");
  });

  it("Should require both sender and recipient whitelisted for transferFrom", async function () {
    await token.addToWhitelist(user1.address);
    await token.addToWhitelist(user2.address);
    
    const transferAmount = ethers.parseEther("100");
    await token.approve(user1.address, transferAmount);
    
    // Should succeed when both are whitelisted
    await token.connect(user1).transferFrom(owner.address, user2.address, transferAmount);
    expect(await token.balanceOf(user2.address)).to.equal(transferAmount);
    
    // Should fail when recipient is not whitelisted
    await expect(
      token.connect(user1).transferFrom(owner.address, user3.address, transferAmount)
    ).to.be.revertedWithCustomError(token, "RecipientNotWhitelisted");
  });

  it("Should require whitelist for approve", async function () {
    await expect(
      token.connect(user1).approve(user2.address, ethers.parseEther("100"))
    ).to.be.revertedWithCustomError(token, "CallerNotWhitelisted");
  });

  it("Should fail to mint when authority is frozen", async function () {
    await expect(
      token.mint(user1.address, ethers.parseEther("1000"))
    ).to.be.revertedWithCustomError(token, "MintAuthorityFrozen");
  });

  it("Should burn tokens correctly", async function () {
    await token.addToWhitelist(user1.address);
    const burnAmount = ethers.parseEther("100");
    
    await token.connect(user1).burn(burnAmount);
    expect(await token.balanceOf(user1.address)).to.equal(ethers.parseEther("999900"));
  });

  it("Should only allow owner to manage whitelist", async function () {
    await expect(
      token.connect(user1).addToWhitelist(user2.address)
    ).to.be.revertedWithCustomError(token, "CallerNotOwner");
  });

  it("Should set reward tracking address and enable it", async function () {
    const mockRewardTracking = ethers.Wallet.createRandom().address;
    
    await token.setRewardTrackingAddress(mockRewardTracking);
    
    expect(await token.rewardTrackingAddress()).to.equal(mockRewardTracking);
    expect(await token.isRewardTrackingEnabled()).to.be.true;
  });

  it("Should emit whitelist events", async function () {
    await expect(token.addToWhitelist(user1.address))
      .to.emit(token, "AddressWhitelisted")
      .withArgs(user1.address);
    
    await expect(token.removeFromWhitelist(user1.address))
      .to.emit(token, "AddressRemovedFromWhitelist")
      .withArgs(user1.address);
  });

  it("Should emit Transfer events", async function () {
    await token.addToWhitelist(user1.address);
    
    await expect(token.transfer(user1.address, ethers.parseEther("100")))
      .to.emit(token, "Transfer")
      .withArgs(owner.address, user1.address, ethers.parseEther("100"));
  });

  it("Should emit Approval events", async function () {
    await token.addToWhitelist(user1.address);
    
    await expect(token.approve(user1.address, ethers.parseEther("100")))
      .to.emit(token, "Approval")
      .withArgs(owner.address, user1.address, ethers.parseEther("100"));
  });
});