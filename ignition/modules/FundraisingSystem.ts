import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

export default buildModule("FundraisingSystem", (m) => {
  // Step 1: Deploy FundraisingToken (no reward tracking address needed)
  const token = m.contract("FundraisingToken", [
    "Fundraising Token",
    "FRT",
    18,
    m.parseEther("1000000") // 1M tokens
  ]);

  // Step 2: Deploy IEO (with token address, no reward tracking address)
  const ieo = m.contract("IEO", [
    token,
    m.getAccount(1) // admin
  ]);

  // Step 3: Deploy RewardTracking (with both token and IEO addresses)
  const rewardTracking = m.contract("RewardTracking", [
    token,
    ieo
  ]);

  // Step 4: Set cross-references
  m.call(token, "setRewardTrackingAddress", [rewardTracking]);
  m.call(ieo, "setRewardTrackingAddress", [rewardTracking]);

  // Step 5: Add contracts to whitelist
  m.call(token, "addToWhitelist", [ieo]);
  m.call(token, "addToWhitelist", [rewardTracking]);

  return { token, ieo, rewardTracking };
});