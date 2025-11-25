// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TrustScoreOracle is Ownable(msg.sender) {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address public signer; 
    mapping(address => uint256) public lastScore;

    event ScoreVerified(address user, uint256 score);

    constructor(address _signer) {
        signer = _signer;
    }

    function updateSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function verifyScore(
        address user,
        uint256 score,
        bytes memory signature
    ) public returns (bool) {

        // Step 1: Same hashing as sign.js
        bytes32 hash = keccak256(abi.encodePacked(user, score));

        // Step 2: Ethereum signed message
        bytes32 ethHash = hash.toEthSignedMessageHash();

        // Step 3: Recover signer
        address recovered = ethHash.recover(signature);
        require(recovered == signer, "Invalid signature");

        // Save score
        lastScore[user] = score;
        emit ScoreVerified(user, score);

        return true;
    }

    function getScore(address user) external view returns (uint256) {
        return lastScore[user];
    }
}
