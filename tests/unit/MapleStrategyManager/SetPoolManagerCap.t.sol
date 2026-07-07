// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import {
    MockGlobals,
    MockPoolManager,
    MockPoolManagerFactory
} from "../../utils/Mocks.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetPoolManagerCapFailureTests is TestBase {

    function test_setPoolManagerCap_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.setPoolManagerCap.selector, true);

        vm.expectRevert("MSM:PAUSED");
        setPoolManagerCap(poolManager, 1);
    }

    function test_setPoolManagerCap_revert_notAuthorized() external {
        vm.expectRevert("MSM:NOT_ADMIN");
        strategyManager.setPoolManagerCap(poolManager, 1);
    }

    function test_setPoolManagerCap_revert_noChange_zero() external {
        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        vm.expectRevert("MSM:SPMC:NO_CHANGE");
        setPoolManagerCap(poolManager, 0);
    }

    function test_setPoolManagerCap_revert_noChange_zeroWhenNotConfigured() external {
        address otherPoolManager = address(new MockPoolManager());

        strategyManager.__setConfigured(false);

        assertEq(strategyManager.configured(),                       false);
        assertEq(strategyManager.poolManagerCapOf(otherPoolManager), 0);

        vm.expectRevert("MSM:SPMC:NO_CHANGE");
        strategyManager.setPoolManagerCap(otherPoolManager, 0);
    }

    function test_setPoolManagerCap_revert_noChange() external {
        uint256 cap = 1_000;

        setPoolManagerCap(poolManager, cap);

        vm.expectRevert("MSM:SPMC:NO_CHANGE");
        setPoolManagerCap(poolManager, cap);
    }

    function test_setPoolManagerCap_revert_invalidPMFactory() external {
        address otherFactory     = address(new MockPoolManagerFactory());
        address otherPoolManager = address(new MockPoolManager());

        MockPoolManager(otherPoolManager).__setFactory(otherFactory);
        MockPoolManagerFactory(otherFactory).__setIsInstance(otherPoolManager, true);

        vm.expectRevert("MSM:SPMC:INVALID_PM");
        setPoolManagerCap(otherPoolManager, 1);
    }

    function test_setPoolManagerCap_revert_invalidPMFactoryWhenNotConfigured() external {
        address otherFactory     = address(new MockPoolManagerFactory());
        address otherPoolManager = address(new MockPoolManager());

        strategyManager.__setConfigured(false);

        MockPoolManager(otherPoolManager).__setFactory(otherFactory);
        MockPoolManagerFactory(otherFactory).__setIsInstance(otherPoolManager, true);

        vm.expectRevert("MSM:SPMC:INVALID_PM");
        strategyManager.setPoolManagerCap(otherPoolManager, 1);
    }

    function test_setPoolManagerCap_revert_nonZeroUpdate_invalidPMFactory() external {
        uint256 initialCap = 1_000;
        uint256 updatedCap = 500;

        setPoolManagerCap(poolManager, initialCap);

        assertEq(strategyManager.poolManagerCapOf(poolManager), initialCap);

        MockGlobals(globals).__setIsInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.expectRevert("MSM:SPMC:INVALID_PM");
        setPoolManagerCap(poolManager, updatedCap);

        assertEq(strategyManager.poolManagerCapOf(poolManager), initialCap);
    }

    function test_setPoolManagerCap_revert_invalidPM() external {
        address otherPoolManager = address(new MockPoolManager());

        MockPoolManager(otherPoolManager).__setFactory(poolManagerFactory);

        vm.expectRevert("MSM:SPMC:INVALID_PM");
        setPoolManagerCap(otherPoolManager, 1);
    }

    function test_setPoolManagerCap_revert_invalidPMWhenNotConfigured() external {
        address otherPoolManager = address(new MockPoolManager());

        strategyManager.__setConfigured(false);

        MockPoolManager(otherPoolManager).__setFactory(poolManagerFactory);

        vm.expectRevert("MSM:SPMC:INVALID_PM");
        strategyManager.setPoolManagerCap(otherPoolManager, 1);
    }

    function test_setPoolManagerCap_revert_nonZeroUpdate_invalidPM() external {
        uint256 initialCap = 1_000;
        uint256 updatedCap = 500;

        setPoolManagerCap(poolManager, initialCap);

        assertEq(strategyManager.poolManagerCapOf(poolManager), initialCap);

        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager, false);

        vm.expectRevert("MSM:SPMC:INVALID_PM");
        setPoolManagerCap(poolManager, updatedCap);

        assertEq(strategyManager.poolManagerCapOf(poolManager), initialCap);
    }

}

