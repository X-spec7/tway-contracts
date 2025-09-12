import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const FundraisingTokenModule = buildModule("FundraisingTokenModule", (m) => {
  // Deploy FundraisingToken with initial parameters
  const fundraisingToken = m.contract("FundraisingToken", [
    "FundraisingToken", // name
    "FRT",              // symbol
    18,                 // decimals
    1000000             // initial supply (1M tokens)
  ]);

  return { fundraisingToken };
});

export default FundraisingTokenModule;