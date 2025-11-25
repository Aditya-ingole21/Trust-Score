// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TrustScoreOracle.sol";
import "../src/TrustScoreMarket.sol";
import "../src/BorrowLens.sol";

contract DeployScript is Script {
    // Base Sepolia Chainlink Feeds
    address constant WETH_USD_FEED = 0x1687d4638Ef74019915a105c7B5B2e0FA5A3a101;
address constant BTC_USD_FEED  = 0x51A6D0a79BBf21633098C30cb7aD24f1E19074e4;

    // Test tokens (you will replace these later)
    address constant USDC = 0x4200000000000000000000000000000000000006; 
    address constant WETH = 0x4200000000000000000000000000000000000007;
    address constant CBBTC = 0x4200000000000000000000000000000000000008;

    function run() public {
         uint256 key = 0x5eb5539b43913fe06afc3f6a4acc5650543bd4b013cfca9ad560c082857503a0;
     

        vm.startBroadcast(key);

        // 1. Deploy Oracle
        TrustScoreOracle oracle = new TrustScoreOracle(msg.sender);

        // 2. Deploy Market
        TrustScoreMarket market = new TrustScoreMarket(
            address(oracle),
            USDC,
            WETH,
            CBBTC
        );

        // 3. Deploy Lens
        BorrowLens lens = new BorrowLens(address(market));

        // Configure tokens
        market.setTokenDecimals(USDC, 6);
        market.setTokenDecimals(WETH, 18);
        market.setTokenDecimals(CBBTC, 18);

        // Configure price feeds
        market.setPriceFeed(WETH, WETH_USD_FEED);
        market.setPriceFeed(CBBTC, BTC_USD_FEED);

        console.log("Oracle:", address(oracle));
        console.log("Market:", address(market));
        console.log("Lens:", address(lens));

        vm.stopBroadcast();
    }
}
