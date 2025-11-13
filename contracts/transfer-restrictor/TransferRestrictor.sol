// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IERC20TransferRestrictor.sol";

contract TransferRestrictor is IERC20TransferRestrictor {
    mapping(address => bool) public fromDenyList;
    
    constructor(address[] memory _fromDenyList) {
        for (uint i = 0; i < _fromDenyList.length; i++) {
            fromDenyList[_fromDenyList[i]] = true; 
        }
    }

    function isTransferAllowed(address from, address to, uint256 value) external view returns (bool) {
        return fromDenyList[from] == false;
    }
}