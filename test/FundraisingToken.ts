import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("FundraisingToken", function () {
  let token: any;
  let owner: any;
  let user1: any;
  let user2: any;
  let user3: any;

  beforeEach(async function () {
    [owner, user1, user2, user3] = await ethers.getSigners();
    token = await ethers.deployContract("FundraisingToken", ["FundraisingToken", "FRT", 18, 1000000]);
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

  it("Should add address to whitelist", async function () {
    expect(await token.isWhitelisted(user1.address)).to.be.false;
    
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
    const addresses = [user1.address, user2.address];
    
    await token.batchAddToWhitelist(addresses);
    
    expect(await token.isWhitelisted(user1.address)).to.be.true;
    expect(await token.isWhitelisted(user2.address)).to.be.true;
  });

  it("Should batch remove addresses from whitelist", async function () {
    await token.addToWhitelist(user1.address);
    await token.addToWhitelist(user2.address);
    
    const addresses = [user1.address, user2.address];
    await token.batchRemoveFromWhitelist(addresses);
    
    expect(await token.isWhitelisted(user1.address)).to.be.false;
    expect(await token.isWhitelisted(user2.address)).to.be.false;
  });

  it("Should require both sender and recipient whitelisted for transfer", async function () {
    const amount = ethers.parseUnits("1000", 18);
    
    // Should fail - user1 not whitelisted
    await expect(
      token.connect(user1).transfer(user2.address, amount)
    ).to.be.revertedWithCustomError(token, "SenderNotWhitelisted");
    
    // Add user1 to whitelist
    await token.addToWhitelist(user1.address);
    
    // Should still fail - user2 not whitelisted
    await expect(
      token.connect(user1).transfer(user2.address, amount)
    ).to.be.revertedWithCustomError(token, "RecipientNotWhitelisted");
    
    // Add user2 to whitelist
    await token.addToWhitelist(user2.address);
    
    // Transfer some tokens to user1 first
    await token.transfer(user1.address, amount);
    
    // Now transfer should work
    await token.connect(user1).transfer(user2.address, amount);
    
    expect(await token.balanceOf(user2.address)).to.equal(amount);
  });

  it("Should require both sender and recipient whitelisted for transferFrom", async function () {
    const amount = ethers.parseUnits("1000", 18);
    
    // Add users to whitelist (but NOT user3)
    await token.addToWhitelist(user1.address);
    await token.addToWhitelist(user2.address);
    // user3 is NOT whitelisted
    
    // Transfer tokens to user1
    await token.transfer(user1.address, amount);
    
    // Approve user2 to spend user1's tokens
    await token.connect(user1).approve(user2.address, amount);
    
    // user3 tries to transferFrom (not whitelisted) - this should fail with RecipientNotWhitelisted
    await expect(
      token.connect(user3).transferFrom(user1.address, user3.address, amount)
    ).to.be.revertedWithCustomError(token, "RecipientNotWhitelisted");
    
    // Add user3 to whitelist
    await token.addToWhitelist(user3.address);
    
    // user2 transfers (whitelisted)
    await token.connect(user2).transferFrom(user1.address, user3.address, amount);
    
    expect(await token.balanceOf(user3.address)).to.equal(amount);
  });

  it("Should require whitelist for approve", async function () {
    const amount = ethers.parseUnits("1000", 18);
    
    // user1 not whitelisted
    await expect(
      token.connect(user1).approve(user2.address, amount)
    ).to.be.revertedWithCustomError(token, "CallerNotWhitelisted");
    
    // Add user1 to whitelist
    await token.addToWhitelist(user1.address);
    
    // user2 not whitelisted
    await expect(
      token.connect(user1).approve(user2.address, amount)
    ).to.be.revertedWithCustomError(token, "SpenderNotWhitelisted");
    
    // Add user2 to whitelist
    await token.addToWhitelist(user2.address);
    
    // Now approve should work
    await token.connect(user1).approve(user2.address, amount);
    
    expect(await token.allowance(user1.address, user2.address)).to.equal(amount);
  });

  it("Should fail to mint when authority is frozen", async function () {
    const mintAmount = ethers.parseUnits("50000", 18);
    
    // Add user1 to whitelist
    await token.addToWhitelist(user1.address);
    
    // Should fail - mint authority is frozen
    await expect(
      token.mint(user1.address, mintAmount)
    ).to.be.revertedWithCustomError(token, "MintAuthorityFrozen");
  });

  it("Should burn tokens correctly", async function () {
    const burnAmount = ethers.parseUnits("10000", 18);
    
    // Should fail - user1 not whitelisted
    await expect(
      token.connect(user1).burn(burnAmount)
    ).to.be.revertedWithCustomError(token, "CallerNotWhitelisted");
    
    // Add user1 to whitelist and give tokens
    await token.addToWhitelist(user1.address);
    await token.transfer(user1.address, burnAmount);
    
    // Now burn should work
    await token.connect(user1).burn(burnAmount);
    
    expect(await token.balanceOf(user1.address)).to.equal(0);
    expect(await token.totalSupply()).to.equal(ethers.parseUnits("990000", 18));
  });

  it("Should only allow owner to manage whitelist", async function () {
    await expect(
      token.connect(user1).addToWhitelist(user2.address)
    ).to.be.revertedWithCustomError(token, "CallerNotOwner");
    
    await expect(
      token.connect(user1).removeFromWhitelist(user2.address)
    ).to.be.revertedWithCustomError(token, "CallerNotOwner");
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
    const amount = ethers.parseUnits("1000", 18);
    
    await token.addToWhitelist(user1.address);
    await token.addToWhitelist(user2.address);
    await token.transfer(user1.address, amount);
    
    await expect(token.connect(user1).transfer(user2.address, amount))
      .to.emit(token, "Transfer")
      .withArgs(user1.address, user2.address, amount);
  });

  it("Should emit Approval events", async function () {
    const amount = ethers.parseUnits("1000", 18);
    
    await token.addToWhitelist(user1.address);
    await token.addToWhitelist(user2.address);
    
    await expect(token.connect(user1).approve(user2.address, amount))
      .to.emit(token, "Approval")
      .withArgs(user1.address, user2.address, amount);
  });
});