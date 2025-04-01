// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AcurastHyperdriveIbc = buildModule("AcurastHyperdriveIbc", (m) => {
  const initialOwner = m.getAccount(0);

  // Implementation Deployment (Logic contract, see Proxy below)
  const ibcImplementation = m.contract("Ibc"); // Assumes Ibc.sol is compiled

  // Initialization Data
  const initData = m.encodeFunctionCall(ibcImplementation, "initialize", [
    initialOwner, // The owner address parameter defined above
  ]);

  // Proxy Deployment
  const proxy = m.contract("ERC1967Proxy", [ibcImplementation, initData]);

  // To interact with the deployed upgradeable contract easily,
  // create a contract instance pointing to the *proxy* address,
  // but using the *Ibc* contract's ABI.
  const ibcProxy = m.contractAt("Ibc", proxy, {
    id: "ibcProxy",
  });

  // Return the proxy instance so it can be easily accessed from other deployment modules such as AcurastToken.ts
  return { ibcProxy };
});

export default AcurastHyperdriveIbc;
