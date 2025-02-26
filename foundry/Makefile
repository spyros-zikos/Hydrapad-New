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
	NETWORK_ARGS := --rpc-url $(BASE_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(BASESCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network polygon,$(ARGS)),--network polygon)
	NETWORK_ARGS := --rpc-url $(POLYGON_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(POLYGONSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network amoy,$(ARGS)),--network amoy)
	NETWORK_ARGS := --rpc-url $(POLYGON_AMOY_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(POLYGONSCAN_API_KEY) -vvvv
endif

# To deploy run: make deploy-presale ARGS="--network base"
# To deploy run: make deploy-presale ARGS="--network polygon"
# To deploy run: make deploy-presale ARGS="--network amoy"
deploy-presale:
	@forge script script/DeployHydrapadPresaleFactory.s.sol:DeployHydrapadPresaleFactory $(NETWORK_ARGS) --via-ir
deploy-simple:
	@forge script script/DeployHydrapadSimpleFactory.s.sol:DeployHydrapadSimpleFactory $(NETWORK_ARGS) --via-ir