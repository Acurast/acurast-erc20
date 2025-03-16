import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("Ibc Contract", function () {
  let Ibc, ibc, owner, user1, user2, relayer;

  beforeEach(async function () {
    [owner, user1, user2, relayer] = await ethers.getSigners();
    Ibc = await ethers.getContractFactory("Ibc");
    ibc = await Ibc.deploy();
    await ibc.initialize();
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
      await ibc.configure(2, 2, 50, 100);
      const config = await ibc.config();
      expect(config.minDeliverySignatures).to.equal(2);
      expect(config.minReceiptSignatures).to.equal(2);
      expect(config.minTTL).to.equal(50);
      expect(config.incomingTTL).to.equal(100);
    });

    it("should prevent non-owner from updating config", async function () {
      await expect(
        ibc.connect(user1).configure(2, 2, 50, 100)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Sending Messages", function () {
    it("should allow users to send messages", async function () {
      const nonce = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const tx = await ibc
        .connect(user1)
        .sendMessage(nonce, user2.address, "0x1234", 50, {
          value: ethers.utils.parseEther("1"),
        });

      await expect(tx).to.emit(ibc, "MessageReadyToSend");
      const id = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["address", "bytes32"],
          [user1.address, nonce]
        )
      );
      const message = await ibc.outgoing(id);
      expect(message.message.sender).to.equal(user1.address);
    });

    it("should not allow sending a message with too low TTL", async function () {
      const nonce = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      await expect(
        ibc
          .connect(user1)
          .sendMessage(nonce, user2.address, "0x1234", 10, {
            value: ethers.utils.parseEther("1"),
          })
      ).to.be.revertedWith("TTL too small");
    });
  });

  describe("Receiving Messages", function () {
    it("should allow relayers to receive messages with valid signatures", async function () {
      const sender = user1.address;
      const nonce = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const recipient = user2.address;
      const payload = "0x1234";

      // Generate a valid signature (mocked here)
      const messageHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["address", "bytes32", "address", "bytes"],
          [sender, nonce, recipient, payload]
        )
      );
      const signature = await relayer.signMessage(
        ethers.utils.arrayify(messageHash)
      );

      const tx = await ibc
        .connect(relayer)
        .receiveMessage(sender, nonce, recipient, payload, [signature]);

      await expect(tx).to.emit(ibc, "MessageProcessed");

      const id = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["address", "bytes32"],
          [sender, nonce]
        )
      );
      const storedMessage = await ibc.incoming(id);
      expect(storedMessage.message.sender).to.equal(sender);
    });

    it("should reject duplicate messages", async function () {
      const sender = user1.address;
      const nonce = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const recipient = user2.address;
      const payload = "0x1234";
      const signature = await relayer.signMessage(ethers.utils.arrayify(nonce));

      await ibc
        .connect(relayer)
        .receiveMessage(sender, nonce, recipient, payload, [signature]);
      await expect(
        ibc
          .connect(relayer)
          .receiveMessage(sender, nonce, recipient, payload, [signature])
      ).to.be.revertedWith("Message already received");
    });
  });

  describe("Confirming Message Delivery", function () {
    it("should allow confirmation of delivered messages", async function () {
      const nonce = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      await ibc
        .connect(user1)
        .sendMessage(nonce, user2.address, "0x1234", 50, {
          value: ethers.utils.parseEther("1"),
        });

      const id = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["address", "bytes32"],
          [user1.address, nonce]
        )
      );

      // Generate a valid signature (mocked here)
      const messageHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["bytes32", "address"],
          [id, owner.address]
        )
      );
      const signature = await owner.signMessage(
        ethers.utils.arrayify(messageHash)
      );

      await expect(
        ibc.connect(owner).confirmMessageDelivery(id, [signature])
      ).to.emit(ibc, "MessageDelivered");
    });

    it("should reject confirmation of non-existent messages", async function () {
      const fakeId = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("fakeMessage")
      );
      await expect(
        ibc.connect(owner).confirmMessageDelivery(fakeId, [])
      ).to.be.revertedWith("Message does not exist");
    });
  });

  describe("Cleaning Incoming Messages", function () {
    it("should allow owner to clean up expired messages", async function () {
      const sender = user1.address;
      const nonce = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const recipient = user2.address;
      const payload = "0x1234";

      const signature = await relayer.signMessage(ethers.utils.arrayify(nonce));
      await ibc
        .connect(relayer)
        .receiveMessage(sender, nonce, recipient, payload, [signature]);

      // Simulate passage of time
      await network.provider.send("evm_mine", [
        (await ethers.provider.getBlock("latest")).timestamp + 100,
      ]);

      await ibc.cleanIncomingIndex();

      const id = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["address", "bytes32"],
          [sender, nonce]
        )
      );
      expect(await ibc.incoming(id).message.id).to.equal(
        ethers.constants.HashZero
      );
    });
  });
});
