// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals } from "../../utils/Mocks.sol";
import { TestBase } from "../../utils/TestBase.sol";

contract AcceptStrategyDelegateFailureTests is TestBase {

    address newStrategyDelegate = makeAddr("newStrategyDelegate");

    function test_acceptStrategyDelegate_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.acceptStrategyDelegate.selector, true);

        vm.prank(newStrategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        strategyManager.acceptStrategyDelegate();
    }

    function test_acceptStrategyDelegate_revert_noPendingStrategyDelegate() external {
        vm.expectRevert("MSM:ASD:NOT_PENDING_SD");
        strategyManager.acceptStrategyDelegate();
    }

    function test_acceptStrategyDelegate_revert_notPendingStrategyDelegate() external {
        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(newStrategyDelegate);

        vm.expectRevert("MSM:ASD:NOT_PENDING_SD");
        strategyManager.acceptStrategyDelegate();
    }

    function test_acceptStrategyDelegate_revert_globalsTransferFails() external {
        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(newStrategyDelegate);

        MockGlobals(globals).__setFailTransferOwnedStrategyManager(true);

        vm.prank(newStrategyDelegate);
        vm.expectRevert("MG:TOSM:FAILED");
        strategyManager.acceptStrategyDelegate();

        assertEq(strategyManager.strategyDelegate(),                                strategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(),                         newStrategyDelegate);
        assertEq(MockGlobals(globals).strategyDelegateOf(address(strategyManager)), strategyDelegate);
    }

}

contract AcceptStrategyDelegateSuccessTests is TestBase {

    address newStrategyDelegate  = makeAddr("newStrategyDelegate");
    address nextStrategyDelegate = makeAddr("nextStrategyDelegate");

    function test_acceptStrategyDelegate_success() external {
        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(newStrategyDelegate);

        assertEq(strategyManager.strategyDelegate(),                                strategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(),                         newStrategyDelegate);
        assertEq(MockGlobals(globals).strategyDelegateOf(address(strategyManager)), strategyDelegate);

        vm.expectEmit(address(strategyManager));
        emit IMapleStrategyManager.PendingStrategyDelegateAccepted(strategyDelegate, newStrategyDelegate);

        vm.prank(newStrategyDelegate);
        strategyManager.acceptStrategyDelegate();

        assertEq(strategyManager.strategyDelegate(),                                newStrategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(),                         address(0));
        assertEq(MockGlobals(globals).strategyDelegateOf(address(strategyManager)), newStrategyDelegate);
    }

    function test_acceptStrategyDelegate_success_canSetPendingStrategyDelegateAfterAccept() external {
        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(newStrategyDelegate);

        vm.prank(newStrategyDelegate);
        strategyManager.acceptStrategyDelegate();

        assertEq(strategyManager.strategyDelegate(),                                newStrategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(),                         address(0));
        assertEq(MockGlobals(globals).strategyDelegateOf(address(strategyManager)), newStrategyDelegate);

        vm.expectEmit(address(strategyManager));
        emit IMapleStrategyManager.PendingStrategyDelegateSet(nextStrategyDelegate);

        vm.prank(operationalAdmin);
        strategyManager.setPendingStrategyDelegate(nextStrategyDelegate);

        assertEq(strategyManager.strategyDelegate(),                                newStrategyDelegate);
        assertEq(strategyManager.pendingStrategyDelegate(),                         nextStrategyDelegate);
        assertEq(MockGlobals(globals).strategyDelegateOf(address(strategyManager)), newStrategyDelegate);
    }

}
