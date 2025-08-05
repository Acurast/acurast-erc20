// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title MaliciousReentrant
 * @dev Contract for testing reentrancy vulnerabilities in the bridge system
 * This contract attempts to reenter the bridge during message processing
 */
contract MaliciousReentrant {
    address public targetBridge;
    bool public hasAttacked = false;
    
    constructor() {
        // No target set initially - will be set during attack attempt
    }
    
    // This function will be called by the IBC contract during receiveMessage
    function processMessage(bytes32 sender, bytes calldata payload) external {
        if (!hasAttacked) {
            hasAttacked = true;
            // Attempt reentrancy by calling back into the caller
            (bool success, ) = msg.sender.call(
                abi.encodeWithSignature(
                    "receiveMessage(bytes32,bytes32,uint8,address,bytes,bytes32,bytes[])",
                    sender,
                    bytes32(uint256(0x123)), // different nonce
                    uint8(3), // ETHEREUM_INDEX
                    address(this),
                    payload,
                    bytes32(uint256(0x456)), // relayer
                    new bytes[](0) // empty signatures - should fail
                )
            );
            
            // This should fail due to reentrancy protection
            require(!success, "Reentrancy attack succeeded - this should not happen!");
        }
    }
    
    // Fallback to catch any unexpected calls
    fallback() external {
        revert("Unexpected call to malicious contract");
    }
}