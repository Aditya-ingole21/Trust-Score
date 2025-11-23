// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { TrustScoreOracle } from "./TrustScoreOracle.sol";

contract TrustScoreMarket is Ownable(msg.sender) {
    
    TrustScoreOracle public oracle;

    // LTV rules (simple version)
    struct LTVBracket {
        uint256 minScore;
        uint256 maxScore;
        uint256 maxLTV;   // e.g., 95 = 95%
    }

    LTVBracket[] public brackets;

    constructor(address _oracle) {
        oracle = TrustScoreOracle(_oracle);

        // EXACT LAUNCH TABLE
        brackets.push(LTVBracket(95, 100, 97));
        brackets.push(LTVBracket(90, 94, 95));
        brackets.push(LTVBracket(85, 89, 90));
        brackets.push(LTVBracket(80, 84, 85));
        brackets.push(LTVBracket(75, 79, 80));
        brackets.push(LTVBracket(70, 74, 70));
        brackets.push(LTVBracket(0, 69, 50));
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = TrustScoreOracle(_oracle);
    }

    function getMaxLTV(uint256 score) public view returns (uint256) {
        for (uint256 i = 0; i < brackets.length; i++) {
            if (score >= brackets[i].minScore && score <= brackets[i].maxScore) {
                return brackets[i].maxLTV;
            }
        }
        return 50;    
    }

    // -------------------------
    // verify + LTV check
    // -------------------------
    function verifyAndBorrow(
        address user,
        uint256 collateralAmount,
        uint256 borrowAmount,
        bytes memory signature
    ) external returns (bool) {

        // 1. Verify backend signature (ADDED)
        oracle.verifyScore(user, oracle.lastScore(user), signature);

        uint256 score = oracle.lastScore(user);
        require(score > 0, "No score found");

        uint256 maxLtv = getMaxLTV(score);

        // collateral must cover borrowAmount / LTV
        uint256 requiredCollateral = (borrowAmount * 100) / maxLtv;

        require(collateralAmount >= requiredCollateral, "Not enough collateral");

        // (Real Morpho Blue borrow goes later)
        return true;
    }
}

