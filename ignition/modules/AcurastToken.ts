// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import AcurastHyperdriveIbc from "./AcurastHyperdriveIbc";

const AcurastToken = buildModule("AcurastToken", (m) => {
  const { ibc } = m.useModule(AcurastHyperdriveIbc);

  // Deploy the AcurastToken Contract
  const acurastToken = m.contract("AcurastToken", [
    ibc, // Set the IBC Contract address in the Token contract
    "0x6d6f646c687970746f6b656e0000000000000000000000000000000000000000", // token pallet account on Acurast parachain (5EYCAe5h8kmzoA4mxYQmkSEPPrDy93poMdg9Lh1d8SehErVo)
  ]);

  return { acurastToken };
});

export default AcurastToken;
