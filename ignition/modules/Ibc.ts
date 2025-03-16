// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const Ibc = buildModule("Ibc", (m) => {
  // Deploy the IBC Contract
  const ibcContract = m.contract("Ibc");
  // Initialize the IBC Contract

  m.call(ibcContract, "initialize", [m.getAccount(0)]);

  return { ibcContract };
});

export default Ibc;
