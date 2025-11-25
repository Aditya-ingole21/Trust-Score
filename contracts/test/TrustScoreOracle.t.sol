// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TrustScoreOracle.sol";

contract TrustScoreOracleTest is Test {
    TrustScoreOracle oracle;

    // Backend signer private key (local for test)
    uint256 backendPk;
    address backendSigner;

    address user = address(0xBEEF);

    function setUp() public {
        // Generate deterministic private key
        backendPk = 0xABCDEF123456789;
        backendSigner = vm.addr(backendPk);

        oracle = new TrustScoreOracle(backendSigner);
    }

    function test_VerifyScore_Succeeds() public {
        uint256 score = 90;

        // 1. Reproduce backend hashing
        bytes32 hash = keccak256(abi.encodePacked(user, score));
        bytes32 ethHash = hash.toEthSignedMessageHash();

        // 2. Sign using Foundry cheatcode
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(backendPk, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 3. Call oracle.verifyScore()
        bool ok = oracle.verifyScore(user, score, signature);
        assertTrue(ok);

        // Score should be stored
        assertEq(oracle.lastScore(user), score);
    }

    function test_VerifyScore_Fails_WithInvalidSignature() public {
        uint256 score = 90;

        // Create signature from wrong private key
        uint256 wrongPk = 0x999999;
        address wrongSigner = vm.addr(wrongPk);
        require(wrongSigner != backendSigner);

        bytes32 hash = keccak256(abi.encodePacked(user, score));
        bytes32 ethHash = hash.toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expect revert: Invalid signature
        vm.expectRevert("Invalid signature");
        oracle.verifyScore(user, score, signature);
    }

    function test_UpdateSigner_Works() public {
        address newSigner = address(0x1234);

        vm.prank(oracle.owner());
        oracle.updateSigner(newSigner);

        assertEq(oracle.signer(), newSigner);
    }

    function test_UpdateSigner_Fails_ForNonOwner() public {
        address newSigner = address(0x5555);

        vm.expectRevert("Ownable: caller is not the owner");
        oracle.updateSigner(newSigner);
    }
}
