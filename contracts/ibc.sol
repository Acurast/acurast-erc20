// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Ibc is Ownable {
    Config public config;
    mapping(bytes32 => OutgoingMessageWithMeta) public outgoing;
    mapping(bytes32 => IncomingMessageWithMeta) public incoming;
    uint256 public messageCounter;
    mapping(address => bool) public oraclePublicKeys;

    constructor() Ownable(msg.sender) {
        config = Config({
            minDeliverySignatures: 1,
            minReceiptSignatures: 1,
            minTTL: 20,
            maxTTL: 200,
            incomingTTL: 30
        });
    }

    struct Config {
        uint8 minDeliverySignatures;
        uint8 minReceiptSignatures;
        uint256 minTTL;
        uint256 maxTTL;
        uint256 incomingTTL;
    }

    struct OutgoingMessage {
        bytes32 id;
        address sender;
        bytes32 nonce;
        bytes32 recipient;
        bytes payload;
    }

    struct IncomingMessage {
        bytes32 id;
        bytes32 sender;
        bytes32 nonce;
        address recipient;
        bytes payload;
    }

    struct OutgoingMessageWithMeta {
        OutgoingMessage message;
        uint256 currentBlock;
        uint256 ttlBlock;
        uint256 fee;
        address payer;
    }

    struct IncomingMessageWithMeta {
        IncomingMessage message;
        uint256 currentBlock;
        address relayer;
    }

    event OracleAdded(address indexed oracle);
    event OracleRemoved(address indexed oracle);
    event MessageReadyToSend(OutgoingMessage message);
    event MessageDelivered(bytes32 id);
    event MessageProcessed(bytes32 id);
    event MessageProcessedWithErrors(
        bytes32 sender,
        address recipient,
        bytes payload,
        string reason
    );

    function configure(
        uint8 minDeliverySignatures,
        uint8 minReceiptSignatures,
        uint256 minTTL,
        uint256 maxTTL,
        uint256 incomingTTL
    ) public onlyOwner {
        config.minDeliverySignatures = minDeliverySignatures;
        config.minReceiptSignatures = minReceiptSignatures;
        config.minTTL = minTTL;
        config.maxTTL = maxTTL;
        config.incomingTTL = incomingTTL;
    }

    function addOracle(address oracle) external onlyOwner {
        require(!oraclePublicKeys[oracle], "Oracle already added");
        oraclePublicKeys[oracle] = true;
        emit OracleAdded(oracle);
    }

    function removeOracle(address oracle) external onlyOwner {
        require(oraclePublicKeys[oracle], "Oracle not found");
        delete oraclePublicKeys[oracle];
        emit OracleRemoved(oracle);
    }

    function sendMessage(
        bytes32 nonce,
        bytes32 recipient,
        bytes memory payload,
        uint256 ttl
    ) public payable returns (bool) {
        require(ttl >= config.minTTL, "TTL too small");
        require(ttl <= config.maxTTL, "TTL too large");
        bytes32 id = keccak256(abi.encodePacked(msg.sender, nonce));

        // Solidity returns default value for maps if key does not exist, so check for non-zero value
        if (outgoing[id].ttlBlock != 0) {
            // potential duplicate found: check for ttl
            if (outgoing[id].ttlBlock >= block.number) {
                revert("Message with same nonce pending");
            }

            // continue below and overwrite message
        }

        outgoing[id] = OutgoingMessageWithMeta({
            message: OutgoingMessage({
                id: id,
                sender: msg.sender,
                nonce: nonce,
                recipient: recipient,
                payload: payload
            }),
            currentBlock: block.number,
            ttlBlock: block.number + ttl,
            // make sure the exact value payed to this contract at the moment of sendMessage is stored for later payout to the relayer
            fee: msg.value,
            payer: msg.sender
        });
        messageCounter++;
        emit MessageReadyToSend(outgoing[id].message);
        return true;
    }

    function confirmMessageDelivery(
        bytes32 id,
        bytes[] memory signatures
    ) public {
        require(outgoing[id].message.id != 0, "Message not found"); // Ensure message exists

        require(
            outgoing[id].ttlBlock >= block.number,
            "Delivery confirmation overdue"
        );

        // since id is hash of sender + nonce, it's not necessary to be part of signed payload
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                outgoing[id].message.sender,
                outgoing[id].message.nonce,
                outgoing[id].message.recipient,
                outgoing[id].message.payload,
                msg.sender // ensures no front-running of competing relayer trying to get fee
            )
        );
        checkSignatures(messageHash, signatures, config.minDeliverySignatures); // Ensure valid signature

        // payout to the relayer
        payable(outgoing[id].payer).transfer(outgoing[id].fee);
        delete outgoing[id];

        emit MessageDelivered(id);
    }

    function receiveMessage(
        bytes32 sender,
        bytes32 nonce,
        address recipient,
        bytes memory payload,
        bytes[] memory signatures
    ) public {
        // since id is hash of sender + nonce, it's not necessary to be part of signed payload
        bytes32 messageHash = keccak256(
            abi.encodePacked(sender, nonce, recipient, payload)
        );
        checkSignatures(messageHash, signatures, config.minReceiptSignatures); // Ensure valid signature

        bytes32 id = keccak256(abi.encodePacked(sender, nonce));
        require(incoming[id].message.id == 0, "Message already received");
        incoming[id] = IncomingMessageWithMeta({
            message: IncomingMessage({
                id: id,
                sender: sender,
                nonce: nonce,
                recipient: recipient,
                payload: payload
            }),
            currentBlock: block.number,
            relayer: msg.sender
        });

        require(recipient.code.length > 0, "Recipient is not a contract");

        (bool success, bytes memory returnData) = recipient.call(
            abi.encodeWithSignature(
                "processMessage(bytes32,bytes)",
                sender,
                payload
            )
        );

        if (!success) {
            string memory errorMessage = _getRevertReason(returnData);
            emit MessageProcessedWithErrors(
                sender,
                recipient,
                payload,
                errorMessage
            );
        }

        emit MessageProcessed(id);
    }

    function _getRevertReason(
        bytes memory returnData
    ) private pure returns (string memory) {
        if (returnData.length < 68) return "Unknown failure";

        assembly {
            returnData := add(returnData, 0x04) // Skip function selector
        }
        return abi.decode(returnData, (string));
    }

    function checkSignatures(
        bytes32 messageHash,
        bytes[] memory signatures,
        uint8 min_signatures
    ) internal view {
        require(signatures.length >= min_signatures, "Not enough signatures");

        address[] memory seenSigners = new address[](signatures.length);
        uint256 validSignatures = 0;

        for (uint256 i = 0; i < signatures.length; i++) {
            address recoveredSigner = ECDSA.recover(messageHash, signatures[i]);

            // Ensure the signer is an authorized oracle
            require(oraclePublicKeys[recoveredSigner], "Invalid signature");

            // Check for duplicates
            for (uint256 j = 0; j < validSignatures; j++) {
                require(
                    seenSigners[j] != recoveredSigner,
                    "Duplicate signature detected"
                );
            }

            // Store the valid signer
            seenSigners[validSignatures] = recoveredSigner;
            validSignatures++;

            // If we reach min_signatures, exit early
            if (validSignatures >= min_signatures) {
                return;
            }
        }

        require(
            validSignatures >= min_signatures,
            "Not enough unique valid signatures"
        );
    }

    function cleanIncomingIndex(bytes32[] calldata clean) external onlyOwner {
        for (uint256 i = 0; i < clean.length; i++) {
            if (
                incoming[clean[i]].currentBlock + config.incomingTTL <
                block.number
            ) {
                delete incoming[clean[i]];
            }
        }
    }
}
