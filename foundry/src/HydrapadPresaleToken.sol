// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

/**
 * @title Hydrapad Presale Token
 * @author Hydrapad
 * @notice An ERC20 token contract that enables users to buy and sell tokens with native currency.
 * The price is determined by a constant product curve x * y = k.
 */
contract HydrapadPresaleToken is IERC20, ERC20Burnable, ReentrancyGuard {

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    struct ConstructorParams {
        string name;
        string symbol;
        address tokenCreator;
        uint256 totalSupply;
        uint256 remainingTokens;
        uint256 accumulatedPOL;
        uint256 feeBPS;
        uint256 uniFeeBPS;
        uint256 migrationFee;
        uint256 poolCreationFee;
        uint256 marketCapMin;
        uint256 marketCapMax;
        uint256 tokensNeededToMigrate;
        address feeCollector;
        address uniFeeCollector;
        address uniV2Router;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private s_remainingTokens;  // tokens held by this contract
    uint256 private s_accumulatedPOL;  // POL held by this contract
    bool private s_presaleEnded;
    bool private s_notMigrated = true;
    
    uint256 private immutable i_totalSupply;
    uint256 private immutable i_accumulatedPOLInitial;
    uint256 private immutable i_marketCapMin;
    uint256 private immutable i_marketCapMax;
    uint256 private immutable i_tokensNeededToMigrate;
    address private immutable i_tokenCreator;
    uint256 private immutable i_poolCreationFee;
    uint256 private immutable i_migrationFee;
    uint256 private immutable i_feeBPS;  // protocol fee
    uint256 private immutable i_uniFeeBPS;  // fee dedicated to uniswap incentives
    address private immutable i_feeCollector;
    address private immutable i_uniFeeCollector;
    address private immutable i_presaleFactory;
    address private immutable i_WETH;
    address private immutable i_pair;
    IUniswapV2Router02 private immutable i_uniV2Router;

    uint256 private constant MAX_BPS = 10_000;  // 100%

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error PresaleEnded();
    error OnlyPresaleFactory();
    error InsufficientTokenAccumulated();
    error SlippageCheckFailed();
    error NotEnoughtPOLToBuyTokens();
    error NotEnoughPOLAccumulated();
    error TokenHasNotMigratedYet(address token);
    error POLTransferFailed();
    error MarketCapMaxExceeded();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier presaleNotEnded() {
        if (s_presaleEnded) revert PresaleEnded();
        _;
    }

    /**
     * @dev Checks if the presale has ended and needs to migrate
     * @dev Checks that the market cap is less than the max market cap after buying tokens
     */
    modifier marketCapChecks() {
        _;
        if (getMarketCap() > i_marketCapMin) s_presaleEnded = true;
        if (getMarketCap() > i_marketCapMax) revert MarketCapMaxExceeded();
    }

    /**
     * @dev Checks that the msg.sender is the presale factory
     */
    modifier onlyPresaleFactory() {
        if (msg.sender != i_presaleFactory) revert OnlyPresaleFactory();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(ConstructorParams memory params) ERC20(params.name, params.symbol) {
        i_totalSupply = params.totalSupply;
        s_remainingTokens = params.remainingTokens;
        s_accumulatedPOL = params.accumulatedPOL;
        i_accumulatedPOLInitial = params.accumulatedPOL;
        i_marketCapMin = params.marketCapMin;
        i_marketCapMax = params.marketCapMax;
        i_tokensNeededToMigrate = params.tokensNeededToMigrate;
        i_tokenCreator = params.tokenCreator;
        i_poolCreationFee = params.poolCreationFee;
        i_migrationFee = params.migrationFee;
        i_feeBPS = params.feeBPS;
        i_uniFeeBPS = params.uniFeeBPS;
        i_feeCollector = params.feeCollector;
        i_uniFeeCollector = params.uniFeeCollector;
        i_uniV2Router = IUniswapV2Router02(params.uniV2Router);
        i_presaleFactory = msg.sender;
        i_WETH = i_uniV2Router.WETH();

        // Sort tokens
        (address token0, address token1) = 
            address(this) < i_WETH ? (address(this), i_WETH) : (i_WETH, address(this));

        // calculates the CREATE2 address for a pair without making any external calls
        // https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
        i_pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(i_uniV2Router.factory()),
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"
                        )
                    )
                )
            )
        );
        _mint(address(this), params.totalSupply);
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Buys given amount of tokens using POL
     * @notice Has slippage control
     * @notice Refunds extra POL
     *
     * @param tokenAmount - amount of tokens to buy
     * @param maxPOLAmount - maximum amount of POL a caller is willing to spend
     * 
     * @return POLToPayWithFee - Total POL cost of the tokens
     * @return feeCollectorFee - Protocol Fee
     * @return uniFee - Fee for Uniswap incentives
     */
    function buyGivenOut(
        uint256 tokenAmount,
        uint256 maxPOLAmount
    )
        external
        payable
        onlyPresaleFactory
        marketCapChecks
        presaleNotEnded
        returns (uint256 POLToPayWithFee, uint256 feeCollectorFee, uint256 uniFee)
    {
        if (balanceOf(address(this)) <= tokenAmount) revert InsufficientTokenAccumulated();
        uint256 POLToSpend = (tokenAmount * s_accumulatedPOL) / (s_remainingTokens - tokenAmount);
        (feeCollectorFee, uniFee) = _calculateFee(POLToSpend);
        POLToPayWithFee = POLToSpend + feeCollectorFee + uniFee;
        if (POLToPayWithFee > maxPOLAmount) revert SlippageCheckFailed();

        _transferPOL(i_feeCollector, feeCollectorFee);
        _transferPOL(i_uniFeeCollector, uniFee);
        s_remainingTokens -= tokenAmount;
        s_accumulatedPOL += POLToSpend;

        uint256 refund;
        if (msg.value > POLToPayWithFee) {
            refund = msg.value - POLToPayWithFee;
            _transferPOL(msg.sender, refund);
        } else if (msg.value < POLToPayWithFee) {
            revert NotEnoughtPOLToBuyTokens();
        }
        _transfer(address(this), msg.sender, tokenAmount);
    }

    /**
     * @dev Buys tokens specifing minimal amount of tokens a caller gets
     *
     * @param amountOutMin - minimal amount of tokens a caller will get
     */
    function buyGivenIn(
        uint256 amountOutMin
    )
        external
        payable
        onlyPresaleFactory
        marketCapChecks
        presaleNotEnded
        returns (uint256 POLToPayWithFee, uint256 feeCollectorFee, uint256 uniFee)
    {
        if (balanceOf(address(this)) <= amountOutMin) revert InsufficientTokenAccumulated();
        POLToPayWithFee = msg.value;
        (feeCollectorFee, uniFee) = _calculateFee(POLToPayWithFee);
        uint256 POLToSpendMinusFee = POLToPayWithFee - feeCollectorFee - uniFee;

        _transferPOL(i_feeCollector, feeCollectorFee);
        _transferPOL(i_uniFeeCollector, uniFee);
        uint256 tokensOut = (POLToSpendMinusFee * s_remainingTokens) /
            (s_accumulatedPOL + POLToSpendMinusFee);
        if (tokensOut < amountOutMin) revert SlippageCheckFailed();

        s_remainingTokens -= tokensOut;
        s_accumulatedPOL += POLToSpendMinusFee;
        _transfer(address(this), msg.sender, tokensOut);
    }

    /**
     * @dev Sells given amount of tokens for POL
     *
     * @param tokenAmount - amount of tokens a caller wants to sell
     * @param amountPOLMin - minimum amount of POL a seller will get
     */
    function sellGivenIn(
        uint256 tokenAmount,
        uint256 amountPOLMin
    )
        external
        payable
        onlyPresaleFactory
        presaleNotEnded
        returns (uint256 POLToReceiveMinusFee, uint256 feeCollectorFee, uint256 uniFee)
    {
        uint256 POLlToReceive = (tokenAmount * s_accumulatedPOL) /
            (s_remainingTokens + tokenAmount);
        (feeCollectorFee, uniFee) = _calculateFee(POLlToReceive);
        POLToReceiveMinusFee = POLlToReceive - feeCollectorFee - uniFee;
        _transferPOL(i_feeCollector, feeCollectorFee);
        _transferPOL(i_uniFeeCollector, uniFee);
        if (POLToReceiveMinusFee < amountPOLMin) revert SlippageCheckFailed();

        s_remainingTokens += tokenAmount;
        s_accumulatedPOL -= POLlToReceive;
        _transferPOL(msg.sender, POLToReceiveMinusFee);
        _transfer(msg.sender, address(this), tokenAmount);
    }

    /**
     * @dev Sells given amount of tokens for POL
     *
     * @param tokenAmountMax - max amount of tokens a caller wants to sell
     */
    function sellGivenOut(
        uint256 tokenAmountMax,
        uint256 amountPOL
    )
        external
        payable
        onlyPresaleFactory
        presaleNotEnded
        returns (uint256 POLToReceiveMinusFee, uint256 tokensOut, uint256 feeCollectorFee, uint256 uniFee)
    {
        (feeCollectorFee, uniFee) = _calculateFee(amountPOL);
        POLToReceiveMinusFee = amountPOL - feeCollectorFee - uniFee;
        _transferPOL(i_feeCollector, feeCollectorFee);
        _transferPOL(i_uniFeeCollector, uniFee);
        tokensOut = (amountPOL * s_remainingTokens) / (s_accumulatedPOL - amountPOL);
        if (tokensOut > tokenAmountMax) revert SlippageCheckFailed();

        _transfer(msg.sender, address(this), tokensOut);
        s_remainingTokens += tokensOut;
        s_accumulatedPOL -= amountPOL;
        _transferPOL(msg.sender, POLToReceiveMinusFee);
    }

    /**
     * @dev Calculates amountOut given amountIn
     * @dev Calculates dy = y * dx / x + dx
     *
     * @param amountIn - amount in which will be transfered to the contract
     * @param remainingIn - remaining in
     * @param remainingOut - remaining out
     * @param InIsPOL - if the in token is POL
     */
    function getAmountOutAndFee(
        uint256 amountIn,
        uint256 remainingIn,
        uint256 remainingOut,
        bool InIsPOL
    ) external view returns (uint256 amountOut, uint256 fee) {
        if (InIsPOL) {
            (uint256 feeCollectorFee, uint256 uniFee) = _calculateFee(amountIn);
            fee = feeCollectorFee + uniFee;

            amountOut = (remainingOut * amountIn) / (remainingIn + amountIn);
        } else {
            amountOut = (remainingOut * amountIn) / (remainingIn + amountIn);

            (uint256 feeCollectorFee, uint256 uniFee) = _calculateFee(amountOut);
            fee = feeCollectorFee + uniFee;
        }
    }

    /**
     * @dev Calculates amountIn given amountOut
     * @dev Calculates dx = x * dy / y + dy
     *
     * @param amountOut - amount out which will be sent to the user
     * @param remainingIn - remaining in
     * @param remainingOut - remaining out
     * @param outIsPol - if token out is POL
     */
    function getAmountInAndFee(
        uint256 amountOut,
        uint256 remainingIn,
        uint256 remainingOut,
        bool outIsPol
    ) external view returns (uint256 amountIn, uint256 fee) {
        if (outIsPol) {
            (uint256 feeCollectorFee, uint256 uniFee) = _calculateFee(amountOut);
            fee = feeCollectorFee + uniFee;

            amountIn = (remainingIn * amountOut) / (remainingOut - amountOut);
        } else {
            amountIn = (remainingIn * amountOut) / (remainingOut - amountOut);

            (uint256 feeCollectorFee, uint256 uniFee) = _calculateFee(amountIn);
            fee = feeCollectorFee + uniFee;
        }
    }

    /**
     * @dev Migrates tokens and POL to Uniswap V2 and burns LP tokens
     * 
     * @return tokensToMigrate - The tokens to migrate
     * @return tokensToBurn - The tokens to burn before migration
     * @return POLAmount - The POL amount to migrate
     */
    function migrate()
        external
        onlyPresaleFactory
        returns (uint256 tokensToMigrate, uint256 tokensToBurn, uint256 POLAmount)
    {
        s_notMigrated = false;
        if (IUniswapV2Factory(i_uniV2Router.factory()).getPair(address(this), i_WETH) == address(0))
            IUniswapV2Factory(i_uniV2Router.factory()).createPair(address(this), i_WETH);

        uint256 tokensRemaining = balanceOf(address(this));
        this.approve(address(i_uniV2Router), tokensRemaining);
        tokensToMigrate = _tokensToMigrate();
        tokensToBurn = tokensRemaining - tokensToMigrate;
        (uint256 feeCollectorFee, uint256 uniFee) = _splitFee(i_migrationFee);
        _transferPOL(i_feeCollector, feeCollectorFee + i_poolCreationFee);
        _transferPOL(i_uniFeeCollector, uniFee);
        _burn(address(this), tokensToBurn);

        POLAmount = s_accumulatedPOL - i_accumulatedPOLInitial - i_poolCreationFee - feeCollectorFee - uniFee;
        (,,uint256 liquidity) = i_uniV2Router.addLiquidityETH{value: POLAmount}(
            address(this),
            tokensToMigrate,
            tokensToMigrate,
            POLAmount,
            address(this),
            block.timestamp + 60
        );
        if (address(this).balance > 0)
            _transferPOL(i_feeCollector, address(this).balance);
        IERC20(i_pair).transfer(address(0), liquidity);
    }

    /**
     * @dev Returns the progress in BPS - from 100 to MAX_BPS (1% to 100%)
     */
    function getProgressBPS() external view returns (uint256) {
        uint256 progress = ((i_totalSupply - balanceOf(address(this))) * MAX_BPS) / i_tokensNeededToMigrate;
        if (progress < 100) return 100;
        if (progress > MAX_BPS) return MAX_BPS;
        return progress;
    }

    /*//////////////////////////////////////////////////////////////
                           PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // The market cap is calculated as the average price of a token times the total supply of the tokens
    function getMarketCap() public view returns (uint256) {
        return ((s_accumulatedPOL * totalSupply() * 1e18) / s_remainingTokens) / 1e18;
    }

    // transfer tokens
    function transfer(address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        if (to == i_pair && s_notMigrated) revert TokenHasNotMigratedYet(i_pair);
        return super.transfer(to, amount);
    }

    // transfer tokens from someone
    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        if (to == i_pair && s_notMigrated) revert TokenHasNotMigratedYet(i_pair);
        return super.transferFrom(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _tokensToMigrate() private view returns (uint256) {
        uint256 POLDeductedFee = address(this).balance - i_migrationFee - i_poolCreationFee;
        return (s_remainingTokens * POLDeductedFee) / s_accumulatedPOL;
    }

    function _calculateFee(uint256 amount) private view returns (uint256 feeCollectorFee, uint256 uniFee) {
        feeCollectorFee = (amount * i_feeBPS) / MAX_BPS;
        uniFee = (feeCollectorFee * i_uniFeeBPS) / MAX_BPS;
        feeCollectorFee -= uniFee;
    }

    function _splitFee(uint256 feeAmount) private view returns (uint256 feeCollectorFee, uint256 uniFee) {
        uniFee = (feeAmount * i_uniFeeBPS) / MAX_BPS;
        feeCollectorFee = feeAmount - uniFee;
    }

    function _transferPOL(address _to, uint256 amount) private {
        (bool success, ) = _to.call{value: amount}("");
        if (!success) revert POLTransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                           GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRemainingTokens() external view returns (uint256) {
        return s_remainingTokens;
    }

    function getAccumulatedPOL() external view returns (uint256) {
        return s_accumulatedPOL;
    }

    function getPresaleEnded() external view returns (bool) {
        return s_presaleEnded;
    }

    function getNotMigrated() external view returns (bool) {
        return s_notMigrated;
    }

    function getTotalSupply() external view returns (uint256) {
        return i_totalSupply;
    }

    function getAccumulatedPOLInitial() external view returns (uint256) {
        return i_accumulatedPOLInitial;
    }

    function getMarketCapMin() external view returns (uint256) {
        return i_marketCapMin;
    }

    function getMarketCapMax() external view returns (uint256) {
        return i_marketCapMax;
    }

    function getTokensNeededToMigrate() external view returns (uint256) {
        return i_tokensNeededToMigrate;
    }

    function getTokenCreator() external view returns (address) {
        return i_tokenCreator;
    }

    function getPoolCreationFee() external view returns (uint256) {
        return i_poolCreationFee;
    }

    function getMigrationFee() external view returns (uint256) {
        return i_migrationFee;
    }

    function getFeeBPS() external view returns (uint256) {
        return i_feeBPS;
    }

    function getUniFeeBPS() external view returns (uint256) {
        return i_uniFeeBPS;
    }

    function getFeeCollector() external view returns (address) {
        return i_feeCollector;
    }

    function getUniFeeCollector() external view returns (address) {
        return i_uniFeeCollector;
    }

    function getPresaleFactory() external view returns (address) {
        return i_presaleFactory;
    }

    function getWETH() external view returns (address) {
        return i_WETH;
    }

    function getPair() external view returns (address) {
        return i_pair;
    }

    function getUniswapV2Router() external view returns (IUniswapV2Router02) {
        return i_uniV2Router;
    }

    function getMaxBPS() external pure returns (uint256) {
        return MAX_BPS;
    }
}