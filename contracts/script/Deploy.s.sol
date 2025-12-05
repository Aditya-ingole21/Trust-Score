// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TrustScoreOracle.sol";
import "../src/TrustScoreMarket.sol";
import "../src/BorrowLens.sol";

contract Deploy is Script {
    // Ethereum Sepolia Chainlink feeds
    address constant ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    // Ethereum Sepolia tokens
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant WETH = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;

    function run() external {
        uint256 deployer = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployer);

        // 1. Deploy Oracle
        TrustScoreOracle oracle = new TrustScoreOracle(msg.sender);

        // 2. Deploy Market (cbBTC disabled = address(0))
        TrustScoreMarket market =
            new TrustScoreMarket(address(oracle), USDC, WETH, address(0));

        // 3. Deploy Lens
        BorrowLens lens = new BorrowLens(address(market));

        // decimals
        market.setTokenDecimals(USDC, 6);
        market.setTokenDecimals(WETH, 18);

        // price feeds (only WETH)
        market.setPriceFeed(WETH, ETH_USD_FEED, 8);

        console.log("Oracle:", address(oracle));
        console.log("Market:", address(market));
        console.log("Lens:", address(lens));

        vm.stopBroadcast();
    }
}
