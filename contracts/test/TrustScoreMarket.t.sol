// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TrustScoreOracle.sol";
import "../src/TrustScoreMarket.sol";
import "../src/BorrowLens.sol";
import "../src/TestUSDC.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Minimal ERC20 for collateral simulation
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Minimal Chainlink mock aggregator
contract MockV3Aggregator {
    int256 public answer;
    uint8 public decimals_;

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals_ = _decimals;
        answer = _initialAnswer;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        // (roundId, answer, startedAt, updatedAt, answeredInRound)
        return (0, answer, block.timestamp, block.timestamp, 0);
    }

    function updateAnswer(int256 newAnswer) external {
        answer = newAnswer;
    }
}

contract TrustScoreMarketTest is Test {
    TrustScoreOracle oracle;
    TrustScoreMarket market;
    BorrowLens lens;
    TestUSDC usdc;

    MockV3Aggregator wethFeed;
    MockV3Aggregator btcFeed;

    uint256 signerKey;
    address signer;

    address alice;
    MockERC20 wethToken;
    MockERC20 cbbtcToken;

    
function setUp() public {
    signerKey = 0xBEEF00112233445566778899AABBCCDDEEFF00112233445566778899AABBCCDD;
    signer = vm.addr(signerKey);

    oracle = new TrustScoreOracle(signer);
    usdc  = new TestUSDC();

    // deploy collateral mocks
    wethToken  = new MockERC20("WETH", "WETH", 18);
    cbbtcToken = new MockERC20("cbBTC", "CBTC", 8);

    // deploy price feed mocks
    wethFeed = new MockV3Aggregator(8, int256(2000 * 1e8));
    btcFeed  = new MockV3Aggregator(8, int256(40000 * 1e8));

    // deploy market
    market = new TrustScoreMarket(
        address(oracle),
        address(usdc),
        address(wethToken),
        address(cbbtcToken)
    );

    // deploy lens
    lens = new BorrowLens(address(market));

    // set decimals
    market.setTokenDecimals(address(usdc), 6);
    market.setTokenDecimals(address(wethToken), 18);
    market.setTokenDecimals(address(cbbtcToken), 8);

    // set price feeds
    market.setPriceFeed(address(wethToken), address(wethFeed), 8);
    market.setPriceFeed(address(cbbtcToken), address(btcFeed), 8);

    // seed liquidity
    usdc.mint(address(market), 1_000_000 * 1e6);

    // prepare alice
    alice = address(0xA11CE);
    wethToken.mint(alice, 10 ether);
    cbbtcToken.mint(alice, 10 * 1e8);
}

    // helper: sign (call oracle.digestForSigning then vm.sign)
    function _signScore(address wallet, uint8 score, uint256 nonce) internal returns (bytes memory sig, uint256 ts) {
        ts = block.timestamp;
        bytes32 digest = oracle.digestForSigning(wallet, score, ts, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function testBorrowRepayWithdraw() public {
        uint8 score = 95;
        uint256 nonce = 1;
        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 1000 * 1e6; // 1000 USDC (6 decimals)

        // alice approves market to spend WETH
        vm.startPrank(alice);
        wethToken.approve(address(market), collateralAmount);
        vm.stopPrank();

        // sign score for alice
        (bytes memory sig, uint256 ts) = _signScore(alice, score, nonce);

        // alice calls oneClickBorrow via lens
        vm.prank(alice);
        bool ok = lens.oneClickBorrow(
            alice,
            alice,
            address(wethToken),
            collateralAmount,
            borrowAmount,
            score,
            ts,
            nonce,
            sig
        );
        assertTrue(ok, "oneClickBorrow failed");

        // verify position on market
        TrustScoreMarket.Position memory pos = market.getPosition(alice);
        assertEq(pos.borrowUsd, borrowAmount);

        // prepare alice to repay
        vm.startPrank(alice);
        usdc.mint(alice, borrowAmount);
        usdc.approve(address(market), borrowAmount);
        vm.stopPrank();

        // repay and withdraw
        vm.prank(alice);
        market.repayAndWithdraw(alice, borrowAmount);

        TrustScoreMarket.Position memory pos2 = market.getPosition(alice);
        assertEq(pos2.borrowUsd, 0, "position should be cleared after full repay");
    }

    function testLiquidationAfterPriceDrop() public {
        uint8 score = 95;
        uint256 nonce = 10;

        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 1500 * 1e6; // 1500 USDC

        // alice approves market to spend WETH
        vm.startPrank(alice);
        wethToken.approve(address(market), collateralAmount);
        vm.stopPrank();

        // sign and borrow
        (bytes memory sig, uint256 ts) = _signScore(alice, score, nonce);
        vm.prank(alice);
        lens.oneClickBorrow(
            alice,
            alice,
            address(wethToken),
            collateralAmount,
            borrowAmount,
            score,
            ts,
            nonce,
            sig
        );

        // price drops significantly
        wethFeed.updateAnswer(int256(500 * 1e8)); // WETH now $500

        uint256 repayUsd = 500 * 1e6;
        address liquidator = address(0xBEEF);

        // give liquidator USDC and approve
        usdc.mint(liquidator, repayUsd);
        vm.prank(liquidator);
        usdc.approve(address(market), repayUsd);

        // perform liquidation
        vm.prank(liquidator);
        market.liquidate(alice, repayUsd);

        // after liquidation debt must be reduced
        TrustScoreMarket.Position memory posAfter = market.getPosition(alice);
        assertLt(posAfter.borrowUsd, borrowAmount, "debt should reduce after liquidation");
    }
}
