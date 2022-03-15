// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { FuseLeveragedToken } from "../FuseLeveragedToken.sol";
import { GOHM_ADDRESS } from "./HEVM.sol";

/// @title Fuse Leveraged Token Test
/// @author bayu (github.com/pyk)
/// @notice Unit test for Fuse Leveraged Token
contract FuseLeveragedTokenTest is DSTest {
    function testProperties() public {
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", GOHM_ADDRESS);

        // Test public properties
        assertEq(flt.name(), "gOHM 2x Long");
        assertEq(flt.symbol(), "gOHMRISE");
        assertEq(flt.collateral(), GOHM_ADDRESS);
    }
}
