// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract TrustScoreOracle is Ownable, EIP712 {
    using ECDSA for bytes32;

    // ----------- STATE ----------- //
    address public signer;        // backend signer
    uint256 public ttl = 600;     // 10 minutes TTL

    struct ScoreMessage {
        address wallet;
        uint8 score;
        uint256 timestamp;
        uint256 nonce;
    }

    // mapping(address => latest nonce used)
    mapping(address => uint256) public lastNonce;

    // mapping(address => last verified score)
    mapping(address => uint8) public lastScore;

    // mapping(address => last score timestamp)
    mapping(address => uint256) public lastScoreTimestamp;

    // EIP-712 struct typehash
    bytes32 private constant TYPEHASH =
        keccak256("ScoreMessage(address wallet,uint8 score,uint256 timestamp,uint256 nonce)");

    event ScoreVerified(address indexed wallet, uint8 score, uint256 timestamp, uint256 nonce);
    event SignerUpdated(address indexed newSigner);
    event TTLUpdated(uint256 newTTL);

    // ----------- INIT ----------- //
    constructor(address _signer)
        EIP712("TrustScoreOracle", "1")
        Ownable(msg.sender)
    {
        require(_signer != address(0), "invalid signer");
        signer = _signer;
    }



function digestForSigning(
    address wallet,
    uint8 score,
    uint256 timestamp,
    uint256 nonce
) external view returns (bytes32) {
    bytes32 structHash = keccak256(abi.encode(
        TYPEHASH,
        wallet,
        score,
        timestamp,
        nonce
    ));
    return _hashTypedDataV4(structHash);
}








    // ----------- ADMIN ----------- //
    function updateSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "invalid signer");
        signer = _signer;
        emit SignerUpdated(_signer);
    }

    function updateTTL(uint256 _ttl) external onlyOwner {
        ttl = _ttl;
        emit TTLUpdated(_ttl);
    }

    // ----------- VERIFY ----------- //
    /**
     * @notice Verifies EIP-712 signature and stores lastScore/lastNonce/lastScoreTimestamp
     * @param wallet address the score is for
     * @param score 0-100
     * @param timestamp unix seconds when backend signed
     * @param nonce monotonic nonce for that wallet (backend must increment)
     * @param signature EIP-712 signature from `signer`
     */
    function verifyScore(
        address wallet,
        uint8 score,
        uint256 timestamp,
        uint256 nonce,
        bytes calldata signature
    ) public returns (bool) {
        require(wallet != address(0), "wallet=0");
        require(score <= 100, "score>100");

        // TTL check: signature must be fresh
        require(block.timestamp <= timestamp + ttl, "signature expired");

        // Nonce monotonicity
        require(nonce > lastNonce[wallet], "nonce used");

        // Build struct hash
        bytes32 structHash = keccak256(abi.encode(
            TYPEHASH,
            wallet,
            score,
            timestamp,
            nonce
        ));

        // EIP-712 digest
        bytes32 digest = _hashTypedDataV4(structHash);
        address recovered = digest.recover(signature);
        require(recovered == signer, "invalid signer");

        // Update state
        lastNonce[wallet] = nonce;
        lastScore[wallet] = score;
        lastScoreTimestamp[wallet] = timestamp;

        emit ScoreVerified(wallet, score, timestamp, nonce);
        return true;
    }

    // ----------- VIEWS ----------- //
    function getScore(address wallet) external view returns (uint8) {
        return lastScore[wallet];
    }
}
