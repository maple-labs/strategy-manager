// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals, MockPoolManager, MockPoolManagerFactory, MockStrategy } from "../../utils/Mocks.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract MulticallFailureTests is TestBase {

    bytes[] calls;

    function test_multicall_revert_paused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.setPoolManagerCap.selector, true);

        calls.push(abi.encodeCall(MapleStrategyManager.setPoolManagerCap, (poolManager, 1)));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        strategyManager.multicall(calls);
    }

    function test_multicall_revert_reentrancy() external {
        strategyManager.__setLocked(2);

        calls.push(abi.encodeCall(MapleStrategyManager.requestRedeem, (poolManager, 1)));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:LOCKED");
        strategyManager.multicall(calls);
    }

    function test_multicall_revert_notFactory() external {
        calls.push(abi.encodeCall(MapleStrategyManager.setImplementation, (address(1))));

        vm.expectRevert("MSM:NOT_FACTORY");
        strategyManager.multicall(calls);
    }

    function test_multicall_revert_notAdmin() external {
        calls.push(abi.encodeCall(MapleStrategyManager.setPoolManagerCap, (poolManager, 1)));

        vm.expectRevert("MSM:NOT_ADMIN");
        strategyManager.multicall(calls);
    }

    function test_multicall_revert_notOperator() external {
        calls.push(abi.encodeCall(MapleStrategyManager.fundStrategyManager, (poolManager, 1, "")));

        vm.expectRevert("MSM:NOT_OPERATOR");
        strategyManager.multicall(calls);
    }

    function test_multicall_revert_notOperatorOrPoolDelegate() external {
        calls.push(abi.encodeCall(MapleStrategyManager.requestRedeem, (poolManager, 1)));

        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        strategyManager.multicall(calls);
    }

    function test_multicall_revert_notSecurityAdmin() external {
        calls.push(abi.encodeCall(MapleStrategyManager.upgrade, (1, "")));

        vm.expectRevert("MSM:U:NOT_AUTHORIZED");
        strategyManager.multicall(calls);
    }

    function test_multicall_revert_invalidPoolManager() external {
        address invalidPoolManager = address(new MockPoolManager());

        calls.push(abi.encodeCall(MapleStrategyManager.setPoolManagerCap, (invalidPoolManager, 1)));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:SPMC:INVALID_PM");
        strategyManager.multicall(calls);
    }

    function test_multicall_revert_emptyRevert() external {
        calls.push("12345678");

        vm.prank(strategyDelegate);
        vm.expectRevert();
        strategyManager.multicall(calls);
    }

    function test_multicall_revert_atomicRollback() external {
        calls.push(abi.encodeCall(MapleStrategyManager.setPoolManagerCap, (poolManager, 1_000)));
        calls.push(abi.encodeCall(MapleStrategyManager.setPoolManagerCap, (poolManager, 1_000)));

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:SPMC:NO_CHANGE");
        strategyManager.multicall(calls);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
    }

}

contract MulticallSuccessTests is TestBase {

    bytes[] calls;

    function test_multicall_success_empty() external {
        vm.prank(strategyDelegate);
        strategyManager.multicall(calls);
    }

    function test_multicall_success_single() external {
        calls.push(abi.encodeCall(MapleStrategyManager.setPoolManagerCap, (poolManager, 1_000)));

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        vm.prank(operationalAdmin);
        strategyManager.multicall(calls);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 1_000);
    }

    function test_multicall_success_repeat() external {
        address poolManager2 = address(new MockPoolManager());

        MockPoolManager(poolManager2).__setFactory(poolManagerFactory);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager2, true);

        calls.push(abi.encodeCall(MapleStrategyManager.setPoolManagerCap, (poolManager, 1_000)));
        calls.push(abi.encodeCall(MapleStrategyManager.setPoolManagerCap, (poolManager2, 2_000)));

        assertEq(strategyManager.poolManagerCapOf(poolManager),  0);
        assertEq(strategyManager.poolManagerCapOf(poolManager2), 0);

        vm.prank(strategyDelegate);
        strategyManager.multicall(calls);

        assertEq(strategyManager.poolManagerCapOf(poolManager),  1_000);
        assertEq(strategyManager.poolManagerCapOf(poolManager2), 2_000);
    }

    function test_multicall_success_mixed() external {
        address newStrategyDelegate = makeAddr("newStrategyDelegate");

        calls.push(abi.encodeCall(MapleStrategyManager.setPoolManagerCap, (poolManager, 1_000)));
        calls.push(abi.encodeCall(MapleStrategyManager.setPendingStrategyDelegate, (newStrategyDelegate)));

        vm.prank(operationalAdmin);
        strategyManager.multicall(calls);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 1_000);
        assertEq(strategyManager.pendingStrategyDelegate(),     newStrategyDelegate);
    }

    function test_multicall_success_sequential() external {
        strategyManager.__setSharesOf(poolManager, 1_000);

        calls.push(abi.encodeCall(MapleStrategyManager.requestRedeem, (poolManager, 500)));
        calls.push(abi.encodeCall(MapleStrategyManager.cancelRedemption, (poolManager, 499)));

        vm.prank(strategyDelegate);
        strategyManager.multicall(calls);

        assertEq(strategyManager.pendingSharesOf(poolManager), 1);
        assertEq(strategyManager.totalPendingShares(),         1);
    }

    function test_multicall_success_unconfigured() external {
        uint256 bootstrapAssets          = 1e6;
        uint256 bootstrapDepositedAssets = bootstrapAssets / 3;

        address unpermissionedCaller = makeAddr("randomer");

        address newUnderlyingStrategy = address(new MockStrategy());

        MockStrategy(newUnderlyingStrategy).__setFundsAsset(address(asset));
        MockStrategy(newUnderlyingStrategy).__setFundUnderlyingStrategyReturn(bootstrapDepositedAssets);

        uint256 poolManagerCap       = 1_000e6;
        uint256 strategyLiquidityCap = 5_000e6;

        strategyManager.__setConfigured(false);

        calls.push(abi.encodeCall(MapleStrategyManager.setUnderlyingStrategy, (newUnderlyingStrategy)));
        calls.push(abi.encodeCall(MapleStrategyManager.setPoolManagerCap, (poolManager, poolManagerCap)));
        calls.push(abi.encodeCall(MapleStrategyManager.setStrategyLiquidityCap, (strategyLiquidityCap)));
        calls.push(abi.encodeCall(MapleStrategyManager.completeConfiguration, (bootstrapAssets, "")));

        assertEq(strategyManager.underlyingStrategy(),          underlyingStrategy);
        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
        assertEq(strategyManager.strategyLiquidityCap(),        0);
        assertEq(strategyManager.configured(),                  false);

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);
        assertEq(strategyManager.sharesOf(address(0)),    0);

        vm.prank(unpermissionedCaller);
        strategyManager.multicall(calls);

        assertEq(strategyManager.underlyingStrategy(),          newUnderlyingStrategy);
        assertEq(strategyManager.poolManagerCapOf(poolManager), poolManagerCap);
        assertEq(strategyManager.strategyLiquidityCap(),        strategyLiquidityCap);
        assertEq(strategyManager.configured(),                  true);

        assertEq(strategyManager.assetsUnderManagement(), bootstrapDepositedAssets);
        assertEq(strategyManager.totalShares(),           bootstrapDepositedAssets);
        assertEq(strategyManager.sharesOf(address(0)),    bootstrapDepositedAssets);
    }

}
