// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../token/AcurastToken.sol";

interface IIbc {
    function config()
        external
        view
        returns (
            uint8 minDeliverySignatures,
            uint8 minReceiptSignatures,
            uint256 minTTL,
            uint256 maxTTL,
            uint256 incomingTTL
        );
}

contract HyperdriveTokenBridge is Ownable {
    AcurastToken public token;
    address public ibcContract;
    bytes32 public tokenPalletAccount; // The only allowed sender and automatic receiver
    uint256 public outgoingTTL;
    
    // a map with all incoming transfers for deduplication
    mapping(uint32 => bool) public incomingTransferNonces;
    uint32 public nextTransferNonce;
    mapping(uint32 => OutgoingTransfer) public outgoingTransfers;

    uint8 public constant BRIDGE_TRANSFER_ACTION = 0;
    uint8 public constant ENABLE_ACTION = 1;

    constructor(
        address _token,
        address _ibcContract,
        bytes32 _tokenPalletAccount,
        address _owner
    ) Ownable(_owner) {
        require(_token != address(0), "Invalid token address");
        require(_ibcContract != address(0), "Invalid IBC contract address");
        require(_owner != address(0), "Invalid owner address");
        require(_tokenPalletAccount != bytes32(0), "Invalid token pallet account");
        
        token = AcurastToken(_token);
        ibcContract = _ibcContract;
        tokenPalletAccount = _tokenPalletAccount;
        outgoingTTL = 50;
    }

    struct OutgoingTransfer {
        address sender;
        uint128 amount;
        bytes32 dest;
    }

    event IbcContractUpdated(
        address indexed oldAddress,
        address indexed newAddress
    );

    event TokenPalletAccountUpdated(
        bytes32 indexed oldAddress,
        bytes32 indexed newAddress
    );

    event OutgoingTTLUpdated(uint256 indexed oldTTL, uint256 indexed newTTL);

    event TransferSent(
        uint128 amount,
        uint256 fee,
        bytes32 indexed dest,
        uint32 transferNonce
    );

    event TransferRetried(
        uint128 amount,
        uint256 fee,
        bytes32 indexed dest,
        uint32 transferNonce
    );

    event TransferRestrictionsUpdated(
        bool indexed restricted,
        address indexed restrictorAddress
    );

    event TransferReceived(
        uint256 amount,
        address indexed dest,
        uint32 transferNonce
    );

    function updateIbcContract(address _ibcContract) external onlyOwner {
        require(_ibcContract != address(0), "Invalid IBC contract address");
        emit IbcContractUpdated(ibcContract, _ibcContract);
        ibcContract = _ibcContract;
    }

    function updateTokenPalletAccount(
        bytes32 _tokenPalletAccount
    ) external onlyOwner {
        require(_tokenPalletAccount != bytes32(0), "Invalid token pallet account");
        emit TokenPalletAccountUpdated(tokenPalletAccount, _tokenPalletAccount);
        tokenPalletAccount = _tokenPalletAccount;
    }

    function setOutgoingTTL(uint256 _outgoingTTL) external onlyOwner {
        IIbc ibc = IIbc(ibcContract); // Cast ibcContract to IIbc interface
        (, , uint256 minTTL, uint256 maxTTL, ) = ibc.config();
        require(_outgoingTTL >= minTTL, "OutgoingTTL too small");
        require(_outgoingTTL <= maxTTL, "OutgoingTTL too large");

        emit OutgoingTTLUpdated(outgoingTTL, _outgoingTTL);
        outgoingTTL = _outgoingTTL;
    }

    function processMessage(bytes32 sender, bytes memory payload) public {
        require(msg.sender == ibcContract, "Unauthorized origin");
        require(sender == tokenPalletAccount, "Unauthorized sender");
        require(payload.length >= 4, "Invalid action");

        // e.g.
        //        00000030 00000000 0000000000000000000000003B9ACA00 00000000 00000013       147B33C5B12767B3ABEE547212AF27B1398CE517
        //        length   action   amount                           asset_id transfer_nonce dest
        // bytes: 4        4        16                               4        4              20                                       (total: 48 without length prefix)

        // When you use a dynamic bytes memory variable like payload, the memory slot pointed to by the variable stores the length of the byte array. The actual data of the array begins 32 bytes after this pointer
        uint32 action;
        assembly {
            action := shr(224, mload(add(payload, 32))) // bytes 0–3 (skipping length field of 4 bytes)
        }

        if (action == BRIDGE_TRANSFER_ACTION) {
            // `payload.length` returns the length of the data chunk, not the length of the dynamic array, in other words it just reads the first 4 bytes encoding the length
            require(payload.length == 48, "Invalid action payload");

            uint128 amount;
            uint32 assetId;
            uint32 transferNonce;
            address dest;

            // SECURITY FIX: Safer assembly with explicit bounds checking
            assembly {
                // Verify we have enough data before reading
                let payloadPtr := add(payload, 0x20) // Skip the length prefix
                let payloadLen := mload(payload)
                
                // Double-check payload length in assembly
                if lt(payloadLen, 48) {
                    revert(0, 0)
                }

                // The amount is a u128 (16 bytes) starting at offset 4 in the data.
                // We load the 32-byte word at data_ptr + 4. The amount is in the most significant 16 bytes.
                // We shift right by 128 bits (256 - 128) to isolate the amount.
                amount := shr(128, mload(add(payloadPtr, 4))) // bytes 4-19

                // assetId is a u32 (4 bytes) at offset 20.
                // Load the word at data_ptr + 20 and shift right by 224 bits (256 - 32).
                assetId := shr(224, mload(add(payloadPtr, 20))) // bytes 20-23

                // transferNonce is a u32 (4 bytes) at offset 24.
                // Load the word at data_ptr + 24 and shift right by 224 bits (256 - 32).
                transferNonce := shr(224, mload(add(payloadPtr, 24))) // bytes 24-27

                // dest is an address (20 bytes) at offset 28.
                // Load the word at data_ptr + 28 and shift right by 96 bits (256 - 160).
                dest := shr(96, mload(add(payloadPtr, 28))) // bytes 28-47
            }

            // disallow transfer to 0-address (burning the tokens)
            require(dest != address(0), "Invalid recipient");
            require(assetId == 0, "Unsupported assetId");
            require(
                !incomingTransferNonces[transferNonce],
                "Transfer already received"
            );

            incomingTransferNonces[transferNonce] = true;
            
            // Use crosschainMint instead of _mint
            token.crosschainMint(dest, amount);
            emit TransferReceived(amount, dest, transferNonce);
        } else if (action == ENABLE_ACTION) {
            // enable/disable contract transfers
            // e.g.
            //        00000030 00000001 01
            //        length   action   enable_flag
            // bytes: 4        4        1              (total: 5 without length prefix)

            require(payload.length == 5, "Invalid action payload");

            uint8 enable;

            assembly {
                enable := shr(248, mload(add(payload, 36)))
            }

            // SECURITY FIX: Proper validation for enable/disable functionality
            // Only enable transfers if the flag is 1, otherwise keep restrictions
            if (enable == 1) {
                token.updateErc20TransferRestrictor(address(0));
                emit TransferRestrictionsUpdated(false, address(0));
            } else {
                revert("Invalid enable flag");
            }
        } else {
            revert("Unsupported action");
        }
    }

    function transferNative(
        uint128 amount,
        bytes32 dest
    ) public payable {
        require(amount > 0, "Cannot transfer 0 amount");
        require(dest != bytes32(0), "Invalid destination");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient ACU balance");

        uint32 transferNonce = nextTransferNonce;

        // Increment transfer nonce
        nextTransferNonce++;

        // SECURITY FIX: Generate a more secure nonce with additional entropy
        bytes32 nonce = keccak256(abi.encodePacked(
            transferNonce,
            msg.sender,
            block.timestamp,
            block.number,
            amount,
            dest
        ));

        // Encode the payload
        bytes memory payload = abi.encodePacked(
            uint32(0), // action_id (0 for transfer)
            amount,
            uint32(0), // assetId (assumed 0)
            transferNonce,
            dest
        );

        // Use crosschainBurn instead of _burn
        token.crosschainBurn(msg.sender, amount);

        // Store the transfer details
        outgoingTransfers[transferNonce] = OutgoingTransfer({
            sender: msg.sender,
            amount: amount,
            dest: dest
        });

        // Call sendMessage on the IBC contract
        (bool success, ) = ibcContract.call{value: msg.value}(
            abi.encodeWithSignature(
                "sendMessage(bytes32,bytes32,bytes,uint256)",
                nonce,
                tokenPalletAccount,
                payload,
                outgoingTTL
            )
        );

        require(success, "sendMessage failed");

        emit TransferSent(amount, msg.value, dest, transferNonce);
    }

    function retryTransferNative(uint32 transferNonce) public payable {
        require(
            outgoingTransfers[transferNonce].amount > 0,
            "Transfer not found"
        );

        OutgoingTransfer memory transfer = outgoingTransfers[transferNonce];

        // SECURITY FIX: Generate a more secure nonce with additional entropy (same as original)
        bytes32 nonce = keccak256(abi.encodePacked(
            transferNonce,
            transfer.sender,
            block.timestamp,
            block.number,
            transfer.amount,
            transfer.dest
        ));

        // Encode the payload
        bytes memory payload = abi.encodePacked(
            uint32(0), // action_id (0 for transfer)
            transfer.amount,
            uint32(0), // assetId (assumed 0)
            transferNonce,
            transfer.dest
        );

        // Do not burn the ACU amount again since this is a retry that will be deduplicated at target chain, in case both original and retry message(s) get delivered eventually.

        // Call sendMessage on the IBC contract
        (bool success, ) = ibcContract.call{value: msg.value}(
            abi.encodeWithSignature(
                "sendMessage(bytes32,bytes32,bytes,uint256)",
                nonce,
                tokenPalletAccount,
                payload,
                outgoingTTL
            )
        );

        require(success, "sendMessage failed");

        emit TransferRetried(
            transfer.amount,
            msg.value,
            transfer.dest,
            transferNonce
        );
    }
}