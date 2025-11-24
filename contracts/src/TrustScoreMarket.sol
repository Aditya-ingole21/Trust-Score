// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { TrustScoreOracle } from "./TrustScoreOracle.sol";
import "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";



/// @notice TrustScoreMarket — accepts collateral (WETH / cbBTC) and mints/returns USDC (requires USDC liquidity seeded).
/// - Uses TrustScoreOracle for on-chain score verification
/// - Uses Chainlink price feeds to convert collateral -> USD value (owner config)
contract TrustScoreMarket is Ownable(msg.sender), ReentrancyGuard {
    using SafeERC20 for IERC20;

    TrustScoreOracle public oracle;

    // Addresses for tokens (set by owner)
    address public USDC;
    address public WETH;
    address public cbBTC;

    // Chainlink aggregator addresses mapped by token
    mapping(address => address) public priceFeed; // token => aggregator
    mapping(address => uint8) public tokenDecimals;
    mapping(address => AggregatorV3Interface) public priceFeeds;
 // token => decimals (ERC20 decimals)
 function setPriceFeed(address token, address feed) external onlyOwner {
    priceFeeds[token] = AggregatorV3Interface(feed);
}

function setTokenDecimals(address token, uint8 decimals_) external onlyOwner {
    tokenDecimals[token] = decimals_;
}
function getPrice(address token) public view returns (uint256) {
    AggregatorV3Interface feed = priceFeeds[token];
    require(address(feed) != address(0), "No price feed");

    (, int256 price,,,) = feed.latestRoundData();
    require(price > 0, "Invalid price");

    return uint256(price); // already 8 decimals
}


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

    constructor(address _oracle, address _usdc, address _weth, address _cbbtc) {
        oracle = TrustScoreOracle(_oracle);

        // EXACT LAUNCH TABLE
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
    function setPriceFeed(address token, address aggregator, uint8 aggregatorDecimals) external onlyOwner {
        priceFeed[token] = aggregator;
        tokenDecimals[token] = tokenDecimals[token] == 0 ? 18 : tokenDecimals[token]; // keep existing or default
        emit PriceFeedSet(token, aggregator, aggregatorDecimals);
    }

    /* ========== VIEW HELPERS ========== */

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
    /// @param aggregatorDecimals decimals of the price feed (e.g. 8)
    function getCollateralUsdValueInUSDC(address token, uint256 amount, uint8 aggregatorDecimals) public view returns (uint256 usdInUSDC6) {
        address agg = priceFeed[token];
        require(agg != address(0), "missing price feed");

        // Call aggregator.latestRoundData()
        (bool ok, bytes memory out) = agg.staticcall(abi.encodeWithSignature("latestRoundData()"));
        require(ok && out.length >= 32, "bad agg call");

        // decode: (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
        (, int256 answer, , , ) = abi.decode(out, (uint80, int256, uint256, uint256, uint80));
        require(answer > 0, "invalid price");

        uint256 price = uint256(answer); // price with aggregatorDecimals

        uint8 tDecimals = tokenDecimals[token];
        if (tDecimals == 0) {
            tDecimals = 18; // default
        }

        // collateralUsdUSDC6 = amount * price * 1e6 / (10**aggregatorDecimals) / (10**tDecimals)
        uint256 numerator = amount * price * 1e6;
        uint256 denom = (10 ** uint256(aggregatorDecimals)) * (10 ** uint256(tDecimals));
        usdInUSDC6 = numerator / denom;
    }

    /* ========== CORE: verify + accept collateral + pay USDC ========== */

    /// @notice verify signature, accept collateral, transfer USDC to borrower (requires USDC liquidity in contract)
    /// @param user target user (score must be issued for this address)
    /// @param collateralToken token used as collateral (WETH or cbBTC)
    /// @param collateralAmount raw token units (must be approved)
    /// @param borrowAmountUsd amount of USDC to borrow (USDC units = 6 decimals)
    /// @param signature signature verifying score (used via oracle.verifyScore)
    /// @param aggregatorDecimals decimals for the price feed being used
    function verifyAndBorrow(
        address user,
        address collateralToken,
        uint256 collateralAmount,
        uint256 borrowAmountUsd,
        bytes memory signature,
        uint8 aggregatorDecimals
    ) external nonReentrant returns (bool) {

        // 1. Verify backend signature -> sets lastScore for user inside oracle
        oracle.verifyScore(user, oracle.lastScore(user), signature);

        // 2. get score & LTV
        uint256 score = oracle.lastScore(user);
        require(score > 0, "No score found");

        uint256 maxLtv = getMaxLTV(score); // percent

        // 3. compute required collateral in USD (USDC 6 decimals)
        uint256 requiredCollateralUsd = (borrowAmountUsd * 100 + (maxLtv - 1)) / maxLtv; // ceil-ish

        // 4. compute actual collateral USD value
        uint256 collateralUsdValue = getCollateralUsdValueInUSDC(collateralToken, collateralAmount, aggregatorDecimals);

        require(collateralUsdValue >= requiredCollateralUsd, "Not enough collateral USD value");

        // 5. take collateral from caller
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

        // 6. store/update position (simple overwrite model)
        positions[user] = Position({
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            borrowUsd: borrowAmountUsd
        });

        // 7. transfer USDC to borrower (requires contract to hold enough USDC)
        IERC20(USDC).safeTransfer(msg.sender, borrowAmountUsd);

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
