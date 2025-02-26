// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {HydrapadSimpleFactory} from "../src/HydrapadSimpleFactory.sol";

contract DeployHydrapadSimpleFactory is Script {
    uint256 private constant CREATION_FEE = 20 ether;  // 20 POL

    function run() public returns (HydrapadSimpleFactory) {
        vm.startBroadcast(vm.envAddress("ACCOUNT_ADDRESS"));
        HydrapadSimpleFactory factory = new HydrapadSimpleFactory(
            CREATION_FEE
        );
        vm.stopBroadcast();
        return factory;
    }
}