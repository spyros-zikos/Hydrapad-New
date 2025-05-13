// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

abstract contract CodeConstants {
    address public WHITE_HAT_DAO_ADDRESS = 0xB5A790568471c23dE46533F1706a238B04D59F25;
    address public SIGNER = 0xc6d37C379816c96344b0e9523AC440523052675F;

    uint256 public constant BASE_CHAIN_ID = 8453;
    uint256 public constant POLYGON_CHAIN_ID = 137;
    uint256 public constant POLYGON_AMOY_CHAIN_ID = 80002;
    uint256 public constant UNICHAIN_CHAIN_ID = 130;
    uint256 public constant AVALANCHE_CHAIN_ID = 43114;
    uint256 public constant AVALANCHE_FUJI_CHAIN_ID = 43113;
    uint256 public constant BNB_CHAIN_ID = 56;
    uint256 public constant OPTIMISM_CHAIN_ID = 10;
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;

    uint256 public constant ONE_BILLION = 1_000_000_000 * 1e18; //1000000000000000000000000000
    uint256 public constant EIGHT_HUNDREAD_MILLION = 800_000_000 * 1e18; //800000000000000000000000000

    // ~$6k liquidity to migrate
    uint256 public constant ETH_MARKET_CAP_MIN = 15 * 1e18; // 15 ETH
    uint256 public constant ETH_MARKET_CAP_MAX = 16 * 1e18; // 16 ETH
    uint256 public constant POL_MARKET_CAP_MIN = 100000 * 1e18; // 100k POL
    uint256 public constant POL_MARKET_CAP_MAX = 110000 * 1e18; // 110k POL
    uint256 public constant AVAX_MARKET_CAP_MIN = 1500 * 1e18; // 1500 AVAX
    uint256 public constant AVAX_MARKET_CAP_MAX = 1600 * 1e18; // 1600 AVAX
    uint256 public constant BNB_MARKET_CAP_MIN = 50 * 1e18; // 50 BNB
    uint256 public constant BNB_MARKET_CAP_MAX = 52 * 1e18; // 52 BNB

    // ~$300 fee to migrate
    uint256 public constant ETH_HALF_MIGRATION_FEE = 0.15 * 1e18 / 2;
    uint256 public constant POL_HALF_MIGRATION_FEE = 500 * 1e18 / 2;
    uint256 public constant AVAX_HALF_MIGRATION_FEE = 14 * 1e18 / 2;
    uint256 public constant BNB_HALF_MIGRATION_FEE = 0.45 * 1e18 / 2;
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
        networkConfigs[POLYGON_CHAIN_ID] = getPolygonConfigLMC();
        networkConfigs[POLYGON_AMOY_CHAIN_ID] = getPolygonAmoyConfig();
        networkConfigs[UNICHAIN_CHAIN_ID] = getUnichainConfig();
        networkConfigs[AVALANCHE_CHAIN_ID] = getAvalancheConfig();
        networkConfigs[AVALANCHE_FUJI_CHAIN_ID] = getAvalancheFujiConfig();
        networkConfigs[BNB_CHAIN_ID] = getBnbConfig();
        networkConfigs[OPTIMISM_CHAIN_ID] = getOptimismConfig();
        networkConfigs[ARBITRUM_CHAIN_ID] = getArbitrumConfig();
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
            totalSupply: ONE_BILLION,
            remainingTokens: 1_060_000_000_000_000_000_000_000_000, // 1.06 billion
            accumulatedPOL: 1_600_000_000_000_000_000, // 1.6
            marketCapMin: ETH_MARKET_CAP_MIN,
            marketCapMax: ETH_MARKET_CAP_MAX,
            tokensNeededToMigrate: EIGHT_HUNDREAD_MILLION,
            poolCreationFee: ETH_HALF_MIGRATION_FEE,
            migrationFee: ETH_HALF_MIGRATION_FEE,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
        });
    }

    function getPolygonConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: ONE_BILLION,
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: POL_MARKET_CAP_MIN,
            marketCapMax: POL_MARKET_CAP_MAX,
            tokensNeededToMigrate: EIGHT_HUNDREAD_MILLION,
            poolCreationFee: POL_HALF_MIGRATION_FEE,
            migrationFee: POL_HALF_MIGRATION_FEE,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0xedf6066a2b290C185783862C7F4776A2C8077AD1
        });
    }

        function getPolygonConfigLMC() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: ONE_BILLION,
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: 25e18,  // Liquidity = 5 POL //25000000000000000000
            marketCapMax: 30e18,  //30000000000000000000
            tokensNeededToMigrate: EIGHT_HUNDREAD_MILLION,
            poolCreationFee: 0.125e18,  // Total fee = 0.25 POL //125000000000000000
            migrationFee: 0.125e18,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0xedf6066a2b290C185783862C7F4776A2C8077AD1
        });
    }

    function getPolygonAmoyConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: ONE_BILLION,
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: POL_MARKET_CAP_MIN,
            marketCapMax: POL_MARKET_CAP_MAX,
            tokensNeededToMigrate: EIGHT_HUNDREAD_MILLION,
            poolCreationFee: POL_HALF_MIGRATION_FEE,
            migrationFee: POL_HALF_MIGRATION_FEE,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0xD4d332B3f56A5686E257f08e4Be982a9c1ed5fFb // mock
        });
    }

    function getUnichainConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: ONE_BILLION,
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: ETH_MARKET_CAP_MIN,
            marketCapMax: ETH_MARKET_CAP_MAX,
            tokensNeededToMigrate: EIGHT_HUNDREAD_MILLION,
            poolCreationFee: ETH_HALF_MIGRATION_FEE,
            migrationFee: ETH_HALF_MIGRATION_FEE,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0x284F11109359a7e1306C3e447ef14D38400063FF
        });
    }

    function getAvalancheConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: ONE_BILLION,
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: AVAX_MARKET_CAP_MIN,
            marketCapMax: AVAX_MARKET_CAP_MAX,
            tokensNeededToMigrate: EIGHT_HUNDREAD_MILLION,
            poolCreationFee: AVAX_HALF_MIGRATION_FEE,
            migrationFee: AVAX_HALF_MIGRATION_FEE,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
        });
    }

    function getAvalancheFujiConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: ONE_BILLION,
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: AVAX_MARKET_CAP_MIN,
            marketCapMax: AVAX_MARKET_CAP_MAX,
            tokensNeededToMigrate: EIGHT_HUNDREAD_MILLION,
            poolCreationFee: AVAX_HALF_MIGRATION_FEE,
            migrationFee: AVAX_HALF_MIGRATION_FEE,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0xD4d332B3f56A5686E257f08e4Be982a9c1ed5fFb // NOTE: NOT WORKING
        });
    }

    function getBnbConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: ONE_BILLION,
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: BNB_MARKET_CAP_MIN,
            marketCapMax: BNB_MARKET_CAP_MAX,
            tokensNeededToMigrate: EIGHT_HUNDREAD_MILLION,
            poolCreationFee: BNB_HALF_MIGRATION_FEE,
            migrationFee: BNB_HALF_MIGRATION_FEE,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
        });
    }

    function getOptimismConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: ONE_BILLION,
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: ETH_MARKET_CAP_MIN,
            marketCapMax: ETH_MARKET_CAP_MAX,
            tokensNeededToMigrate: EIGHT_HUNDREAD_MILLION,
            poolCreationFee: ETH_HALF_MIGRATION_FEE,
            migrationFee: ETH_HALF_MIGRATION_FEE,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2
        });
    }

    function getArbitrumConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: ONE_BILLION,
            remainingTokens: 1060000000000000000000000000, // 1.06 billion
            accumulatedPOL: 1600000000000000000, // 1.6
            marketCapMin: ETH_MARKET_CAP_MIN,
            marketCapMax: ETH_MARKET_CAP_MAX,
            tokensNeededToMigrate: EIGHT_HUNDREAD_MILLION,
            poolCreationFee: ETH_HALF_MIGRATION_FEE,
            migrationFee: ETH_HALF_MIGRATION_FEE,
            feeBPS: 100,
            uniFeeBPS: 6000,
            feeCollector: WHITE_HAT_DAO_ADDRESS,
            uniFeeCollector: WHITE_HAT_DAO_ADDRESS,
            signer: SIGNER,
            uniswapV2Router: 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
        });
    }
}