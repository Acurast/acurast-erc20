// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title MockMessageReceiver
 * @dev Mock contract for testing IBC message reception
 */
contract MockMessageReceiver {
    bytes32 public lastSender;
    bytes public lastPayload;
    uint256 public messageCount;
    
    event MessageReceived(bytes32 sender, bytes payload);
    
    function processMessage(bytes32 sender, bytes calldata payload) external {
        lastSender = sender;
        lastPayload = payload;
        messageCount++;
        
        emit MessageReceived(sender, payload);
    }
    
    function reset() external {
        lastSender = bytes32(0);
        lastPayload = "";
        messageCount = 0;
    }
}