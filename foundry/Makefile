-include .env

.PHONY: all test deploy deploy-sepolia deploy-presale deploy-simple

build :; forge build

test :; forge test

install :; forge install openzeppelin/openzeppelin-contracts@v5.0.0 --no-commit

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
# 	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
# endif

ifeq ($(findstring --network base,$(ARGS)),--network base)
	NETWORK_ARGS := --rpc-url $(BASE_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(BASESCAN_API_KEY) --optimizer-runs 1 -vvvv
endif
ifeq ($(findstring --network polygon,$(ARGS)),--network polygon)
	NETWORK_ARGS := --rpc-url $(POLYGON_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(POLYGONSCAN_API_KEY) --optimizer-runs 1 -vvvv
endif
ifeq ($(findstring --network amoy,$(ARGS)),--network amoy)
	NETWORK_ARGS := --rpc-url $(POLYGON_AMOY_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(POLYGONSCAN_API_KEY) --optimizer-runs 1 -vvvv
endif

ifeq ($(findstring --network unichain,$(ARGS)),--network unichain)
	NETWORK_ARGS := --rpc-url $(UNICHAIN_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(UNISCAN_API_KEY) --optimizer-runs 1 -vvvv
endif
ifeq ($(findstring --network avalanche,$(ARGS)),--network avalanche)
	NETWORK_ARGS := --rpc-url $(AVAX_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(AVAX_API_KEY) --optimizer-runs 1 -vvvv
endif
ifeq ($(findstring --network fuji,$(ARGS)),--network fuji)
	NETWORK_ARGS := --rpc-url $(AVAX_FUJI_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(AVAX_API_KEY) --optimizer-runs 1 -vvvv
endif
ifeq ($(findstring --network bnb,$(ARGS)),--network bnb)
	NETWORK_ARGS := --rpc-url $(BNB_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(BSCSCAN_API_KEY) --optimizer-runs 1 -vvvv
endif
ifeq ($(findstring --network optimism,$(ARGS)),--network optimism)
	NETWORK_ARGS := --rpc-url $(OPTIMISM_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(OPTIMISM_API_KEY) --optimizer-runs 1 -vvvv
endif
ifeq ($(findstring --network arbitrum,$(ARGS)),--network arbitrum)
	NETWORK_ARGS := --rpc-url $(ARBITRUM_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(ARBITRUM_API_KEY) --optimizer-runs 1 -vvvv
endif


# To deploy run:  make deploy-presale ARGS="--network x"  ,
# where x = amoy, polygon, base, unichain, avalanche, fuji, bnb, optimism, arbitrum
deploy-presale:
	@forge script script/DeployHydrapadPresaleFactory.s.sol:DeployHydrapadPresaleFactory $(NETWORK_ARGS) --via-ir
deploy-simple:
	@forge script script/DeployHydrapadSimpleFactory.s.sol:DeployHydrapadSimpleFactory $(NETWORK_ARGS) --via-ir



############# VERIFY #############

# Deploy presale token to verify the contract
# ```make deploy-presale-token ARGS="--network amoy"
deploy-presale-token:
	@forge script script/DeployHydrapadPresaleToken.s.sol:DeployHydrapadPresaleToken $(NETWORK_ARGS) --via-ir