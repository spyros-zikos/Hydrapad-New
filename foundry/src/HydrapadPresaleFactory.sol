// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {HydrapadPresaleToken} from "./HydrapadPresaleToken.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title Hydrapad Presale Factory
 * @author Hydrapad
 * @notice This contract creates Hydrapad tokens and enables users to buy and sell them with native currency.
 * @notice After the tokens reach a ceartain market cap, they can migrate to Uniswap V2.
 */
contract HydrapadPresaleFactory is Ownable, ReentrancyGuard {

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private s_totalSupply;
    uint256 private s_remainingTokens;
    uint256 private s_accumulatedPOL;
    uint256 private s_marketCapMin;
    uint256 private s_marketCapMax;
    uint256 private s_tokensNeededToMigrate;
    uint256 private s_poolCreationFee;
    uint256 private s_migrationFee;
    uint256 private s_feeBPS;
    uint256 private s_uniFeeBPS;
    address private s_feeCollector;
    address private s_uniFeeCollector;
    address private s_signer;
    mapping(bytes32 => bool) private s_usedSignatures;
    mapping(address => bool) private s_canMigrate;
    address[] private s_HydrapadPresaleTokens;

    address private immutable i_uniswapV2Router;

    uint256 private constant MAX_FEE_BPS = 2_500;
    uint256 private constant MAX_UNI_FEE_BPS = 10_000;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event SetParameters(
        uint256 totalSupply,
        uint256 remainingTokens,
        uint256 accumulatedPOL,
        uint256 marketCapMin,
        uint256 marketCapMax,
        uint256 tokensNeededToMigrate,
        uint256 poolCreationFee,
        uint256 migrationFee,
        uint256 feeBPS,
        uint256 uniFeeBPS,
        address feeCollector,
        address uniFeeCollector,
        address signer
    );

    event CreateHydrapadPresaleToken(
        address indexed tokenAddress,
        address indexed creator,
        bytes indexed signature
    );

    event CreateHydrapadPresaleTokenAndBuy(
        address indexed tokenAddress,
        address indexed creator,
        bytes indexed signature,
        uint256 tokenAmount,
        uint256 POLAmount,
        uint256 fee,
        uint256 uniFee,
        uint256 progress
    );

    event CanMigrate(address indexed token);

    event Migrated(
        address indexed token,
        address indexed pair,
        uint256 tokensToMigrate,
        uint256 tokensToBurn,
        uint256 POLToMigrate,
        uint256 migrationFee
    );

    event BuyGivenOut(
        address indexed buyer,
        address indexed token,
        uint256 indexed tokenAmount,
        uint256 tokensOutstanding,
        uint256 POLAmount,
        uint256 refund,
        uint256 fee,
        uint256 uniFee,
        uint256 progress
    );

    event BuyGivenIn(
        address indexed buyer,
        address indexed token,
        uint256 indexed tokenAmount,
        uint256 tokensOutstanding,
        uint256 POLAmount,
        uint256 fee,
        uint256 uniFee,
        uint256 progress
    );

    event SellGivenIn(
        address indexed seller,
        address indexed token,
        uint256 indexed tokenAmount,
        uint256 tokensOutstanding,
        uint256 POLAmount,
        uint256 fee,
        uint256 uniFee,
        uint256 progress
    );

    event SellGivenOut(
        address indexed seller,
        address indexed token,
        uint256 indexed tokenAmount,
        uint256 tokensOutstanding,
        uint256 POLAmount,
        uint256 fee,
        uint256 uniFee,
        uint256 progress
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidSignature();
    error ReusedSignature();
    error POLTransferFailed();
    error CannotMigrateYet();
    error TotalSupplyIsZero();
    error RemaningTokensIsZero();
    error RemainingPOLIsZero();
    error MarketCapMinIsZero();
    error MarketCapMaxIsZero();
    error TokensNeededToMigrateIsZero();
    error FeeCollectorIsZero();
    error UniFeeCollectorIsZero();
    error SignerIsZero();
    error MarketCapMinGreaterThanMax();
    error FeeBPSCheckFailed();
    error UniFeeBPSCheckFailed();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 totalSupply,
        uint256 remainingTokens,
        uint256 accumulatedPOL,
        uint256 marketCapMin,
        uint256 marketCapMax,
        uint256 tokensNeededToMigrate,
        uint256 poolCreationFee,
        uint256 migrationFee,
        uint256 feeBPS,
        uint256 uniFeeBPS,
        address feeCollector,
        address uniFeeCollector,
        address signer,
        address uniswapV2Router
    ) Ownable(msg.sender) {
        _setParameters(
            totalSupply,
            remainingTokens,
            accumulatedPOL,
            marketCapMin,
            marketCapMax,
            tokensNeededToMigrate,
            poolCreationFee,
            migrationFee,
            feeBPS,
            uniFeeBPS,
            feeCollector,
            uniFeeCollector,
            signer
        );
        i_uniswapV2Router = uniswapV2Router;
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Can receive POL
    receive() external payable {}

    function setParameters(
        uint256 totalSupply,
        uint256 remainingTokens,
        uint256 accumulatedPOL,
        uint256 marketCapMin,
        uint256 marketCapMax,
        uint256 tokensNeededToMigrate,
        uint256 poolCreationFee,
        uint256 migrationFee,
        uint256 feeBPS,
        uint256 uniFeeBPS,
        address feeCollector,
        address uniFeeCollector,
        address signer
    ) external onlyOwner {
        _setParameters(
            totalSupply,
            remainingTokens,
            accumulatedPOL,
            marketCapMin,
            marketCapMax,
            tokensNeededToMigrate,
            poolCreationFee,
            migrationFee,
            feeBPS,
            uniFeeBPS,
            feeCollector,
            uniFeeCollector,
            signer
        );
    }

    /**
     * @notice This function creates a new HydrapadPresaleToken.
     * @notice It checks the signature that should be created by the signer
     * to approve the creation of this token.
     * 
     * @param name Token name
     * @param symbol Token symbol
     * @param nonce Nonce used by signature
     * @param signature The signature that the signer created to approve the creation of this token.
     */
    function createHydrapadPresaleToken(
        string memory name,
        string memory symbol,
        uint256 nonce,
        bytes memory signature
    ) external returns (address) {
        _checkSignatureAndStore(name, symbol, nonce, signature);

        address tokenCreator = msg.sender;
        HydrapadPresaleToken token = new HydrapadPresaleToken(
            HydrapadPresaleToken.ConstructorParams(
                name,
                symbol,
                tokenCreator,
                s_totalSupply,
                s_remainingTokens,
                s_accumulatedPOL,
                s_feeBPS,
                s_uniFeeBPS,
                s_migrationFee,
                s_poolCreationFee,
                s_marketCapMin,
                s_marketCapMax,
                s_tokensNeededToMigrate,
                s_feeCollector,
                s_uniFeeCollector,
                i_uniswapV2Router
            )
        );
        s_HydrapadPresaleTokens.push(address(token));
        emit CreateHydrapadPresaleToken(address(token), msg.sender, signature);
        return address(token);
    }

    /**
     * @notice This function creates a new HydrapadPresaleToken.
     * @notice It checks the signature that should be created by the signer
     * to approve the creation of this token.
     * @notice It allows the token creator (msg.sender) to buy tokens.
     * 
     * @param name Token name
     * @param symbol Token symbol
     * @param nonce Nonce used by signature
     * @param tokenAmountMin The minimum amount of tokens the user is willing to receive
     * @param signature The signature that the signer created to approve the creation of this token.
     */
    function createHydrapadPresaleTokenAndBuy(
        string memory name,
        string memory symbol,
        uint256 nonce,
        uint256 tokenAmountMin,
        bytes memory signature
    ) external payable nonReentrant returns (address) {
        _checkSignatureAndStore(name, symbol, nonce, signature);

        address tokenCreator = msg.sender;
        HydrapadPresaleToken token = new HydrapadPresaleToken(
            HydrapadPresaleToken.ConstructorParams(
                name,
                symbol,
                tokenCreator,
                s_totalSupply,
                s_remainingTokens,
                s_accumulatedPOL,
                s_feeBPS,
                s_uniFeeBPS,
                s_migrationFee,
                s_poolCreationFee,
                s_marketCapMin,
                s_marketCapMax,
                s_tokensNeededToMigrate,
                s_feeCollector,
                s_uniFeeCollector,
                i_uniswapV2Router
            )
        );

        (uint256 POLToPayWithFee, uint256 feeCollectorFee, uint256 uniFee) = token.buyGivenIn{value: msg.value}(
            tokenAmountMin
        );
        uint256 tokenAmount = token.balanceOf(address(this));
        token.transfer(msg.sender, tokenAmount);

        s_HydrapadPresaleTokens.push(address(token));
        emit CreateHydrapadPresaleTokenAndBuy(
            address(token),
            msg.sender,
            signature,
            tokenAmount,
            POLToPayWithFee,
            feeCollectorFee,
            uniFee,
            token.getProgressBPS()
        );
        return address(token);
    }

    /**
     * @notice This function allows the user to buy a specific amount of tokens
     * 
     * @param token Token address
     * @param tokenAmount Amount of tokens to buy
     * @param maxPOLAmount Max amount of POL the user is willing to spend
     */
    function buyGivenOut(
        address token,
        uint256 tokenAmount,
        uint256 maxPOLAmount
    ) external payable nonReentrant {
        (uint256 POLToPayWithFee, uint256 feeCollectorFee, uint256 uniFee) = HydrapadPresaleToken(token).buyGivenOut{
            value: msg.value
        }(tokenAmount, maxPOLAmount);
        HydrapadPresaleToken(token).transfer(msg.sender, tokenAmount);

        uint256 refund = address(this).balance;
        if (refund > 0) {
            (bool success, ) = msg.sender.call{value: refund}("");
            if (!success) revert POLTransferFailed();
        }

        emit BuyGivenOut(
            msg.sender,
            token,
            tokenAmount,
            HydrapadPresaleToken(token).totalSupply() - HydrapadPresaleToken(token).balanceOf(address(token)),
            POLToPayWithFee,
            refund,
            feeCollectorFee,
            uniFee,
            HydrapadPresaleToken(token).getProgressBPS()
        );

        if (HydrapadPresaleToken(token).getPresaleEnded()) {
            s_canMigrate[token] = true;
            emit CanMigrate(token);
        }
    }

    /**
     * @notice This function allows the user to buy tokens with a specific amount of POL
     * 
     * @param token Token address
     * @param amountOutMin Min amount of tokens the user is willing to receive
     */
    function buyGivenIn(address token, uint256 amountOutMin) external payable nonReentrant {
        (uint256 POLToPayWithFee, uint256 feeCollectorFee, uint256 uniFee) = HydrapadPresaleToken(token).buyGivenIn{
            value: msg.value
        }(amountOutMin);
        uint256 tokensOut = HydrapadPresaleToken(token).balanceOf(address(this));
        HydrapadPresaleToken(token).transfer(msg.sender, tokensOut);

        uint256 refund = address(this).balance;
        if (refund > 0) {
            (bool success, ) = msg.sender.call{value: refund}("");
            if (!success) revert POLTransferFailed();
        }

        emit BuyGivenIn(
            msg.sender,
            token,
            tokensOut,
            HydrapadPresaleToken(token).totalSupply() - HydrapadPresaleToken(token).balanceOf(address(token)),
            POLToPayWithFee,
            feeCollectorFee,
            uniFee,
            HydrapadPresaleToken(token).getProgressBPS()
        );

        if (HydrapadPresaleToken(token).getPresaleEnded()) {
            s_canMigrate[token] = true;
            emit CanMigrate(token);
        }
    }

    /**
     * @notice This function allows the user to sell a specific amount of tokens
     * 
     * @param token Token address
     * @param tokenAmount Amount of tokens to sell
     * @param amountPOLMin Min amount of POL the user is willing to receive
     */
    function sellGivenIn(address token, uint256 tokenAmount, uint256 amountPOLMin) external nonReentrant {
        HydrapadPresaleToken(token).transferFrom(msg.sender, address(this), tokenAmount);
        (uint256 POLToReceiveMinusFee, uint256 feeCollectorFee, uint256 uniFee) = HydrapadPresaleToken(token).sellGivenIn(
            tokenAmount,
            amountPOLMin
        );
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert POLTransferFailed();

        emit SellGivenIn(
            msg.sender,
            token,
            tokenAmount,
            HydrapadPresaleToken(token).totalSupply() - HydrapadPresaleToken(token).balanceOf(address(token)),
            POLToReceiveMinusFee,
            feeCollectorFee,
            uniFee,
            HydrapadPresaleToken(token).getProgressBPS()
        );
    }

    /**
     * @notice This function allows the user to sell tokens which are worth a specific amount of POL
     * 
     * @param token Token address
     * @param tokenAmountMax Max amount of tokens the user is willing to spend
     * @param amountPOL Amount of POL the user wants to receive
     */
    function sellGivenOut(address token, uint256 tokenAmountMax, uint256 amountPOL) external nonReentrant {
        HydrapadPresaleToken(token).transferFrom(msg.sender, address(this), tokenAmountMax);
        (uint256 POLToReceiveMinusFee, uint256 tokensOut, uint256 feeCollectorFee, uint256 uniFee) = HydrapadPresaleToken(
            token
        ).sellGivenOut(tokenAmountMax, amountPOL);
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert POLTransferFailed();

        emit SellGivenOut(
            msg.sender,
            token,
            tokensOut,
            HydrapadPresaleToken(token).totalSupply() - HydrapadPresaleToken(token).balanceOf(address(token)),
            POLToReceiveMinusFee,
            feeCollectorFee,
            uniFee,
            HydrapadPresaleToken(token).getProgressBPS()
        );
    }

    /**
     * @notice Migrates a token to Uniswap V2
     * 
     * @param token Token address
     */
    function migrate(address token) external {
        if (!s_canMigrate[token]) revert CannotMigrateYet();

        (uint256 tokensToMigrate, uint256 tokensToBurn, uint256 POLAmount) = HydrapadPresaleToken(token).migrate();
        emit Migrated(
            token,
            HydrapadPresaleToken(token).getPair(),
            tokensToMigrate,
            tokensToBurn,
            POLAmount,
            HydrapadPresaleToken(token).getMigrationFee() + HydrapadPresaleToken(token).getPoolCreationFee()
        );
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setParameters(
        uint256 totalSupply,
        uint256 remainingTokens,
        uint256 accumulatedPOL,
        uint256 marketCapMin,
        uint256 marketCapMax,
        uint256 tokensNeededToMigrate,
        uint256 poolCreationFee,
        uint256 migrationFee,
        uint256 feeBPS,
        uint256 uniFeeBPS,
        address feeCollector,
        address uniFeeCollector,
        address signer
    ) private {
        if (totalSupply == 0) revert TotalSupplyIsZero();
        if (marketCapMin == 0) revert MarketCapMinIsZero();
        if (marketCapMax == 0) revert MarketCapMaxIsZero();
        if (accumulatedPOL == 0) revert RemainingPOLIsZero();
        if (remainingTokens == 0) revert RemaningTokensIsZero();
        if (signer == address(0)) revert SignerIsZero();
        if (s_feeBPS >= MAX_FEE_BPS) revert FeeBPSCheckFailed();
        if (tokensNeededToMigrate == 0) revert TokensNeededToMigrateIsZero();
        if (feeCollector == address(0)) revert FeeCollectorIsZero();
        if (marketCapMin >= marketCapMax) revert MarketCapMinGreaterThanMax();
        if (uniFeeCollector == address(0)) revert UniFeeCollectorIsZero();
        if (s_uniFeeBPS >= MAX_UNI_FEE_BPS) revert UniFeeBPSCheckFailed();

        s_totalSupply = totalSupply;
        s_remainingTokens = remainingTokens;
        s_accumulatedPOL = accumulatedPOL;
        s_marketCapMin = marketCapMin;
        s_marketCapMax = marketCapMax;
        s_tokensNeededToMigrate = tokensNeededToMigrate;
        s_poolCreationFee = poolCreationFee;
        s_migrationFee = migrationFee;
        s_feeBPS = feeBPS;
        s_uniFeeBPS = uniFeeBPS;
        s_feeCollector = feeCollector;
        s_uniFeeCollector = uniFeeCollector;
        s_signer = signer;

        emit SetParameters(
            s_totalSupply,
            s_remainingTokens,
            s_accumulatedPOL,
            s_marketCapMin,
            s_marketCapMax,
            s_tokensNeededToMigrate,
            s_poolCreationFee,
            s_migrationFee,
            s_feeBPS,
            s_uniFeeBPS,
            s_feeCollector,
            s_uniFeeCollector,
            s_signer
        );
    }

    /**
     * @notice Checks if the signature has been used and if it has reverts.
     * @notice Checks if the signature is valid and reverts if it is not.
     * @notice Stores the signature so that it cannot be reused.
     * 
     * @param name Token name
     * @param symbol Token symbol
     * @param nonce Nonce used for the signature
     * @param signature The signature from the signer
     */
    function _checkSignatureAndStore(
        string memory name,
        string memory symbol,
        uint256 nonce,
        bytes memory signature
    ) private {
        if (s_usedSignatures[keccak256(signature)]) revert ReusedSignature();

        bytes32 message = keccak256(abi.encodePacked(name, symbol, nonce, address(this), block.chainid, msg.sender));

        if (!SignatureChecker.isValidSignatureNow(s_signer, MessageHashUtils.toEthSignedMessageHash(message), signature))
            revert InvalidSignature();

        s_usedSignatures[keccak256(signature)] = true;
    }

    /*//////////////////////////////////////////////////////////////
                           GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getTotalSupply() public view returns (uint256) {
        return s_totalSupply;
    }

    function getRemainingTokens() public view returns (uint256) {
        return s_remainingTokens;
    }

    function getAccumulatedPOL() public view returns (uint256) {
        return s_accumulatedPOL;
    }

    function getMarketCapMin() public view returns (uint256) {
        return s_marketCapMin;
    }

    function getMarketCapMax() public view returns (uint256) {
        return s_marketCapMax;
    }

    function getTokensNeededToMigrate() public view returns (uint256) {
        return s_tokensNeededToMigrate;
    }

    function getPoolCreationFee() public view returns (uint256) {
        return s_poolCreationFee;
    }

    function getMigrationFee() public view returns (uint256) {
        return s_migrationFee;
    }

    function getFeeBPS() public view returns (uint256) {
        return s_feeBPS;
    }

    function getUniFeeBPS() public view returns (uint256) {
        return s_uniFeeBPS;
    }

    function getFeeCollector() public view returns (address) {
        return s_feeCollector;
    }

    function getUniFeeCollector() public view returns (address) {
        return s_uniFeeCollector;
    }

    function getSigner() public view returns (address) {
        return s_signer;
    }

    function getUsedSignatures(bytes32 signature) public view returns (bool) {
        return s_usedSignatures[signature];
    }

    function getCanMigrate(address token) public view returns (bool) {
        return s_canMigrate[token];
    }

    function getHydrapadPresaleTokens() public view returns (address[] memory) {
        return s_HydrapadPresaleTokens;
    }

    function getUniswapV2Router() public view returns (address) {
        return i_uniswapV2Router;
    }

    function getMaxFeeBPS() public pure returns (uint256) {
        return MAX_FEE_BPS;
    }

    function getMaxUniFeeBPS() public pure returns (uint256) {
        return MAX_UNI_FEE_BPS;
    }
}