// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals } from "../../utils/Mocks.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetPendingStrategyDelegateFailureTests is TestBase {

    address newStrategyDelegate = makeAddr("newStrategyDelegate");

    function test_setPendingStrategyDelegate_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.setPendingStrategyDelegate.selector, true);

        vm.prank(operationalAdmin);
        vm.expectRevert("MSM:PAUSED");
        strategyManager.setPendingStrategyDelegate(newStrategyDelegate);
    }

    function test_setPendingStrategyDelegate_revert_notAuthorized() external {
        vm.expectRevert("MSM:SPSD:NOT_OPERATIONAL_ADMIN");
        strategyManager.setPendingStrategyDelegate(newStrategyDelegate);
    }

    function test_setPendingStrategyDelegate_revert_calledByStrategyDelegate() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:SPSD:NOT_OPERATIONAL_ADMIN");
        strategyManager.setPendingStrategyDelegate(newStrategyDelegate);
    }

}

contract SetPendingStrategyDelegateSuccessTests is TestBase {

    address newStrategyDelegate  = makeAddr("newStrategyDelegate");
    address nextStrategyDelegate = makeAddr("nextStrategyDelegate");

    function test_setPendingStrategyDelegate_success_calledByOperationalAdmin() external {
        assertEq(strategyManager.strategyDelegate(),        strategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(), address(0));

        vm.expectEmit(address(strategyManager));
        emit IMapleStrategyManager.PendingStrategyDelegateSet(newStrategyDelegate);

        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(newStrategyDelegate);

        assertEq(strategyManager.strategyDelegate(),        strategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(), newStrategyDelegate);
    }

    function test_setPendingStrategyDelegate_success_cancelWithZeroAddress() external {
        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(newStrategyDelegate);

        assertEq(strategyManager.strategyDelegate(),        strategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(), newStrategyDelegate);

        vm.expectEmit(address(strategyManager));
        emit IMapleStrategyManager.PendingStrategyDelegateSet(address(0));

        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(address(0));

        assertEq(strategyManager.strategyDelegate(),        strategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(), address(0));
    }

    function test_setPendingStrategyDelegate_success_currentStrategyDelegate() external {
        assertEq(strategyManager.strategyDelegate(),        strategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(), address(0));

        vm.expectEmit(address(strategyManager));
        emit IMapleStrategyManager.PendingStrategyDelegateSet(strategyDelegate);

        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(strategyDelegate);

        assertEq(strategyManager.strategyDelegate(),        strategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(), strategyDelegate);
    }

    function test_setPendingStrategyDelegate_success_overwrite() external {
        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(newStrategyDelegate);

        assertEq(strategyManager.strategyDelegate(),        strategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(), newStrategyDelegate);

        vm.expectEmit(address(strategyManager));
        emit IMapleStrategyManager.PendingStrategyDelegateSet(nextStrategyDelegate);

        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(nextStrategyDelegate);

        assertEq(strategyManager.strategyDelegate(),        strategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(), nextStrategyDelegate);
    }

}
