// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals } from "../../utils/Mocks.sol";
import { TestBase }    from "../../utils/TestBase.sol";

contract SetUnderlyingStrategyFailureTests is TestBase {

    function setUp() public override {
        super.setUp();

        strategyManager.__setConfigured(false);
    }

    function test_setUnderlyingStrategy_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.setUnderlyingStrategy.selector, true);

        vm.expectRevert("MSM:PAUSED");
        strategyManager.setUnderlyingStrategy(makeAddr("newUnderlyingStrategy"));
    }

    function test_setUnderlyingStrategy_revert_alreadyConfigured() external {
        strategyManager.__setConfigured(true);

        vm.expectRevert("MSM:SUS:ALREADY_CONFIGURED");
        strategyManager.setUnderlyingStrategy(makeAddr("newUnderlyingStrategy"));
    }

}

contract SetUnderlyingStrategySuccessTests is TestBase {

    function test_setUnderlyingStrategy_success() external {
        address newUnderlyingStrategy = makeAddr("newUnderlyingStrategy");

        strategyManager.__setConfigured(false);
        strategyManager.__setUnderlyingStrategy(address(0));

        assertEq(strategyManager.configured(),         false);
        assertEq(strategyManager.underlyingStrategy(), address(0));

        vm.expectEmit();
        emit IMapleStrategyManager.UnderlyingStrategySet(newUnderlyingStrategy);

        strategyManager.setUnderlyingStrategy(newUnderlyingStrategy);

        assertEq(strategyManager.configured(),         false);
        assertEq(strategyManager.underlyingStrategy(), newUnderlyingStrategy);
    }

}
