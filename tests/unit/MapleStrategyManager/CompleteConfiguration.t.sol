// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals } from "../../utils/Mocks.sol";
import { TestBase }    from "../../utils/TestBase.sol";

contract CompleteConfigurationFailureTests is TestBase {

    function test_completeConfiguration_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.completeConfiguration.selector, true);

        vm.expectRevert("MSM:PAUSED");
        strategyManager.completeConfiguration();
    }

    function test_completeConfiguration_revert_alreadyConfigured() external {
        assertEq(strategyManager.configured(), true);

        vm.expectRevert("MSM:CC:ALREADY_CONFIGURED");
        strategyManager.completeConfiguration();
    }

}

contract CompleteConfigurationSuccessTests is TestBase {

    function test_completeConfiguration_success() external {
        strategyManager.__setConfigured(false);

        assertEq(strategyManager.configured(), false);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerConfigurationComplete();

        strategyManager.completeConfiguration();

        assertEq(strategyManager.configured(), true);
    }

}
