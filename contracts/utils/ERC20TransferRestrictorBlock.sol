// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IERC20TransferRestrictor.sol";

/// @title Hard Transfer Restrictor
/// @notice Rejects all ERC20 transfers unconditionally
contract ERC20TransferRestrictorBlock is IERC20TransferRestrictor {
    /// @inheritdoc IERC20TransferRestrictor
    function isTransferAllowed(address, address, uint256) external pure override returns (bool) {
        return false;
    }
}
