// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

contract AcurastToken is ERC20, Ownable {
    address public ibcContract;
    bytes32 public tokenPalletAccount; // The only allowed sender and automatic receiver
    uint256 public outgoingTTL;
    // a map with all incoming transfers for deduplication
    mapping(uint32 => bool) public incomingTransferNonces;
    uint32 public nextTransferNonce;
    mapping(uint32 => OutgoingTransfer) public outgoingTransfers;

    constructor(
        address _ibcContract,
        bytes32 _tokenPalletAccount
    ) ERC20("Acurast", "ACU") Ownable(msg.sender) {
        require(_ibcContract != address(0), "Invalid IBC contract address");
        ibcContract = _ibcContract;
        tokenPalletAccount = _tokenPalletAccount;
        outgoingTTL = 50;

        // TODO remove (temporary for testing)
        _mint(msg.sender, 100 * 10 ** decimals());
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
    event TransferReceived(
        uint256 amount,
        address indexed dest,
        uint32 transferNonce
    );

    function decimals() public view virtual override returns (uint8) {
        return 12;
    }

    function updateIbcContract(address _ibcContract) external onlyOwner {
        require(_ibcContract != address(0), "Invalid IBC contract address");
        emit IbcContractUpdated(ibcContract, _ibcContract);
        ibcContract = _ibcContract;
    }

    function updateTokenPalletAccount(
        bytes32 _tokenPalletAccount
    ) external onlyOwner {
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
        require(sender == tokenPalletAccount, "Unauthorized sender");

        require(payload.length >= 4, "Invalid action");

        // e.g.
        // 00000000 0000000000000000000000003B9ACA00 00000000 00000013       147B33C5B12767B3ABEE547212AF27B1398CE517
        // action   amount (16 bytes)                asset_id transfer_nonce dest

        uint32 action;
        assembly {
            action := shr(224, mload(add(payload, 32))) // bytes 0–3 (skipping length field of 4 bytes)
        }

        if (action == 0) {
            require(payload.length == 48, "Invalid ation payload");

            uint128 amount;
            uint32 assetId;
            uint32 transferNonce;
            address dest;
            assembly {
                amount := mload(add(payload, 36)) // bytes 4–19
                assetId := shr(224, mload(add(payload, 52))) // bytes 20–23
                transferNonce := shr(224, mload(add(payload, 56))) // bytes 24–27
                dest := shr(96, mload(add(payload, 60))) // bytes 28–47
            }

            // disallow transfer to 0-address (burning the tokens)
            require(dest != address(0), "Invalid recipient");
            require(assetId == 0, "Unsupported assetId");
            require(
                !incomingTransferNonces[transferNonce],
                "Transfer already received"
            );

            incomingTransferNonces[transferNonce] = true;
            _mint(dest, amount);
            emit TransferReceived(amount, dest, transferNonce);
        } else {
            revert("Unsupported action");
        }
    }

    function transferNative(uint128 amount, bytes32 dest) public payable {
        require(amount > 0, "Cannot transfer 0 amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient ACU balance");

        uint32 transferNonce = nextTransferNonce;

        // Increment transfer nonce
        nextTransferNonce++;

        // Generate a unique nonce
        bytes32 nonce = keccak256(abi.encodePacked(transferNonce));

        // Encode the payload
        bytes memory payload = abi.encodePacked(
            uint32(0), // action_id (0 for transfer)
            amount,
            uint32(0), // assetId (assumed 0)
            transferNonce,
            dest
        );

        // Burn only the ACU amount, not the ETH fee, which is locked in ibc contract automatically in call below
        _burn(msg.sender, amount);

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

        // Generate a unique nonce again
        bytes32 nonce = keccak256(abi.encodePacked(transferNonce));

        // Encode the payload
        bytes memory payload = abi.encodePacked(
            uint32(0), // action_id (0 for transfer)
            transfer.amount,
            uint32(0), // assetId (assumed 0)
            transferNonce,
            transfer.dest
        );

        // Do not burn the ACU amount again since this is a retry that will be deduplicated at target chain (Acurast), in case both original and retry message(s) get delivered eventually.

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
