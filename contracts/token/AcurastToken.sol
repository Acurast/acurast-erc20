// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./AcuERC20.sol";

contract AcurastToken is AcuERC20 {

    struct InitialBalance {
        address source;
        uint128 amount;
    }
    
    constructor(
        string memory name,
        string memory symbol,
        InitialBalance[] memory _initialBalances
    ) AcuERC20(name, symbol) {
        uint8 tokenDecimals = decimals();
        uint256 multiplier = 10 ** tokenDecimals;
        
        for (uint i = 0; i < _initialBalances.length; i++) {
            require(_initialBalances[i].source != address(0), "Invalid address");
            require(_initialBalances[i].amount > 0, "Amount must be greater than 0");
            
            // SECURITY FIX: Check for overflow before multiplication
            // Maximum safe amount is type(uint256).max / (10 ** decimals())
            require(_initialBalances[i].amount <= type(uint256).max / multiplier, "Amount too large");
            
            uint256 mintAmount = _initialBalances[i].amount * multiplier;
            _mint(_initialBalances[i].source, mintAmount);
        }
    }

    function decimals() public view virtual override returns (uint8) {
        return 12;
    }
}