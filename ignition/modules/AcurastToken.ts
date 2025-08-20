// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
// import AcurastHyperdriveIbc from "./AcurastHyperdriveIbc";

const AcurastToken = buildModule("AcurastToken", (m) => {
//   const { ibc } = m.useModule(AcurastHyperdriveIbc);

  // Deploy the AcurastToken Contract (pure ERC20) with CoinList initial balances
  // CoinList token sale: May 15, 2025 to May 22, 2025
  const acurastToken = m.contract("AcurastToken", [
    "ACU",
    "ACU",
    [
      {
        source: "0xcC5739Af13B822154d9d858E36EeF11587c09546", // CoinList fee payment (5,000,000 ACU)
        amount: "5000000",
      },
      {
        source: "0x5780dFA96011dC8F6a85f94640aCa0490949dfcA", // CoinList user purchases (59,906,307 ACU)
        amount: "59906307",
      },
    ],
  ]);

//   // Deploy the HyperdriveTokenBridge Contract
//   const bridge = m.contract("HyperdriveTokenBridge", [
//     acurastToken, // Token contract address
//     ibc, // IBC Contract address
//     "0x6d6f646c687970746f6b656e0000000000000000000000000000000000000000", // token pallet account on Acurast parachain
//     m.getAccount(0), // Bridge owner (deployer)
//   ]);

//   // Grant TOKEN_BRIDGE role to the bridge contract
//   // The role is calculated as keccak256("TOKEN_BRIDGE") in the contract
//   m.call(acurastToken, "grantRole", [
//     m.staticCall(acurastToken, "TOKEN_BRIDGE", []),
//     bridge
//   ]);

  return { acurastToken/*, bridge*/ };
});

export default AcurastToken;
