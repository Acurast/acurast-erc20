// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import AcurastHyperdriveIbc from "./AcurastHyperdriveIbc";

const AcurastToken = buildModule("AcurastToken", (m) => {
  const { ibc } = m.useModule(AcurastHyperdriveIbc);

  // Deploy the AcurastToken Contract
  const acurastToken = m.contract("AcurastToken", [
    "Acurast",
    "ACU",
    ibc, // Set the IBC Contract address in the Token contract
    "0x0000000000000000000000000000000000000000000000000000000000000000", // token pallet account on Acurast parachain
    [
      {
        source: "0x0D9649EF2b751D94f6dBb1370F1EE052f33107d4", // replace with real address
        amount: "1000",
      },
    ],
  ]);

  return { acurastToken };
});

export default AcurastToken;
