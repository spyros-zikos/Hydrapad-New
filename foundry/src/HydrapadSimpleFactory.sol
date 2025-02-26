// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {HydrapadSimpleToken} from "./HydrapadSimpleToken.sol";

contract HydrapadSimpleFactory is Ownable {
    uint256 private s_fee;

    error InsufficientFunds();
    error FailedToSendPOL();

    constructor(uint256 fee) Ownable(msg.sender) {
        s_fee = fee;
    }

    function createERC20(
        string memory name,
        string memory symbol,
        address owner,
        uint256 supply,
        uint8 decimals,
        bool mintable,
        bool burnable,
        bool permitable
    ) external payable returns (address) {
        if (msg.value < s_fee) revert InsufficientFunds();
        return address(new HydrapadSimpleToken(name, symbol, owner, supply, decimals, mintable, burnable, permitable));
    }

    function withdrawFees() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        if (!success) revert FailedToSendPOL();
    }
}

