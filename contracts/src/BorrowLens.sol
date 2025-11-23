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
        uint256 collateralAmount,
        uint256 borrowAmount,
        bytes memory signature
    ) external returns (bool) {
        return market.verifyAndBorrow(
            user,
            collateralAmount,
            borrowAmount,
            signature
        );
    }
}
