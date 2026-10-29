// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ALP token
/// @notice A plain fixed-supply ERC-20 (BEP-20 on BNB Smart Chain). The entire supply is minted
///         once, in the constructor, to the treasury. There is no mint, burn, owner, role, pause,
///         blacklist, fee, transfer limit or upgrade path; see ADR-0004.
contract ALPToken is ERC20 {
    error InvalidSupply();

    /// @param name_ Token name.
    /// @param symbol_ Token symbol.
    /// @param totalSupply_ The fixed total supply in base units (18 decimals); must be nonzero.
    /// @param treasury_ The reviewed treasury Safe that receives the whole supply.
    constructor(string memory name_, string memory symbol_, uint256 totalSupply_, address treasury_)
        ERC20(name_, symbol_)
    {
        if (totalSupply_ == 0) revert InvalidSupply();
        // ERC20._mint already rejects a zero treasury with ERC20InvalidReceiver(address(0)).
        _mint(treasury_, totalSupply_);
    }
}
