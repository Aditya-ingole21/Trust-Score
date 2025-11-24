// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TrustScoreMarket } from "./TrustScoreMarket.sol";

contract BorrowLens {

    TrustScoreMarket public market;

    constructor(address _market) {
        market = TrustScoreMarket(_market);
    }

    function oneClickBorrow(
        address user,
        address collateralToken,
        uint256 collateralAmount,
        uint256 borrowAmountUsd,
        bytes memory signature,
        uint8 aggregatorDecimals
    ) external returns (bool) {
        return market.verifyAndBorrow(
            user,
            collateralToken,
            collateralAmount,
            borrowAmountUsd,
            signature,
            aggregatorDecimals
        );
    }
}
