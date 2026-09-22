// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals } from "../../utils/Mocks.sol";
import { TestBase } from "../../utils/TestBase.sol";

contract SetActiveFailureTests is TestBase {

    function test_setActive_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.setActive.selector, true);

        vm.prank(globals);
        vm.expectRevert("MSM:PAUSED");
        strategyManager.setActive(false);

        vm.prank(globals);
        vm.expectRevert("MSM:PAUSED");
        strategyManager.setActive(true);
    }

    function test_setActive_revert_notGlobals() external {
        vm.expectRevert("MSM:SA:NOT_GLOBALS");
        strategyManager.setActive(false);

        vm.expectRevert("MSM:SA:NOT_GLOBALS");
        strategyManager.setActive(true);
    }

}

contract SetActiveSuccessTests is TestBase {

    function test_setActive_success() external {
        strategyManager.__setActive(false);

        assertEq(strategyManager.active(), false);

        vm.expectEmit();
        emit IMapleStrategyManager.SetAsActive(true);

        vm.prank(globals);
        strategyManager.setActive(true);

        assertEq(strategyManager.active(), true);

        vm.expectEmit();
        emit IMapleStrategyManager.SetAsActive(false);

        vm.prank(globals);
        strategyManager.setActive(false);

        assertEq(strategyManager.active(), false);
    }

}
