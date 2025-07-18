// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

abstract contract AcuERC20 is ERC20, ERC20Permit, Ownable {
    
    struct InitialBalance {
        address source;
        uint128 amount;
    }

    error NotEnabled();

    event Enabled(bool enabled);

    bool private _enabled;

    constructor(
        string memory name,
        string memory symbol,
        InitialBalance[] memory _initialBalances
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(msg.sender) {
        _enabled = false;

        for (uint i = 0; i < _initialBalances.length; i++) {
            _mint(_initialBalances[i].source, _initialBalances[i].amount * (10 ** decimals()));
        }
    }

    modifier onlyIfEnabled() {
        _checkEnabled();
        _;
    }

    function enabled() public view virtual returns (bool) {
        return _enabled;
    }

    function _checkEnabled() internal view virtual {
        if (!_enabled) {
            revert NotEnabled();
        }
    }

    function transfer(address to, uint256 value) public override onlyIfEnabled returns (bool) {
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override onlyIfEnabled returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function _setEnabled(bool enabled_) internal {
        _enabled = enabled_;
        emit Enabled(enabled_);
    }
}