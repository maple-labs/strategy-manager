// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals } from "../../utils/Mocks.sol";
import { TestBase } from "../../utils/TestBase.sol";

contract SetStrategyLiquidityCapFailureTests is TestBase {

    function test_setStrategyLiquidityCap_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.setStrategyLiquidityCap.selector, true);

        vm.expectRevert("MSM:PAUSED");
        setStrategyLiquidityCap(1);
    }

    function test_setStrategyLiquidityCap_revert_notAuthorized() external {
        vm.expectRevert("MSM:NOT_ADMIN");
        strategyManager.setStrategyLiquidityCap(1);
    }

    function test_setStrategyLiquidityCap_revert_noChange_zero() external {
        assertEq(strategyManager.strategyLiquidityCap(), 0);

        vm.expectRevert("MSM:SSC:NO_CHANGE");
        setStrategyLiquidityCap(0);
    }

    function test_setStrategyLiquidityCap_revert_noChange() external {
        uint256 cap = 1_000;

        setStrategyLiquidityCap(cap);

        vm.expectRevert("MSM:SSC:NO_CHANGE");
        setStrategyLiquidityCap(cap);
    }

}

contract SetStrategyLiquidityCapSuccessTests is TestBase {

    function test_setStrategyLiquidityCap_success_calledByStrategyDelegate() external {
        uint256 cap = 1_000;

        assertEq(strategyManager.strategyLiquidityCap(), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyLiquidityCapSet(cap);

        setStrategyLiquidityCap(cap);

        assertEq(strategyManager.strategyLiquidityCap(), cap);
    }

    function test_setStrategyLiquidityCap_success_calledByOperationalAdmin() external {
        uint256 cap = 1_000;

        assertEq(strategyManager.strategyLiquidityCap(), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyLiquidityCapSet(cap);

        vm.prank(operationalAdmin);
        strategyManager.setStrategyLiquidityCap(cap);

        assertEq(strategyManager.strategyLiquidityCap(), cap);
    }

    function test_setStrategyLiquidityCap_success_calledByNonAdminWhenNotConfigured() external {
        uint256 cap = 1_000;

        strategyManager.__setConfigured(false);

        assertEq(strategyManager.configured(),           false);
        assertEq(strategyManager.strategyLiquidityCap(), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyLiquidityCapSet(cap);

        strategyManager.setStrategyLiquidityCap(cap);

        assertEq(strategyManager.configured(),           false);
        assertEq(strategyManager.strategyLiquidityCap(), cap);
    }

    function test_setStrategyLiquidityCap_success_max_calledByStrategyDelegate() external {
        uint256 cap = type(uint256).max;

        assertEq(strategyManager.strategyLiquidityCap(), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyLiquidityCapSet(cap);

        setStrategyLiquidityCap(cap);

        assertEq(strategyManager.strategyLiquidityCap(), cap);
    }

    function test_setStrategyLiquidityCap_success_update_calledByStrategyDelegate() external {
        uint256 initialCap = 1_000;
        uint256 updatedCap = 500;

        setStrategyLiquidityCap(initialCap);

        assertEq(strategyManager.strategyLiquidityCap(), initialCap);

        setStrategyLiquidityCap(updatedCap);

        assertEq(strategyManager.strategyLiquidityCap(), updatedCap);
    }

    function test_setStrategyLiquidityCap_success_zero_calledByStrategyDelegate() external {
        setStrategyLiquidityCap(1);

        assertEq(strategyManager.strategyLiquidityCap(), 1);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyLiquidityCapSet(0);

        setStrategyLiquidityCap(0);

        assertEq(strategyManager.strategyLiquidityCap(), 0);
    }

}
