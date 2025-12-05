// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TrustScoreMarket } from "./TrustScoreMarket.sol";

contract BorrowLens {

    TrustScoreMarket public market;

    constructor(address _market) {
        market = TrustScoreMarket(_market);
    }

    /**
     * @notice One-click borrow: forwards required params to TrustScoreMarket.verifyAndBorrow
     * @param user wallet for which score was issued (the borrower)
     * @param collateralFrom address supplying collateral (should be `user` in normal UX)
     * @param collateralToken token used as collateral (WETH or cbBTC)
     * @param collateralAmount raw token units
     * @param borrowAmountUsd USDC (6 decimals)
     * @param score signed score (0-100) from backend
     * @param timestamp timestamp the backend signed (unix seconds)
     * @param nonce monotonic nonce the backend used for this wallet
     * @param signature EIP-712 signature from the backend signer
     */
    function oneClickBorrow(
        address user,
        address collateralFrom,
        address collateralToken,
        uint256 collateralAmount,
        uint256 borrowAmountUsd,
        uint8 score,
        uint256 timestamp,
        uint256 nonce,
        bytes memory signature
    ) external returns (bool) {
        return market.verifyAndBorrow(
            user,
            collateralFrom,
            collateralToken,
            collateralAmount,
            borrowAmountUsd,
            score,
            timestamp,
            nonce,
            signature
        );
    }
}
