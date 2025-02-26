// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract HydrapadSimpleToken is ERC20, Ownable, ERC20Permit {
    uint8 private immutable i_decimals;
    bool private immutable i_mintable;
    bool private immutable i_burnable;
    bool private immutable i_permitable;

    error TokenIsNotMintable();
    error TokenIsNotBurnable();
    error TokenIsNotPermitable();

    constructor(string memory name,
        string memory symbol,
        address owner,
        uint256 supply,
        uint8 _decimals,
        bool mintable,
        bool burnable,
        bool permitable
    )
        ERC20(name, symbol)
        Ownable(owner)
        ERC20Permit(name)
    {
        _mint(owner, supply);
        i_decimals = _decimals;
        i_mintable = mintable;
        i_burnable = burnable;
        i_permitable = permitable;
    }

    function decimals() public view override returns (uint8) {
        return i_decimals;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        if (i_mintable == false) revert TokenIsNotMintable();
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        if (i_burnable == false) revert TokenIsNotBurnable();
        _burn(from, amount);
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public override {
        if (i_permitable == false) revert TokenIsNotPermitable();
        permit(owner, spender, value, deadline, v, r, s);
    }

    function isMintable() public view returns (bool) {
        return i_mintable;
    }

    function isBurnable() public view returns (bool) {
        return i_burnable;
    }
    
    function isPermitable() public view returns (bool) {
        return i_permitable;
    }
}