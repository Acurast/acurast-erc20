import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { network } from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";
import { ethers } from "hardhat";

describe("Ibc Contract", function () {
  let Ibc, ibc, owner, user1, user2, relayer, mockReceiver;

  beforeEach(async function () {
    [owner, user1, user2, relayer] = await ethers.getSigners();
    Ibc = await ethers.getContractFactory("Ibc");
    ibc = await Ibc.deploy();
    
    // Deploy mock message receiver for testing
    const MockReceiver = await ethers.getContractFactory("MockMessageReceiver");
    mockReceiver = await MockReceiver.deploy();
  });

  describe("Initialization", function () {
    it("should set correct default config", async function () {
      const config = await ibc.config();
      expect(config.minDeliverySignatures).to.equal(1);
      expect(config.minReceiptSignatures).to.equal(1);
      expect(config.minTTL).to.equal(20);
      expect(config.incomingTTL).to.equal(30);
    });

    it("should set the owner correctly", async function () {
      expect(await ibc.owner()).to.equal(owner.address);
    });
  });

  describe("Configuration", function () {
    it("should allow the owner to update the config", async function () {
      await ibc.configure(2, 2, 50, 100, 100); // Added missing incomingTTL parameter
      const config = await ibc.config();
      expect(config.minDeliverySignatures).to.equal(2);
      expect(config.minReceiptSignatures).to.equal(2);
      expect(config.minTTL).to.equal(50);
      expect(config.maxTTL).to.equal(100);
      expect(config.incomingTTL).to.equal(100);
    });

    it("should prevent non-owner from updating config", async function () {
      await expect(
        ibc.connect(user1).configure(2, 2, 50, 100, 100)
      ).to.be.reverted;
    });
  });

  describe("Sending Messages", function () {
    it("should allow users to send messages", async function () {
      const nonce = ethers.keccak256(ethers.toUtf8Bytes("test"));
      const recipient = ethers.zeroPadValue(user2.address, 32); // Convert address to bytes32
      const tx = await ibc
        .connect(user1)
        .sendMessage(nonce, recipient, "0x1234", 50, {
          value: ethers.parseEther("1"),
        });

      await expect(tx).to.emit(ibc, "MessageReadyToSend");
      const id = ethers.keccak256(
        ethers.solidityPacked(
          ["address", "bytes32"],
          [user1.address, nonce]
        )
      );
      const message = await ibc.outgoing(id);
      expect(message.message.sender).to.equal(user1.address);
    });

    it("should not allow sending a message with too low TTL", async function () {
      const nonce = ethers.keccak256(ethers.toUtf8Bytes("test"));
      const recipient = ethers.zeroPadValue(user2.address, 32); // Convert address to bytes32
      await expect(
        ibc
          .connect(user1)
          .sendMessage(nonce, recipient, "0x1234", 10, {
            value: ethers.parseEther("1"),
          })
      ).to.be.revertedWith("TTL too small");
    });
  });

  describe("Receiving Messages", function () {
    it("should allow relayers to receive messages with valid signatures", async function () {
      const acurastSender = ethers.zeroPadValue(user1.address, 32); // bytes32
      const nonce = ethers.keccak256(ethers.toUtf8Bytes("test"));
      const recipientIndex = 3; // ETHEREUM_INDEX
      const recipient = mockReceiver.target; // contract address
      const payload = "0x1234";
      const relayerBytes32 = ethers.zeroPadValue(relayer.address, 32); // bytes32

      // Generate a valid signature
      const messageHash = ethers.keccak256(
        ethers.solidityPacked(
          ["uint8", "bytes32", "bytes32", "uint8", "address", "bytes"],
          [0, acurastSender, nonce, recipientIndex, recipient, payload] // ACURAST_INDEX = 0
        )
      );
      const signature = await relayer.signMessage(
        ethers.getBytes(messageHash)
      );

      // Add the relayer as an oracle first
      await ibc.addOracle(relayer.address);

      const tx = await ibc
        .connect(relayer)
        .receiveMessage(acurastSender, nonce, recipientIndex, recipient, payload, relayerBytes32, [signature]);

      await expect(tx).to.emit(ibc, "MessageProcessed");

      const id = ethers.keccak256(
        ethers.solidityPacked(
          ["bytes32", "bytes32"],
          [acurastSender, nonce]
        )
      );
      const storedMessage = await ibc.incoming(id);
      expect(storedMessage.message.sender).to.equal(acurastSender);
    });

    it("should reject duplicate messages", async function () {
      const acurastSender = ethers.zeroPadValue(user1.address, 32); // bytes32
      const nonce = ethers.keccak256(ethers.toUtf8Bytes("test"));
      const recipientIndex = 3; // ETHEREUM_INDEX
      const recipient = mockReceiver.target; // contract address
      const payload = "0x1234";
      const relayerBytes32 = ethers.zeroPadValue(relayer.address, 32); // bytes32

      // Generate a valid signature
      const messageHash = ethers.keccak256(
        ethers.solidityPacked(
          ["uint8", "bytes32", "bytes32", "uint8", "address", "bytes"],
          [0, acurastSender, nonce, recipientIndex, recipient, payload] // ACURAST_INDEX = 0
        )
      );
      const signature = await relayer.signMessage(ethers.getBytes(messageHash));

      // Add the relayer as an oracle first
      await ibc.addOracle(relayer.address);

      await ibc
        .connect(relayer)
        .receiveMessage(acurastSender, nonce, recipientIndex, recipient, payload, relayerBytes32, [signature]);
      await expect(
        ibc
          .connect(relayer)
          .receiveMessage(acurastSender, nonce, recipientIndex, recipient, payload, relayerBytes32, [signature])
      ).to.be.revertedWith("Message already received");
    });
  });

  describe("Confirming Message Delivery", function () {
    it("should allow confirmation of delivered messages", async function () {
      const nonce = ethers.keccak256(ethers.toUtf8Bytes("test"));
      const recipient = ethers.zeroPadValue(user2.address, 32); // Convert address to bytes32
      await ibc
        .connect(user1)
        .sendMessage(nonce, recipient, "0x1234", 50, {
          value: ethers.parseEther("1"),
        });

      const id = ethers.keccak256(
        ethers.solidityPacked(
          ["address", "bytes32"],
          [user1.address, nonce]
        )
      );

      // Add owner as an oracle for signature validation
      await ibc.addOracle(owner.address);

      // Get the stored message to create proper signature
      const storedMessage = await ibc.outgoing(id);
      
      // Generate the message hash as done in the contract
      const messageHash = ethers.keccak256(
        ethers.solidityPacked(
          ["uint8", "address", "bytes32", "uint8", "bytes32", "bytes", "address"],
          [
            3, // ETHEREUM_INDEX
            storedMessage.message.sender,
            storedMessage.message.nonce,
            storedMessage.message.recipientIndex,
            storedMessage.message.recipient,
            storedMessage.message.payload,
            owner.address // msg.sender in the contract
          ]
        )
      );
      const signature = await owner.signMessage(
        ethers.getBytes(messageHash)
      );

      await expect(
        ibc.connect(owner).confirmMessageDelivery(id, [signature])
      ).to.emit(ibc, "MessageDelivered");
    });

    it("should reject confirmation of non-existent messages", async function () {
      const fakeId = ethers.keccak256(
        ethers.toUtf8Bytes("fakeMessage")
      );
      await expect(
        ibc.connect(owner).confirmMessageDelivery(fakeId, [])
      ).to.be.revertedWith("Message not found");
    });
  });

  describe("Cleaning Incoming Messages", function () {
    it("should allow owner to clean up expired messages", async function () {
      const acurastSender = ethers.zeroPadValue(user1.address, 32); // bytes32
      const nonce = ethers.keccak256(ethers.toUtf8Bytes("test"));
      const recipientIndex = 3; // ETHEREUM_INDEX
      const recipient = mockReceiver.target; // contract address
      const payload = "0x1234";
      const relayerBytes32 = ethers.zeroPadValue(relayer.address, 32); // bytes32

      // Generate a valid signature
      const messageHash = ethers.keccak256(
        ethers.solidityPacked(
          ["uint8", "bytes32", "bytes32", "uint8", "address", "bytes"],
          [0, acurastSender, nonce, recipientIndex, recipient, payload] // ACURAST_INDEX = 0
        )
      );
      const signature = await relayer.signMessage(ethers.getBytes(messageHash));

      // Add the relayer as an oracle first
      await ibc.addOracle(relayer.address);

      await ibc
        .connect(relayer)
        .receiveMessage(acurastSender, nonce, recipientIndex, recipient, payload, relayerBytes32, [signature]);

      const id = ethers.keccak256(
        ethers.solidityPacked(
          ["bytes32", "bytes32"],
          [acurastSender, nonce]
        )
      );

      // Verify message exists before cleanup
      const messageBeforeCleanup = await ibc.incoming(id);
      expect(messageBeforeCleanup.message.id).to.not.equal(ethers.ZeroHash);

      // Mine blocks to exceed incomingTTL (30 blocks by default)
      // We need: currentBlock + incomingTTL < block.number
      // So we mine 31 additional blocks to ensure cleanup condition is met
      for (let i = 0; i < 31; i++) {
        await network.provider.send("evm_mine");
      }

      // Clean up with the specific message ID
      await ibc.cleanIncomingIndex([id]);

      // Verify message was cleaned up
      const messageAfterCleanup = await ibc.incoming(id);
      expect(messageAfterCleanup.message.id).to.equal(ethers.ZeroHash);
    });
  });
});
