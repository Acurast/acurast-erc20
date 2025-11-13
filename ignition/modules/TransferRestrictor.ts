// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TransferRestrictor = buildModule("TransferRestrictor", (m) => {

  const contract = m.contract("TransferRestrictor", [[]]);

  return { contract };
});

export default TransferRestrictor;
