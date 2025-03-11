// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

abstract contract CodeConstants {
    address public WHITE_HAT_DAO_ADDRESS = 0xB5A790568471c23dE46533F1706a238B04D59F25;
    address public SIGNER = 0xc6d37C379816c96344b0e9523AC440523052675F;

    uint256 public constant BASE_CHAIN_ID = 8453;
    uint256 public constant POLYGON_CHAIN_ID = 137;
    uint256 public constant POLYGON_AMOY_CHAIN_ID = 80002;
}

contract HelperConfig is CodeConstants, Script {
    struct NetworkConfig {
        uint256 totalSupply;
        uint256 remainingTokens;
        uint256 accumulatedPOL;
        uint256 marketCapMin;
        uint256 marketCapMax;
        uint256 tokensNeededToMigrate;
        uint256 poolCreationFee;
        uint256 migrationFee;
        uint256 feeBPS;
        uint256 uniFeeBPS;
        address feeCollector;
        address uniFeeCollector;
        address signer;
        address uniswapV2Router;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    error HelperConfig__InvalidChainId();

    constructor() {
        networkConfigs[BASE_CHAIN_ID] = getBaseConfig();
        networkConfigs[POLYGON_CHAIN_ID] = getPolygonConfig();
        networkConfigs[POLYGON_AMOY_CHAIN_ID] = getPolygonAmoyConfig();
    }

    function getConfigByChainId(uint256 chainId) public view returns(NetworkConfig memory) {
        if (networkConfigs[chainId].signer != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public view returns(NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getBaseConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: 1_000_000_000_000_000_000_000_000_000, // 1 billion
            remainingTokens: 1_060_000_000_000_000_000_000_000_000, // 1.06 billion
            accumulatedPOL: 1_600_000_000_000_000_000, // 1.6
            marketCapMin: 25_000_000_000_000_000_000,
            marketCapMax: 27_000_000_000_000_000_000,
            tokensNeededToMigrate: 799_538_870_462_404_697_804_703_491, // 800 million
            poolCreationFee: 50_000_000_000_000_000,
            migrationFee: 100_000_000_000_000_000,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
        });
    } // 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24

    function getPolygonConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: 1000000000000000000000000000, // 1 billion
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: 25000000000000000000,
            marketCapMax: 27000000000000000000,
            tokensNeededToMigrate: 799538870462404697804703491, // 800 million
            poolCreationFee: 50000000000000000,
            migrationFee: 100000000000000000,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0xedf6066a2b290C185783862C7F4776A2C8077AD1
        });
    } // 0xedf6066a2b290C185783862C7F4776A2C8077AD1

    function getPolygonAmoyConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: 1000000000000000000000000000, // 1 billion
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: 100000_000000000000000000,
            marketCapMax: 110000_000000000000000000,
            tokensNeededToMigrate: 800000000000000000000000000, // 800 million
            poolCreationFee: 500000000000000000000, // 500 POL
            migrationFee: 500000000000000000000, // 500 POL
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0xD4d332B3f56A5686E257f08e4Be982a9c1ed5fFb // mock
        });
    } // 0xD4d332B3f56A5686E257f08e4Be982a9c1ed5fFb
}