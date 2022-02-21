// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title Fuse Leveraged Token (FLT)
/// @author bayu (github.com/pyk)
/// @notice Leveraged Token powered by Rari Fuse
contract FuseLeveragedToken is ERC20 {
    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice The ERC20 compliant token that used by FLT as collateral
    address public collateral;

    /// ███ Constructors ███████████████████████████████████████████████████████

    /// @notice Creates a new FLT that manages specific collateral and debt
    /// @param _name The name of the Fuse Leveraged Token.
    /// @param _symbol The symbol of the Fuse Leveraged Token.
    /// @param _collateral The ERC20 compliant token the FLT accepts as collateral
    constructor(string memory _name, string memory _symbol, address _collateral) ERC20(_name, _symbol) {
        collateral = _collateral;
    }

    /// ███ User actions ███████████████████████████████████████████████████████

    /// @notice Mints shares FLT shares to receiver by depositing exactly amount of collateral tokens.
    /// @param _collateralAmount The amount of collateral
    /// @param _recipient The address that will receive the minted leveraged tokens
    /// @return _shares The amount of leveraged tokens minted
    function deposit(uint256 _collateralAmount, address _recipient) external view returns (uint256 _shares) {
        // TODO(pyk): Check max mint amount
        return 0;
    }
}
