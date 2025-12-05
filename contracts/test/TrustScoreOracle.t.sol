// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract TrustScoreOracle is Ownable, EIP712 {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // signer (backend)
    address public signer;

    // user => last valid score
    mapping(address => uint8) public lastScore;

    // user => used nonce (prevent replay attacks)
    mapping(address => mapping(uint256 => bool)) public usedNonce;

    // valid signature time window (10 minutes = 600 seconds)
    uint256 public constant TTL = 600;

    // EIP-712 struct typehash
    bytes32 private constant TYPEHASH =
        keccak256(
            "Score(address wallet,uint8 score,uint256 timestamp,uint256 nonce)"
        );

    event ScoreVerified(address indexed user, uint8 score);

    constructor(address _signer)
        Ownable(msg.sender)
        EIP712("TrustScoreOracle", "1")
    {
        require(_signer != address(0), "invalid signer");
        signer = _signer;
    }

    function updateSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "invalid signer");
        signer = _signer;
    }

    // ------------------------------------------------------------------------
    // EIP-712 digest creator  (used by tests and by your backend)
    // ------------------------------------------------------------------------
    function digestForSigning(
        address wallet,
        uint8 score,
        uint256 timestamp,
        uint256 nonce
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(TYPEHASH, wallet, score, timestamp, nonce)
        );
        return _hashTypedDataV4(structHash);
    }

    // ------------------------------------------------------------------------
    // Main verify function (called by TrustScoreMarket)
    // ------------------------------------------------------------------------
    function verifyScore(
        address wallet,
        uint8 score,
        uint256 timestamp,
        uint256 nonce,
        bytes memory signature
    ) public returns (bool) {
        // --- timestamp expired ---
        require(block.timestamp <= timestamp + TTL, "signature expired");

        // --- replay protection ---
        require(!usedNonce[wallet][nonce], "nonce used");
        usedNonce[wallet][nonce] = true;

        // --- EIP-712 digest ---
        bytes32 digest = digestForSigning(wallet, score, timestamp, nonce);

        // --- recover signer ---
        address recovered = ECDSA.recover(digest, signature);
        require(recovered == signer, "invalid signer");

        // save score
        lastScore[wallet] = score;

        emit ScoreVerified(wallet, score);
        return true;
    }

    function getScore(address wallet) external view returns (uint8) {
        return lastScore[wallet];
    }
}
