// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Bridgeable.sol";
import "../interfaces/IERC20TransferRestrictor.sol";

abstract contract AcuERC20 is ERC20, ERC20Permit, ERC20Bridgeable, AccessControlDefaultAdminRules {

    bytes32 public constant TOKEN_BRIDGE = keccak256("TOKEN_BRIDGE");
    bytes32 public constant RESTRICTOR_UPDATER = keccak256("RESTRICTOR_UPDATER");

    address private erc20TransferRestrictor = address(0x000000000000000000000000000000000000dEaD); // transfers are disabled to start, can be extended with allowlists in future.
    bool private transfersAreUnrestricted = false;

    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) ERC20Permit(name) AccessControlDefaultAdminRules(5 days, msg.sender) {

    }

    event ERC20TransferRestrictorContractUpdated(
        address indexed oldAddress,
        address indexed newAddress
    );

    modifier restrictTransfer(address from, address to, uint256 value) {
        if (!transfersAreUnrestricted) { // for efficiency we skip if zero address is set
            if (!IERC20TransferRestrictor(erc20TransferRestrictor).isTransferAllowed(from, to, value)) {
                revert IERC20TransferRestrictor.TransferRestricted();
            }
        }
        _;
    }

    function updateErc20TransferRestrictor(address _erc20TransferRestrictor) external onlyRole(RESTRICTOR_UPDATER) {
        emit ERC20TransferRestrictorContractUpdated(erc20TransferRestrictor, _erc20TransferRestrictor);
        erc20TransferRestrictor = _erc20TransferRestrictor;
        transfersAreUnrestricted = (_erc20TransferRestrictor == address(0));
    }

    function transfer(address to, uint256 value) public override restrictTransfer(msg.sender, to, value) returns (bool) {
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override restrictTransfer(from, to, value) returns (bool) {
        return super.transferFrom(from, to, value);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC20Bridgeable, AccessControlDefaultAdminRules) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Checks if the caller has the TOKEN_BRIDGE role for crosschain operations
     */
    function _checkTokenBridge(address caller) internal virtual override {
        require(hasRole(TOKEN_BRIDGE, caller), "AcuERC20: caller is not a bridge");
    }
}