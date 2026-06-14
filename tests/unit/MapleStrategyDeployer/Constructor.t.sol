// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../../modules/forge-std/src/Test.sol";

import { MapleStrategyDeployer } from "../../../contracts/MapleStrategyDeployer.sol";

contract ConstructorTests is Test {

    function test_constructor_revert_zeroGlobals() external {
        vm.expectRevert("MSD:C:ZERO_GLOBALS");
        new MapleStrategyDeployer(address(0));
    }

    function test_constructor_success() external {
        address globals = makeAddr("globals");

        MapleStrategyDeployer deployer = new MapleStrategyDeployer(globals);

        assertEq(deployer.globals(), globals);
    }

}
