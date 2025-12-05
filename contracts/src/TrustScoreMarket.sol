// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { TrustScoreOracle } from "./TrustScoreOracle.sol";
import "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract TrustScoreMarket is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    TrustScoreOracle public oracle;

    // Addresses for tokens (set by owner)
    address public USDC;
    address public WETH;
    address public cbBTC;

    // Chainlink aggregator addresses mapped by token
    mapping(address => address) public priceFeed; // token => aggregator address
    mapping(address => AggregatorV3Interface) public priceFeeds; // token => AggregatorV3Interface
    mapping(address => uint8) public aggregatorDecimals; // token => aggregator decimals
    mapping(address => uint8) public tokenDecimals; // token => token decimals (ERC20 decimals)

    // LTV rules
    struct LTVBracket {
        uint256 minScore;
        uint256 maxScore;
        uint256 maxLTV; // percent, e.g. 95 => 95%
    }
    LTVBracket[] public brackets;

    // Simple position tracking per user (single position per user for simplicity)
    struct Position {
        address collateralToken;
        uint256 collateralAmount; // raw token units
        uint256 borrowUsd; // USDC units (6 decimals)
    }
    mapping(address => Position) public positions;

    event BorrowExecuted(address indexed user, address collateralToken, uint256 collateralAmount, uint256 borrowUsd);
    event CollateralWithdrawn(address indexed user, address collateralToken, uint256 collateralAmount);
    event AssetsConfigured(address usdc, address weth, address cbbtc);
    event PriceFeedSet(address token, address aggregator, uint8 decimals);
    event LiquidationExecuted(address indexed user, address indexed liquidator, uint256 repayUsd, uint256 collateralSeized);

    constructor(address _oracle, address _usdc, address _weth, address _cbbtc) Ownable(msg.sender) {
        oracle = TrustScoreOracle(_oracle);

        // EXACT LAUNCH TABLE (minScore, maxScore, maxLTV)
        brackets.push(LTVBracket(95, 100, 97));
        brackets.push(LTVBracket(90, 94, 95));
        brackets.push(LTVBracket(85, 89, 90));
        brackets.push(LTVBracket(80, 84, 85));
        brackets.push(LTVBracket(75, 79, 80));
        brackets.push(LTVBracket(70, 74, 70));
        brackets.push(LTVBracket(0, 69, 50));

        // set assets
        USDC = _usdc;
        WETH = _weth;
        cbBTC = _cbbtc;
    }

    /* ========== OWNER CONFIG ========== */

    function setOracle(address _oracle) external onlyOwner {
        oracle = TrustScoreOracle(_oracle);
    }

    function setAssets(address _usdc, address _weth, address _cbbtc) external onlyOwner {
        USDC = _usdc;
        WETH = _weth;
        cbBTC = _cbbtc;
        emit AssetsConfigured(_usdc, _weth, _cbbtc);
    }

    /// @notice Set Chainlink price feed for a token (aggregator that returns price with aggregatorDecimals)
    function setPriceFeed(address token, address aggregator, uint8 _aggregatorDecimals) external onlyOwner {
        require(token != address(0), "token zero");
        require(aggregator != address(0), "aggregator zero");

        priceFeed[token] = aggregator;
        priceFeeds[token] = AggregatorV3Interface(aggregator);
        aggregatorDecimals[token] = _aggregatorDecimals;

        // keep tokenDecimals existing or default to 18 (owner can explicitly set via setTokenDecimals)
        if (tokenDecimals[token] == 0) {
            tokenDecimals[token] = 18;
        }

        emit PriceFeedSet(token, aggregator, _aggregatorDecimals);
    }

    function setTokenDecimals(address token, uint8 decimals_) external onlyOwner {
        require(token != address(0), "token zero");
        tokenDecimals[token] = decimals_;
    }

    /* ========== VIEW HELPERS ========== */

    function getPrice(address token) public view returns (uint256) {
        AggregatorV3Interface feed = priceFeeds[token];
        require(address(feed) != address(0), "No price feed");
        (, int256 price,,,) = feed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    }

    function getMaxLTV(uint256 score) public view returns (uint256) {
        for (uint256 i = 0; i < brackets.length; i++) {
            if (score >= brackets[i].minScore && score <= brackets[i].maxScore) {
                return brackets[i].maxLTV;
            }
        }
        return 50;
    }

    /// @notice Compute collateral USD value (returns USDC units, 6 decimals).
    /// @param token collateral token address
    /// @param amount raw token amount (token decimals as in tokenDecimals[token])
    /// @param _aggregatorDecimals decimals of the price feed (should come from aggregatorDecimals mapping)
    function getCollateralUsdValueInUSDC(address token, uint256 amount, uint8 _aggregatorDecimals) public view returns (uint256 usdInUSDC6) {
        address aggAddr = priceFeed[token];
        require(aggAddr != address(0), "missing price feed");

        AggregatorV3Interface feed = priceFeeds[token];
        require(address(feed) != address(0), "missing feed instance");

        // read latestRoundData() from aggregator
        (, int256 answer, , , ) = feed.latestRoundData();
        require(answer > 0, "invalid price");

        uint256 price = uint256(answer);

        uint8 tDecimals = tokenDecimals[token];
        if (tDecimals == 0) {
            tDecimals = 18;
        }

        uint8 aDecimals = _aggregatorDecimals;
        require(aDecimals > 0, "aggregator decimals not set");

        // collateralUsdUSDC6 = amount * price * 1e6 / (10**aggregatorDecimals) / (10**tDecimals)
        uint256 numerator = amount * price * 1e6;
        uint256 denom = (10 ** uint256(aDecimals)) * (10 ** uint256(tDecimals));
        usdInUSDC6 = numerator / denom;
    }

    /* ========== CORE: verify + accept collateral + pay USDC ========== */

    /**
     * @notice verify signature, accept collateral, transfer USDC to borrower (requires USDC liquidity in contract)
     * @param user target user (score must be issued for this address)
     * @param collateralFrom address that supplies collateral (should be the user in regular UX)
     * @param collateralToken token used as collateral (WETH or cbBTC)
     * @param collateralAmount raw token units (must be approved by collateralFrom)
     * @param borrowAmountUsd amount of USDC to borrow (USDC units = 6 decimals)
     * @param score signed trust score (0-100)
     * @param timestamp timestamp embedded in signature (unix seconds)
     * @param nonce monotonic nonce embedded in signature
     * @param signature signature verifying score (EIP-712)
     */
    function verifyAndBorrow(
        address user,
        address collateralFrom,
        address collateralToken,
        uint256 collateralAmount,
        uint256 borrowAmountUsd,
        uint8 score,
        uint256 timestamp,
        uint256 nonce,
        bytes memory signature
    ) external nonReentrant returns (bool) {

        // 0. Validate collateral token
        require(collateralToken == WETH, "unsupported collateral");


        // 1) Verify backend signature (this updates oracle.lastScore for the user)
        oracle.verifyScore(user, score, timestamp, nonce, signature);

        // 2) get score & LTV
        uint256 maxLtv = getMaxLTV(score); // percent

        // 3) compute required collateral in USD (USDC 6 decimals).
        require(maxLtv > 0, "invalid ltv");
        uint256 requiredCollateralUsd = (borrowAmountUsd * 100 + (maxLtv - 1)) / maxLtv; // ceil-ish

        // 4) compute actual collateral USD value (use stored aggregatorDecimals)
        uint8 aDecimals = aggregatorDecimals[collateralToken];
        require(aDecimals > 0, "aggregator decimals not set");
        uint256 collateralUsdValue = getCollateralUsdValueInUSDC(collateralToken, collateralAmount, aDecimals);

        require(collateralUsdValue >= requiredCollateralUsd, "Not enough collateral USD value");

        // 5) take collateral from collateralFrom
        IERC20(collateralToken).safeTransferFrom(collateralFrom, address(this), collateralAmount);

        // 6) store/update position (simple overwrite model)
        positions[user] = Position({
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            borrowUsd: borrowAmountUsd
        });

        // 7) transfer USDC to user (requires contract to hold enough USDC)
        IERC20(USDC).safeTransfer(user, borrowAmountUsd);

        emit BorrowExecuted(user, collateralToken, collateralAmount, borrowAmountUsd);
        return true;
    }

    /* ========== REPAY / WITHDRAW ========== */

    /// @notice repay borrowed USDC and allow collateral withdrawal if fully repaid
    /// @param user borrower address (msg.sender can also be allowed in production)
    /// @param repayAmountUsd USDC amount to repay (6 decimals)
    function repayAndWithdraw(address user, uint256 repayAmountUsd) external nonReentrant returns (bool) {
        Position memory pos = positions[user];
        require(pos.borrowUsd > 0, "no position");

        // transfer USDC from caller to contract
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), repayAmountUsd);

        // reduce borrowed amount (simple model)
        if (repayAmountUsd >= pos.borrowUsd) {
            // fully repaid -> return collateral to user
            IERC20(pos.collateralToken).safeTransfer(user, pos.collateralAmount);
            delete positions[user];
            emit CollateralWithdrawn(user, pos.collateralToken, pos.collateralAmount);
        } else {
            // partially repaid -> reduce outstanding
            positions[user].borrowUsd = pos.borrowUsd - repayAmountUsd;
        }

        return true;
    }

    /* ========== LIQUIDATION ========== */

    /**
     * @notice Minimal liquidation: anyone can call to repay a portion of debt and seize collateral at a bonus
     * @param user borrower to liquidate
     * @param repayUsd amount of USDC to pay (6 decimals), must be <= borrowUsd
     */
    function liquidate(address user, uint256 repayUsd) external nonReentrant {
    Position memory pos = positions[user];
    require(pos.borrowUsd > 0, "no position");
    require(repayUsd > 0 && repayUsd <= pos.borrowUsd, "invalid repay amount");

    uint8 aDecimals = aggregatorDecimals[pos.collateralToken];
    require(aDecimals > 0, "aggregator decimals not set");

    uint256 collateralUsd = getCollateralUsdValueInUSDC(
        pos.collateralToken,
        pos.collateralAmount,
        aDecimals
    );

    uint8 score = oracle.getScore(user);
    uint256 maxLtv = getMaxLTV(score);
    uint256 requiredCollateralUsd =
        (pos.borrowUsd * 100 + (maxLtv - 1)) / maxLtv;

    require(collateralUsd < requiredCollateralUsd, "position healthy");

    IERC20(USDC).safeTransferFrom(msg.sender, address(this), repayUsd);

    uint256 bonusBP = 500; // 5% liquidation bonus
    uint256 seizeUsd = (repayUsd * (10000 + bonusBP)) / 10000;

    uint256 collateralToSeize =
        (pos.collateralAmount * seizeUsd) / collateralUsd;

    // ----------- SAFETY FIX -----------
    if (collateralToSeize > pos.collateralAmount) {
        collateralToSeize = pos.collateralAmount;
    }
    // ----------------------------------

    // update debt
    if (repayUsd >= pos.borrowUsd) {
        positions[user].borrowUsd = 0;
    } else {
        positions[user].borrowUsd = pos.borrowUsd - repayUsd;
    }

    // update collateral
    positions[user].collateralAmount =
        pos.collateralAmount - collateralToSeize;

    // fully remove position if empty
    if (
        positions[user].borrowUsd == 0 ||
        positions[user].collateralAmount == 0
    ) {
        delete positions[user];
    }

    IERC20(pos.collateralToken).safeTransfer(
        msg.sender,
        collateralToSeize
    );

    emit LiquidationExecuted(
        user,
        msg.sender,
        repayUsd,
        collateralToSeize
    );
}


    /* ========== ADMIN UTILITIES ========== */

    /// @notice owner can withdraw tokens (useful to seed / drain USDC liquidity)
    function adminWithdraw(address token, uint256 amount, address to) external onlyOwner nonReentrant {
        IERC20(token).safeTransfer(to, amount);
    }

    /// @notice view position
    function getPosition(address user) external view returns (Position memory) {
        return positions[user];
    }
}
