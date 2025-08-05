// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC20TransferRestrictor {
    error TransferRestricted();
    
    function isTransferAllowed(address from, address to, uint256 value) external view returns (bool);
}