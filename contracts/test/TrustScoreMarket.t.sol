// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TrustScoreMarket.sol";

/// Minimal mock ERC20 (mintable, basic allowance/transferFrom)
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "insufficient-from");
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "allowance");
        allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/// Mock chainlink aggregator
contract MockAggregator {
    int256 public answer;
    uint8 public aggDecimals;

    constructor(int256 _answer, uint8 _decimals) {
        answer = _answer;
        aggDecimals = _decimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (uint80(1), answer, block.timestamp, block.timestamp, uint80(1));
    }
}

/// Mock oracle
contract MockOracle {
    mapping(address => uint256) public lastScore;
    address public signer;

    event ScoreVerified(address indexed user, uint256 score);

    constructor(address _signer) {
        signer = _signer;
    }

    function verifyScore(address user, uint256 score, bytes memory) external returns (bool) {
        uint256 setTo = score == 0 ? 90 : score;
        lastScore[user] = setTo;
        emit ScoreVerified(user, setTo);
        return true;
    }

    function updateSigner(address _s) external {
        signer = _s;
    }
}

contract TrustScoreMarketTest is Test {
    TrustScoreMarket market;
    MockOracle oracle;
    MockERC20 usdc;
    MockERC20 weth;
    MockERC20 cbBTC;
    MockAggregator aggWETH;

    address owner = address(0xABCD);
    address alice = address(0xBEEF);
    address deployer = address(0xDEAD);

    function setUp() public {
        vm.deal(deployer, 1 ether);

        oracle = new MockOracle(owner);

        usdc = new MockERC20("USDC","USDC",6);
        weth = new MockERC20("WETH","WETH",18);
        cbBTC = new MockERC20("cbBTC","cbBTC",8);

        int256 wethPrice = int256(2000 * 10 ** 8);
        aggWETH = new MockAggregator(wethPrice, 8);

        vm.prank(deployer);
        market = new TrustScoreMarket(address(oracle), address(usdc), address(weth), address(cbBTC));

        usdc.mint(deployer, 100_000 * 10 ** 6);
        vm.prank(deployer);
        usdc.transfer(address(market), 100_000 * 10 ** 6);

        vm.prank(deployer);
        market.setPriceFeed(address(weth), address(aggWETH), 8);

        vm.prank(deployer);
        market.setTokenDecimals(address(weth), 18);

        weth.mint(alice, 1 ether);
    }

    function test_setPriceFeed_and_getPrice() public {
        uint256 p = market.getPrice(address(weth));
        assertEq(p, uint256(2000 * 10 ** 8));
    }

    function test_verifyAndBorrow_success() public {
        vm.prank(alice);
        weth.approve(address(market), 1 ether);

        uint256 collateralAmount = 0.1 ether;
        uint256 borrowUsd = 50 * 10 ** 6;

        vm.prank(alice);
        bool ok = market.verifyAndBorrow(
            alice,
            address(weth),
            collateralAmount,
            borrowUsd,
            bytes("sig"),
            8
        );
        assertTrue(ok);

        assertEq(usdc.balanceOf(alice), borrowUsd);

        (address collTok, uint256 collAmt, uint256 borrowed) = market.getPosition(alice);
        assertEq(collTok, address(weth));
        assertEq(collAmt, collateralAmount);
        assertEq(borrowed, borrowUsd);
    }

    function test_verifyAndBorrow_fails_missingPriceFeed() public {
        vm.prank(alice);
        cbBTC.mint(alice, 10 * 10 ** 8);
        vm.prank(alice);
        cbBTC.approve(address(market), 10 * 10 ** 8);

        vm.prank(alice);
        vm.expectRevert("missing price feed");
        market.verifyAndBorrow(alice, address(cbBTC), 1 * 10 ** 8, 10 * 10 ** 6, bytes("sig"), 8);
    }

    function test_verifyAndBorrow_fails_insufficientCollateral() public {
        vm.prank(alice);
        weth.approve(address(market), 1 ether);

        uint256 collateralAmount = 1 wei;
        uint256 borrowUsd = 1000 * 10 ** 6;

        vm.prank(alice);
        vm.expectRevert("Not enough collateral USD value");
        market.verifyAndBorrow(alice, address(weth), collateralAmount, borrowUsd, bytes("sig"), 8);
    }

    function test_repayAndWithdraw_fullRepay_returnsCollateral() public {
        vm.prank(alice);
        weth.approve(address(market), 1 ether);

        uint256 collateralAmount = 0.1 ether;
        uint256 borrowUsd = 50 * 10 ** 6;

        vm.prank(alice);
        market.verifyAndBorrow(alice, address(weth), collateralAmount, borrowUsd, bytes("sig"), 8);

        vm.prank(alice);
        usdc.approve(address(market), borrowUsd);

        vm.prank(alice);
        bool ok = market.repayAndWithdraw(alice, borrowUsd);
        assertTrue(ok);

        (, , uint256 borrowed) = market.getPosition(alice);
        assertEq(borrowed, 0);

        assertEq(weth.balanceOf(alice), 1 ether);
    }

    function test_adminWithdraw() public {
        uint256 beforeBal = usdc.balanceOf(deployer);
        uint256 marketBal = usdc.balanceOf(address(market));
        uint256 amt = 1 * 10 ** 6;

        vm.prank(deployer);
        market.adminWithdraw(address(usdc), amt, deployer);

        uint256 afterBal = usdc.balanceOf(deployer);

        assertEq(afterBal - beforeBal, amt);
        assertEq(usdc.balanceOf(address(market)), marketBal - amt);
    }
}
