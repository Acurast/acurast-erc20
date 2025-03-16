// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import Ibc from "./Ibc";

const AcurastToken = buildModule("AcurastToken", (m) => {
  const { ibc } = m.useModule(Ibc);

  // Deploy the AcurastToken Contract
  const acurastToken = m.contract("AcurastToken");
  // Initialize the AcurastToken Contract directly after
  m.call(acurastToken, "initialize", [
    m.getAccount(0), // Initial recipient of 100 ACUs tokens (temporary for testing)
    m.getAccount(0), // Contract owner
    ibc, // Set the IBC Contract address in the Token contract
    "5EYCAe5h8kmzoA4mxYQmkSEPPrDy93poMdg9Lh1d8SehErVo", // token pallet account on Acurast parachain
  ]);

  return { acurastToken };
});

export default AcurastToken;