contract SetPoolManagerCapSuccessTests is TestBase {

    function test_setPoolManagerCap_success_calledByStrategyDelegate() external {
        uint256 cap = 1_000;

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.PoolManagerCapSet(poolManager, cap);

        setPoolManagerCap(poolManager, cap);

        assertEq(strategyManager.poolManagerCapOf(poolManager), cap);
    }

    function test_setPoolManagerCap_success_calledByOperationalAdmin() external {
        uint256 cap = 1_000;

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.PoolManagerCapSet(poolManager, cap);

        vm.prank(operationalAdmin);
        strategyManager.setPoolManagerCap(poolManager, cap);

        assertEq(strategyManager.poolManagerCapOf(poolManager), cap);
    }

    function test_setPoolManagerCap_success_calledByNonAdminWhenNotConfigured() external {
        uint256 cap = 1_000;

        strategyManager.__setConfigured(false);

        assertEq(strategyManager.configured(),                  false);
        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.PoolManagerCapSet(poolManager, cap);

        strategyManager.setPoolManagerCap(poolManager, cap);

        assertEq(strategyManager.configured(),                  false);
        assertEq(strategyManager.poolManagerCapOf(poolManager), cap);
    }

    function test_setPoolManagerCap_success_calledByNonAdminWhenNotConfigured_thenAdminUpdatesAfterConfigured() external {
        uint256 initialCap = 1_000;
        uint256 updatedCap = 500;

        strategyManager.__setConfigured(false);

        assertEq(strategyManager.configured(),                  false);
        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.PoolManagerCapSet(poolManager, initialCap);

        strategyManager.setPoolManagerCap(poolManager, initialCap);

        assertEq(strategyManager.configured(),                  false);
        assertEq(strategyManager.poolManagerCapOf(poolManager), initialCap);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerConfigurationComplete();

        strategyManager.completeConfiguration();

        assertEq(strategyManager.configured(),                  true);
        assertEq(strategyManager.poolManagerCapOf(poolManager), initialCap);

        vm.expectEmit();
        emit IMapleStrategyManager.PoolManagerCapSet(poolManager, updatedCap);

        setPoolManagerCap(poolManager, updatedCap);

        assertEq(strategyManager.configured(),                  true);
        assertEq(strategyManager.poolManagerCapOf(poolManager), updatedCap);
    }

    function test_setPoolManagerCap_success_max_calledByStrategyDelegate() external {
        uint256 cap = type(uint256).max;

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.PoolManagerCapSet(poolManager, cap);

        setPoolManagerCap(poolManager, cap);

        assertEq(strategyManager.poolManagerCapOf(poolManager), cap);
    }

    function test_setPoolManagerCap_success_update_calledByStrategyDelegate() external {
        uint256 initialCap = 1_000;
        uint256 updatedCap = 500;

        setPoolManagerCap(poolManager, initialCap);

        assertEq(strategyManager.poolManagerCapOf(poolManager), initialCap);

        setPoolManagerCap(poolManager, updatedCap);

        assertEq(strategyManager.poolManagerCapOf(poolManager), updatedCap);
    }

    function test_setPoolManagerCap_success_updateMultiplePoolManagers_calledByStrategyDelegate() external {
        address poolManager2 = address(new MockPoolManager());

        MockPoolManager(poolManager2).__setFactory(poolManagerFactory);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager2, true);

        uint256 poolManagerInitialCap  = 1_000;
        uint256 poolManagerUpdatedCap  = 500;
        uint256 poolManager2InitialCap = 2_000;
        uint256 poolManager2UpdatedCap = 750;

        setPoolManagerCap(poolManager, poolManagerInitialCap);
        setPoolManagerCap(poolManager2, poolManager2InitialCap);

        assertEq(strategyManager.poolManagerCapOf(poolManager),  poolManagerInitialCap);
        assertEq(strategyManager.poolManagerCapOf(poolManager2), poolManager2InitialCap);

        setPoolManagerCap(poolManager, poolManagerUpdatedCap);

        assertEq(strategyManager.poolManagerCapOf(poolManager),  poolManagerUpdatedCap);
        assertEq(strategyManager.poolManagerCapOf(poolManager2), poolManager2InitialCap);

        setPoolManagerCap(poolManager2, poolManager2UpdatedCap);

        assertEq(strategyManager.poolManagerCapOf(poolManager),  poolManagerUpdatedCap);
        assertEq(strategyManager.poolManagerCapOf(poolManager2), poolManager2UpdatedCap);
    }

    function test_setPoolManagerCap_success_zero_calledByStrategyDelegate() external {
        setPoolManagerCap(poolManager, 1);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 1);

        vm.expectEmit();
        emit IMapleStrategyManager.PoolManagerCapSet(poolManager, 0);

        setPoolManagerCap(poolManager, 0);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
    }

    function test_setPoolManagerCap_success_zero_invalidPMFactory_calledByStrategyDelegate() external {
        setPoolManagerCap(poolManager, 1);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 1);

        MockGlobals(globals).__setIsInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.expectEmit();
        emit IMapleStrategyManager.PoolManagerCapSet(poolManager, 0);

        setPoolManagerCap(poolManager, 0);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
    }

    function test_setPoolManagerCap_success_zero_invalidPM_calledByStrategyDelegate() external {
        setPoolManagerCap(poolManager, 1);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 1);

        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager, false);

        vm.expectEmit();
        emit IMapleStrategyManager.PoolManagerCapSet(poolManager, 0);

        setPoolManagerCap(poolManager, 0);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
    }

}
