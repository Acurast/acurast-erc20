// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IERC20TransferRestrictor.sol";

contract TransferRestrictor is IERC20TransferRestrictor, Ownable {
    mapping(address => bool) public fromDenyList;

    event DenyFrom(address indexed from);
    event AllowFrom(address indexed from);
    
    constructor(address[] memory _fromDenyList) Ownable(msg.sender) {
        for (uint i = 0; i < _fromDenyList.length; i++) {
            fromDenyList[_fromDenyList[i]] = true; 
        }
    }

    function denyFrom(address from) external onlyOwner {
        fromDenyList[from] = true;
        emit DenyFrom(from);
    }

    function allowFrom(address from) external onlyOwner {
        delete fromDenyList[from];
        emit AllowFrom(from);
    }

    function isTransferAllowed(address from, address to, uint256 value) external view returns (bool) {
        return !fromDenyList[from];
    }
}