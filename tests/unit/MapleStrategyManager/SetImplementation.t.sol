// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals } from "../../utils/Mocks.sol";
import { TestBase } from "../../utils/TestBase.sol";

contract SetImplementationTests is TestBase {

    address internal newImplementation;

    function setUp() public override {
        super.setUp();

        newImplementation = address(new MapleStrategyManager());
    }

    function test_setImplementation_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.setImplementation.selector, true);

        vm.expectRevert("MSM:PAUSED");
        strategyManager.setImplementation(newImplementation);
    }

    function test_setImplementation_revert_notFactory() external {
        vm.expectRevert("MSM:NOT_FACTORY");
        strategyManager.setImplementation(newImplementation);
    }

    function test_setImplementation_success() external {
        assertEq(strategyManager.implementation(), implementation);

        vm.prank(address(factory));
        strategyManager.setImplementation(newImplementation);

        assertEq(strategyManager.implementation(), newImplementation);
    }

}
