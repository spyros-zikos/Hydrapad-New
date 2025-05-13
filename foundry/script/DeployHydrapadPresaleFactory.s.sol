// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {HydrapadPresaleFactory} from "../src/HydrapadPresaleFactory.sol";

contract DeployHydrapadPresaleFactory is Script {
    function run() public returns (HydrapadPresaleFactory) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(vm.envAddress("ACCOUNT_ADDRESS"));
        HydrapadPresaleFactory factory = new HydrapadPresaleFactory(
            config.totalSupply,
            config.remainingTokens,
            config.accumulatedPOL,
            config.marketCapMin,
            config.marketCapMax,
            config.tokensNeededToMigrate,
            config.poolCreationFee,
            config.migrationFee,
            config.feeBPS,
            config.uniFeeBPS,
            config.feeCollector,
            config.uniFeeCollector,
            config.signer,
            config.uniswapV2Router
        );
        vm.stopBroadcast();
        return factory;
    }
}