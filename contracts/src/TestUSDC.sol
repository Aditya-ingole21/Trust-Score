// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestUSDC is ERC20 {
    uint8 private _decimals;

    constructor() ERC20("Test USDC", "tUSDC") {
        _decimals = 6;
    }

    /// @notice Mint freely in tests (no onlyOwner) so tests can allocate tokens easily.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
