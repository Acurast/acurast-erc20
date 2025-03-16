// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

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

contract AcurastToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable
{
    address public ibcContract;
    bytes32 public tokenPalletAccount; // The only allowed sender and automatic receiver
    uint256 public outgoingTTL;
    mapping(uint32 => bool) public incomingTransferNonces;
    uint32 public nextTransferNonce;
    mapping(uint32 => OutgoingTransfer) public outgoingTransfers;

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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        // TODO remove (temporary for testing)
        address recipient,
        address initialOwner,
        address _ibcContract,
        bytes32 _tokenPalletAccount
    ) public initializer {
        __ERC20_init("AcurastToken", "ACU");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("AcurastToken");
        __UUPSUpgradeable_init();
        require(_ibcContract != address(0), "Invalid IBC contract address");
        ibcContract = _ibcContract;
        tokenPalletAccount = _tokenPalletAccount;

        _mint(recipient, 100 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
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

        uint32 action;
        assembly {
            action := mload(add(payload, 32)) // Read first 4 bytes
        }

        if (action == 0) {
            require(payload.length == 48, "Invalid ation payload");

            // Decode the remaining payload safely
            (
                ,
                uint128 amount,
                uint32 assetId,
                uint32 transferNonce,
                address dest
            ) = abi.decode(payload, (uint32, uint128, uint32, uint32, address));

            // disallow transfer to 0-address (burning the tokens)
            require(dest != address(0), "Invalid recipient");
            require(assetId != 0, "Unsupported assetId");
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
                "sendMessage(bytes32,address,bytes,uint256)",
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
                "sendMessage(bytes32,address,bytes,uint256)",
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

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }
}
