// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {HydrapadPresaleToken} from "../src/HydrapadPresaleToken.sol";


contract DeployHydrapadPresaleToken is Script {
    function run() public returns (HydrapadPresaleToken) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        HydrapadPresaleToken.ConstructorParams memory params = HydrapadPresaleToken.ConstructorParams(
            "Hydrapad Presale Token",
            "HPT",
            vm.envAddress("ACCOUNT_ADDRESS"),
            config.totalSupply,
            config.remainingTokens,
            config.accumulatedPOL,
            config.feeBPS,
            config.uniFeeBPS,
            config.migrationFee,
            config.poolCreationFee,
            config.marketCapMin,
            config.marketCapMax,
            config.tokensNeededToMigrate,
            config.feeCollector,
            config.uniFeeCollector,
            config.uniswapV2Router
        );

        vm.startBroadcast(vm.envAddress("ACCOUNT_ADDRESS"));
        HydrapadPresaleToken token = new HydrapadPresaleToken(
            params
        );
        vm.stopBroadcast();
        return token;
    }
}