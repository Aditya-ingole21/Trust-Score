// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TrustScoreOracle is Ownable(msg.sender) {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address public signer; // backend signer wallet
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
        bytes32 hash = keccak256(abi.encode(user, score));

        // FIX: OZ v5 → toEthSignedMessageHash is on MessageHashUtils
        bytes32 ethHash = hash.toEthSignedMessageHash();

        address recovered = ethHash.recover(signature);
        require(recovered == signer, "Invalid signature");

        lastScore[user] = score;
        emit ScoreVerified(user, score);
        return true;
    }

    function getScore(address user) external view returns (uint256) {
        return lastScore[user];
    }
}
