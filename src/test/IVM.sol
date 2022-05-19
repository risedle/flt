// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title Foundry VM Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice doc: https://github.com/foundry-rs/foundry/tree/master/forge#cheat-codes
 */
interface IVM {
    function addr(uint256 sk) external returns (address);
    function warp(uint256 x) external;
    function roll(uint256 x) external;
    function store(address c, bytes32 loc, bytes32 val) external;
    function expectRevert(bytes calldata) external;
    function startPrank(address sender) external;
    function prank(address sender) external;
    function stopPrank() external;
}

