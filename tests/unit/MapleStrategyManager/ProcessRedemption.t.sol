// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IUnderlyingStrategyLike } from "../../../contracts/interfaces/Interfaces.sol";
import { IMapleStrategyManager }   from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import {
    MockERC20,
    MockGlobals,
    MockPoolManager,
    MockPoolManagerFactory,
    MockStrategy
} from "../../utils/Mocks.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract ProcessRedemptionFailureTests is TestBase {

    function test_processRedemption_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.processRedemption.selector, true);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PAUSED");
        strategyManager.processRedemption(poolManager, 1, "");
    }

    function test_processRedemption_revert_reentrancy() external {
        strategyManager.__setLocked(2);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:LOCKED");
        strategyManager.processRedemption(poolManager, 1, "");
    }

    function test_processRedemption_revert_notAuthorized() external {
        vm.expectRevert("MSM:NOT_OPERATOR");
        strategyManager.processRedemption(poolManager, 1, "");
    }

    function test_processRedemption_revert_impairment_liquidityBot() external {
        MockStrategy(underlyingStrategy).__setImpairedAssets(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR");
        strategyManager.processRedemption(poolManager, 1, "");
    }

    function test_processRedemption_revert_impairment_liquidityRouter() external {
        MockStrategy(underlyingStrategy).__setImpairedAssets(1);

        vm.prank(liquidityRouter);
        vm.expectRevert("MSM:NOT_OPERATOR");
        strategyManager.processRedemption(poolManager, 1, "");
    }

    function test_processRedemption_revert_invalidPMFactory() external {
        address otherFactory     = address(new MockPoolManagerFactory());
        address otherPoolManager = address(new MockPoolManager());

        MockPoolManager(otherPoolManager).__setFactory(otherFactory);
        MockPoolManagerFactory(otherFactory).__setIsInstance(otherPoolManager, true);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PR:INVALID_PM");
        strategyManager.processRedemption(otherPoolManager, 1, "");
    }

    function test_processRedemption_revert_invalidPM() external {
        address otherPoolManager = address(new MockPoolManager());

        MockPoolManager(otherPoolManager).__setFactory(poolManagerFactory);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PR:INVALID_PM");
        strategyManager.processRedemption(otherPoolManager, 1, "");
    }

    function test_processRedemption_revert_zeroShares() external {
        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PR:ZERO_SHARES");
        strategyManager.processRedemption(poolManager, 0, "");
    }

    function test_processRedemption_revert_exceedsRequested() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 10;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        uint256 sharesRequested = 4;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PR:EXCEEDS_REQUESTED");
        strategyManager.processRedemption(poolManager, sharesRequested + 1, "");
    }

    function test_processRedemption_revert_zeroAssets() external {
        uint256 totalAum    = 1;
        uint256 totalShares = 3;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        uint256 sharesRequested = 1;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        strategyManager.processRedemption(poolManager, sharesRequested, "");
    }

    function test_processRedemption_revert_zeroAssets_totalLoss() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 100;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        uint256 sharesRequested = 50;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        MockStrategy(underlyingStrategy).__setAssetsUnderManagement(0);
        MockStrategy(underlyingStrategy).__setAvailableToWithdraw(0);

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.assetsOf(poolManager),   0);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        strategyManager.processRedemption(poolManager, sharesRequested, "");
    }

    function test_processRedemption_revert_zeroAssets_unrealizedLossesExceedAum() external {
        uint256 totalAum       = 100;
        uint256 totalShares    = 10;
        uint256 impairedAssets = 200;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });

        strategyManager.__setSharesOf(poolManager, totalShares);

        MockStrategy(underlyingStrategy).__setImpairedAssets(impairedAssets);
        MockStrategy(underlyingStrategy).__setUnrealizedLosses(impairedAssets);

        uint256 sharesRequested = 5;

        vm.prank(poolDelegate);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(),          totalAum);
        assertEq(strategyManager.availableToWithdraw(),            totalAum);
        assertEq(strategyManager.totalShares(),                    totalShares);
        assertEq(strategyManager.totalPendingShares(),             sharesRequested);
        assertEq(strategyManager.sharesOf(poolManager),            totalShares);
        assertEq(strategyManager.assetsOf(poolManager),            totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager),     sharesRequested);
        assertEq(strategyManager.unrealizedLossesOf(poolManager),  totalAum);
        assertEq(strategyManager.convertToExitAssets(totalShares), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        strategyManager.processRedemption(poolManager, sharesRequested, "");
    }

    function test_processRedemption_revert_notEnoughLiquidity() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 10;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        uint256 sharesRequested     = 5;
        uint256 assetsExpected      = 50;
        uint256 availableToWithdraw = assetsExpected - 1;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.availableToWithdraw(),   totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        MockStrategy(underlyingStrategy).__setAvailableToWithdraw(availableToWithdraw);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PR:NOT_ENOUGH_LIQUIDITY");
        strategyManager.processRedemption(poolManager, sharesRequested, "");
    }

}

contract ProcessRedemptionSuccessTests is TestBase {

    address pool1;
    address pool2;
    address poolManager1;
    address poolManager2;

    function setUp() public override {
        super.setUp();

        pool1 = makeAddr("pool1");
        pool2 = makeAddr("pool2");

        poolManager1 = address(new MockPoolManager());
        poolManager2 = address(new MockPoolManager());

        MockPoolManager(poolManager1).__setFactory(poolManagerFactory);
        MockPoolManager(poolManager2).__setFactory(poolManagerFactory);
        MockPoolManager(poolManager1).__setPool(pool1);
        MockPoolManager(poolManager2).__setPool(pool2);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager1, true);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager2, true);
    }

    function test_processRedemption_success_calledByLiquidityBot() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 10;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 sharesRequested = 5;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        /**********************************************************************************************************************************/
        /*** Step 2: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 assetsExpected = 50;

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, assetsExpected, "")));

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionProcessed(poolManager, sharesRequested, assetsExpected);

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager, sharesRequested, "");

        assertEq(strategyManager.assetsUnderManagement(), totalAum - assetsExpected);
        assertEq(strategyManager.totalShares(),           totalShares - sharesRequested);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares - sharesRequested);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum - assetsExpected);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), assetsExpected);
    }

    function test_processRedemption_success_calledByLiquidityRouter() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 10;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 sharesRequested = 5;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        /**********************************************************************************************************************************/
        /*** Step 2: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 assetsExpected = 50;

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, assetsExpected, "")));

        vm.prank(liquidityRouter);
        strategyManager.processRedemption(poolManager, sharesRequested, "");

        assertEq(strategyManager.assetsUnderManagement(), totalAum - assetsExpected);
        assertEq(strategyManager.totalShares(),           totalShares - sharesRequested);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares - sharesRequested);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum - assetsExpected);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), assetsExpected);
    }

    function test_processRedemption_success_calledByStrategyDelegate() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 10;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 sharesRequested = 5;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        /**********************************************************************************************************************************/
        /*** Step 2: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 assetsExpected = 50;

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, assetsExpected, "")));

        vm.prank(strategyDelegate);
        strategyManager.processRedemption(poolManager, sharesRequested, "");

        assertEq(strategyManager.assetsUnderManagement(), totalAum - assetsExpected);
        assertEq(strategyManager.totalShares(),           totalShares - sharesRequested);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares - sharesRequested);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum - assetsExpected);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), assetsExpected);
    }

    function test_processRedemption_success_partial_availableToWithdrawBelowAum() external {
        uint256 totalAum           = 100;
        uint256 totalShares        = 10;
        uint256 availableLiquidity = 50;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        MockStrategy(underlyingStrategy).__setAvailableToWithdraw(availableLiquidity);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.availableToWithdraw(),   availableLiquidity);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 sharesRequested = 7;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.availableToWithdraw(),   availableLiquidity);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        /**********************************************************************************************************************************/
        /*** Step 2: Process partial redemption                                                                                         ***/
        /**********************************************************************************************************************************/

        uint256 sharesProcessed = 3;
        uint256 assetsExpected  = 30;

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, assetsExpected, "")));

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager, sharesProcessed, "");

        assertEq(strategyManager.assetsUnderManagement(), totalAum - assetsExpected);
        assertEq(strategyManager.availableToWithdraw(),   availableLiquidity - assetsExpected);
        assertEq(strategyManager.totalShares(),           totalShares - sharesProcessed);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested - sharesProcessed);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares - sharesProcessed);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum - assetsExpected);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested - sharesProcessed);

        assertEq(MockERC20(asset).balanceOf(pool), assetsExpected);
    }

    function test_processRedemption_success_roundsDown() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 3;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 sharesRequested = 3;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        /**********************************************************************************************************************************/
        /*** Step 2: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 sharesProcessed = 1;
        uint256 assetsExpected  = 33;  // 1 * 100 / 3 = 33.33..., rounds down to 33.

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, assetsExpected, "")));

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionProcessed(poolManager, sharesProcessed, assetsExpected);

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager, sharesProcessed, "");

        assertEq(strategyManager.assetsUnderManagement(), totalAum - assetsExpected);
        assertEq(strategyManager.totalShares(),           totalShares - sharesProcessed);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested - sharesProcessed);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares - sharesProcessed);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum - assetsExpected);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested - sharesProcessed);

        assertEq(MockERC20(asset).balanceOf(pool), assetsExpected);
    }

    function test_processRedemption_success_usesExitAssets() external {
        uint256 totalAum       = 100;
        uint256 totalShares    = 10;
        uint256 impairedAssets = 20;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });

        strategyManager.__setSharesOf(poolManager, totalShares);

        MockStrategy(underlyingStrategy).__setImpairedAssets(impairedAssets);
        MockStrategy(underlyingStrategy).__setUnrealizedLosses(impairedAssets);

        assertEq(strategyManager.assetsUnderManagement(),          totalAum);
        assertEq(strategyManager.totalShares(),                    totalShares);
        assertEq(strategyManager.totalPendingShares(),             0);
        assertEq(strategyManager.sharesOf(poolManager),            totalShares);
        assertEq(strategyManager.assetsOf(poolManager),            totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager),     0);
        assertEq(strategyManager.unrealizedLossesOf(poolManager),  impairedAssets);
        assertEq(strategyManager.convertToExitAssets(totalShares), totalAum - impairedAssets);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 sharesRequested = 5;

        vm.prank(strategyDelegate);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(),          totalAum);
        assertEq(strategyManager.totalShares(),                    totalShares);
        assertEq(strategyManager.totalPendingShares(),             sharesRequested);
        assertEq(strategyManager.sharesOf(poolManager),            totalShares);
        assertEq(strategyManager.assetsOf(poolManager),            totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager),     sharesRequested);
        assertEq(strategyManager.unrealizedLossesOf(poolManager),  impairedAssets);
        assertEq(strategyManager.convertToExitAssets(totalShares), totalAum - impairedAssets);

        /**********************************************************************************************************************************/
        /*** Step 2: Process redemption at exit rate                                                                                    ***/
        /**********************************************************************************************************************************/

        uint256 assetsExpected = 40;  // 5 shares redeem against 80 exit assets with 10 total shares.

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, assetsExpected, "")));

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionProcessed(poolManager, sharesRequested, assetsExpected);

        vm.prank(strategyDelegate);
        strategyManager.processRedemption(poolManager, sharesRequested, "");

        assertEq(strategyManager.assetsUnderManagement(),                            totalAum - assetsExpected);
        assertEq(strategyManager.totalShares(),                                      totalShares - sharesRequested);
        assertEq(strategyManager.totalPendingShares(),                               0);
        assertEq(strategyManager.sharesOf(poolManager),                              totalShares - sharesRequested);
        assertEq(strategyManager.assetsOf(poolManager),                              totalAum - assetsExpected);
        assertEq(strategyManager.pendingSharesOf(poolManager),                       0);
        assertEq(strategyManager.unrealizedLossesOf(poolManager),                    impairedAssets);
        assertEq(strategyManager.convertToExitAssets(totalShares - sharesRequested), totalAum - assetsExpected - impairedAssets);

        assertEq(MockERC20(asset).balanceOf(pool), assetsExpected);
    }

    function test_processRedemption_success_full() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 10;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, totalShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    totalShares);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), totalShares);

        /**********************************************************************************************************************************/
        /*** Step 2: Process full redemption                                                                                            ***/
        /**********************************************************************************************************************************/

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, totalAum, "")));

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionProcessed(poolManager, totalShares, totalAum);

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager, totalShares, "");

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        0);
        assertEq(strategyManager.assetsOf(poolManager),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), totalAum);
    }

    function test_processRedemption_success_full_strategyHasLossAfterRequest() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 10;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 sharesRequested = 4;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        /**********************************************************************************************************************************/
        /*** Step 2: Strategy incurs a loss                                                                                             ***/
        /**********************************************************************************************************************************/

        uint256 totalAumAfterLoss = 50;

        MockStrategy(underlyingStrategy).__setAssetsUnderManagement(totalAumAfterLoss);

        /**********************************************************************************************************************************/
        /*** Step 3: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 assetsExpected = 20;

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, assetsExpected, "")));

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager, sharesRequested, "");

        assertEq(strategyManager.assetsUnderManagement(), totalAumAfterLoss - assetsExpected);
        assertEq(strategyManager.totalShares(),           totalShares - sharesRequested);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares - sharesRequested);
        assertEq(strategyManager.assetsOf(poolManager),        totalAumAfterLoss - assetsExpected);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), assetsExpected);

        /**********************************************************************************************************************************/
        /*** Step 4: Fully withdraw remaining shares                                                                                    ***/
        /**********************************************************************************************************************************/

        uint256 remainingShares = totalShares - sharesRequested;
        uint256 remainingAssets = totalAumAfterLoss - assetsExpected;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, remainingShares);

        assertEq(strategyManager.assetsUnderManagement(), remainingAssets);
        assertEq(strategyManager.totalShares(),           remainingShares);
        assertEq(strategyManager.totalPendingShares(),    remainingShares);

        assertEq(strategyManager.sharesOf(poolManager),        remainingShares);
        assertEq(strategyManager.assetsOf(poolManager),        remainingAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager), remainingShares);

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, remainingAssets, "")));

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager, remainingShares, "");

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        0);
        assertEq(strategyManager.assetsOf(poolManager),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), totalAumAfterLoss);
    }

    function test_processRedemption_success_strategyHasYieldAfterRequest() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 10;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 sharesRequested = 4;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesRequested);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesRequested);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesRequested);

        /**********************************************************************************************************************************/
        /*** Step 2: Strategy earns yield                                                                                               ***/
        /**********************************************************************************************************************************/

        uint256 totalAumAfterYield = 150;

        MockStrategy(underlyingStrategy).__setAssetsUnderManagement(totalAumAfterYield);
        MockStrategy(underlyingStrategy).__setAvailableToWithdraw(totalAumAfterYield);

        /**********************************************************************************************************************************/
        /*** Step 3: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 assetsExpected = 60;

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, assetsExpected, "")));

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager, sharesRequested, "");

        assertEq(strategyManager.assetsUnderManagement(), totalAumAfterYield - assetsExpected);
        assertEq(strategyManager.totalShares(),           totalShares - sharesRequested);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares - sharesRequested);
        assertEq(strategyManager.assetsOf(poolManager),        totalAumAfterYield - assetsExpected);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), assetsExpected);

        /**********************************************************************************************************************************/
        /*** Step 4: Fully withdraw remaining shares                                                                                    ***/
        /**********************************************************************************************************************************/

        uint256 remainingShares = totalShares - sharesRequested;
        uint256 remainingAssets = totalAumAfterYield - assetsExpected;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, remainingShares);

        assertEq(strategyManager.assetsUnderManagement(), remainingAssets);
        assertEq(strategyManager.totalShares(),           remainingShares);
        assertEq(strategyManager.totalPendingShares(),    remainingShares);

        assertEq(strategyManager.sharesOf(poolManager),        remainingShares);
        assertEq(strategyManager.assetsOf(poolManager),        remainingAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager), remainingShares);

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, remainingAssets, "")));

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager, remainingShares, "");

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        0);
        assertEq(strategyManager.assetsOf(poolManager),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        assertEq(MockERC20(asset).balanceOf(pool), totalAumAfterYield);
    }

    function test_processRedemption_success_afterPoolManagerCapRevoked() external {
        uint256 assetsToFund   = 100;
        uint256 sharesToRedeem = 100;

        setStrategyLiquidityCap(type(uint256).max);

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
        assertEq(strategyManager.assetsUnderManagement(),       0);
        assertEq(strategyManager.availableToWithdraw(),         0);
        assertEq(strategyManager.totalShares(),                 0);
        assertEq(strategyManager.totalPendingShares(),          0);

        assertEq(strategyManager.sharesOf(poolManager),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager),        0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Set pool manager cap                                                                                               ***/
        /**********************************************************************************************************************************/

        setPoolManagerCap(poolManager, type(uint256).max);

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), type(uint256).max);
        assertEq(strategyManager.assetsUnderManagement(),       0);
        assertEq(strategyManager.availableToWithdraw(),         0);
        assertEq(strategyManager.totalShares(),                 0);
        assertEq(strategyManager.totalPendingShares(),          0);

        assertEq(strategyManager.sharesOf(poolManager),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager),        0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund strategy manager                                                                                              ***/
        /**********************************************************************************************************************************/

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsToFund);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), type(uint256).max);
        assertEq(strategyManager.assetsUnderManagement(),       assetsToFund);
        assertEq(strategyManager.availableToWithdraw(),         assetsToFund);
        assertEq(strategyManager.totalShares(),                 assetsToFund);
        assertEq(strategyManager.totalPendingShares(),          0);

        assertEq(strategyManager.sharesOf(poolManager),        assetsToFund);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager),        assetsToFund);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 3: Revoke pool manager cap                                                                                            ***/
        /**********************************************************************************************************************************/

        setPoolManagerCap(poolManager, 0);

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
        assertEq(strategyManager.assetsUnderManagement(),       assetsToFund);
        assertEq(strategyManager.availableToWithdraw(),         assetsToFund);
        assertEq(strategyManager.totalShares(),                 assetsToFund);
        assertEq(strategyManager.totalPendingShares(),          0);

        assertEq(strategyManager.sharesOf(poolManager),        assetsToFund);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager),        assetsToFund);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 4: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesToRedeem);

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
        assertEq(strategyManager.assetsUnderManagement(),       assetsToFund);
        assertEq(strategyManager.availableToWithdraw(),         assetsToFund);
        assertEq(strategyManager.totalShares(),                 assetsToFund);
        assertEq(strategyManager.totalPendingShares(),          sharesToRedeem);

        assertEq(strategyManager.sharesOf(poolManager),        assetsToFund);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesToRedeem);
        assertEq(strategyManager.assetsOf(poolManager),        assetsToFund);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 5: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, assetsToFund, "")));

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionProcessed(poolManager, sharesToRedeem, assetsToFund);

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager, sharesToRedeem, "");

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
        assertEq(strategyManager.assetsUnderManagement(),       0);
        assertEq(strategyManager.availableToWithdraw(),         0);
        assertEq(strategyManager.totalShares(),                 0);
        assertEq(strategyManager.totalPendingShares(),          0);

        assertEq(strategyManager.sharesOf(poolManager),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager),        0);

        assertEq(MockERC20(asset).balanceOf(pool), assetsToFund);
    }

    function test_processRedemption_success_afterPoolManagerCapLowered() external {
        uint256 assetsToFund   = 100;
        uint256 cap            = 50;
        uint256 sharesToRedeem = 50;

        setStrategyLiquidityCap(type(uint256).max);

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
        assertEq(strategyManager.assetsUnderManagement(),       0);
        assertEq(strategyManager.availableToWithdraw(),         0);
        assertEq(strategyManager.totalShares(),                 0);
        assertEq(strategyManager.totalPendingShares(),          0);

        assertEq(strategyManager.sharesOf(poolManager),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager),        0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Set pool manager cap                                                                                               ***/
        /**********************************************************************************************************************************/

        setPoolManagerCap(poolManager, type(uint256).max);

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), type(uint256).max);
        assertEq(strategyManager.assetsUnderManagement(),       0);
        assertEq(strategyManager.availableToWithdraw(),         0);
        assertEq(strategyManager.totalShares(),                 0);
        assertEq(strategyManager.totalPendingShares(),          0);

        assertEq(strategyManager.sharesOf(poolManager),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager),        0);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund strategy manager                                                                                              ***/
        /**********************************************************************************************************************************/

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsToFund);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), type(uint256).max);
        assertEq(strategyManager.assetsUnderManagement(),       assetsToFund);
        assertEq(strategyManager.availableToWithdraw(),         assetsToFund);
        assertEq(strategyManager.totalShares(),                 assetsToFund);
        assertEq(strategyManager.totalPendingShares(),          0);

        assertEq(strategyManager.sharesOf(poolManager),        assetsToFund);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager),        assetsToFund);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 3: Lower pool manager cap                                                                                             ***/
        /**********************************************************************************************************************************/

        setPoolManagerCap(poolManager, cap);

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), cap);
        assertEq(strategyManager.assetsUnderManagement(),       assetsToFund);
        assertEq(strategyManager.availableToWithdraw(),         assetsToFund);
        assertEq(strategyManager.totalShares(),                 assetsToFund);
        assertEq(strategyManager.totalPendingShares(),          0);

        assertEq(strategyManager.sharesOf(poolManager),        assetsToFund);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager),        assetsToFund);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 4: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesToRedeem);

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), cap);
        assertEq(strategyManager.assetsUnderManagement(),       assetsToFund);
        assertEq(strategyManager.availableToWithdraw(),         assetsToFund);
        assertEq(strategyManager.totalShares(),                 assetsToFund);
        assertEq(strategyManager.totalPendingShares(),          sharesToRedeem);

        assertEq(strategyManager.sharesOf(poolManager),        assetsToFund);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesToRedeem);
        assertEq(strategyManager.assetsOf(poolManager),        assetsToFund);

        assertEq(MockERC20(asset).balanceOf(pool), 0);

        /**********************************************************************************************************************************/
        /*** Step 5: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.expectCall(underlyingStrategy, abi.encodeCall(MockStrategy.withdrawFromUnderlyingStrategy, (pool, sharesToRedeem, "")));

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionProcessed(poolManager, sharesToRedeem, sharesToRedeem);

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager, sharesToRedeem, "");

        assertEq(strategyManager.strategyLiquidityCap(),        type(uint256).max);
        assertEq(strategyManager.poolManagerCapOf(poolManager), cap);
        assertEq(strategyManager.assetsUnderManagement(),       assetsToFund - sharesToRedeem);
        assertEq(strategyManager.availableToWithdraw(),         assetsToFund - sharesToRedeem);
        assertEq(strategyManager.totalShares(),                 assetsToFund - sharesToRedeem);
        assertEq(strategyManager.totalPendingShares(),          0);

        assertEq(strategyManager.sharesOf(poolManager),        assetsToFund - sharesToRedeem);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager),        assetsToFund - sharesToRedeem);

        assertEq(MockERC20(asset).balanceOf(pool), sharesToRedeem);
    }

    function test_processRedemption_success_multiplePoolManagers() external {
        uint256 totalAum    = 300;
        uint256 totalShares = 30;

        uint256 pm1InitialShares = 10;
        uint256 pm2InitialShares = 20;

        uint256 pm1InitialAssets = 100;
        uint256 pm2InitialAssets = 200;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager1, pm1InitialShares);
        strategyManager.__setSharesOf(poolManager2, pm2InitialShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1InitialShares);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1InitialAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), 0);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2InitialShares);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2InitialAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager2), 0);

        assertEq(MockERC20(asset).balanceOf(pool1), 0);
        assertEq(MockERC20(asset).balanceOf(pool2), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: First pool manager requests redemption                                                                             ***/
        /**********************************************************************************************************************************/

        uint256 pm1InitialRequest = 4;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager1, pm1InitialRequest);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pm1InitialRequest);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1InitialShares);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1InitialAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1InitialRequest);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2InitialShares);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2InitialAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager2), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Second pool manager requests redemption                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 pm2InitialRequest = 5;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager2, pm2InitialRequest);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pm1InitialRequest + pm2InitialRequest);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1InitialShares);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1InitialAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1InitialRequest);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2InitialShares);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2InitialAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager2), pm2InitialRequest);

        /**********************************************************************************************************************************/
        /*** Step 3: Second pool manager processes redemption                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 pm2SharesProcessed = 2;
        uint256 pm2AssetsReceived  = 20;

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager2, pm2SharesProcessed, "");

        assertEq(strategyManager.assetsUnderManagement(), totalAum          - pm2AssetsReceived);
        assertEq(strategyManager.totalShares(),           totalShares       - pm2SharesProcessed);
        assertEq(strategyManager.totalPendingShares(),    pm1InitialRequest + pm2InitialRequest - pm2SharesProcessed);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1InitialShares);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1InitialAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1InitialRequest);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2InitialShares  - pm2SharesProcessed);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2InitialAssets  - pm2AssetsReceived);
        assertEq(strategyManager.pendingSharesOf(poolManager2), pm2InitialRequest - pm2SharesProcessed);

        assertEq(MockERC20(asset).balanceOf(pool1), 0);
        assertEq(MockERC20(asset).balanceOf(pool2), pm2AssetsReceived);

        /**********************************************************************************************************************************/
        /*** Step 4: First pool manager requests additional redemption                                                                  ***/
        /**********************************************************************************************************************************/

        uint256 pm1AdditionalRequest = pm1InitialShares - pm1InitialRequest;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager1, pm1AdditionalRequest);

        assertEq(strategyManager.assetsUnderManagement(), totalAum    - pm2AssetsReceived);
        assertEq(strategyManager.totalShares(),           totalShares - pm2SharesProcessed);

        assertEq(
            strategyManager.totalPendingShares(),
            pm1InitialRequest + pm2InitialRequest - pm2SharesProcessed + pm1AdditionalRequest
        );

        assertEq(strategyManager.sharesOf(poolManager1),        pm1InitialShares);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1InitialAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1InitialRequest + pm1AdditionalRequest);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2InitialShares  - pm2SharesProcessed);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2InitialAssets  - pm2AssetsReceived);
        assertEq(strategyManager.pendingSharesOf(poolManager2), pm2InitialRequest - pm2SharesProcessed);

        /**********************************************************************************************************************************/
        /*** Step 5: Second pool manager requests additional redemption                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 pm2AdditionalRequest = pm2InitialShares - pm2InitialRequest;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager2, pm2AdditionalRequest);

        assertEq(strategyManager.assetsUnderManagement(), totalAum    - pm2AssetsReceived);
        assertEq(strategyManager.totalShares(),           totalShares - pm2SharesProcessed);

        assertEq(
            strategyManager.totalPendingShares(),
            pm1InitialRequest + pm2InitialRequest - pm2SharesProcessed + pm1AdditionalRequest + pm2AdditionalRequest
        );

        assertEq(strategyManager.sharesOf(poolManager1),        pm1InitialShares);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1InitialAssets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1InitialRequest + pm1AdditionalRequest);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2InitialShares  - pm2SharesProcessed);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2InitialAssets  - pm2AssetsReceived);
        assertEq(strategyManager.pendingSharesOf(poolManager2), pm2InitialRequest - pm2SharesProcessed + pm2AdditionalRequest);

        /**********************************************************************************************************************************/
        /*** Step 6: First pool manager processes redemption                                                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager1, pm1InitialRequest + pm1AdditionalRequest, "");

        assertEq(strategyManager.assetsUnderManagement(), pm2InitialAssets  - pm2AssetsReceived);
        assertEq(strategyManager.totalShares(),           pm2InitialShares  - pm2SharesProcessed);
        assertEq(strategyManager.totalPendingShares(),    pm2InitialRequest - pm2SharesProcessed + pm2AdditionalRequest);

        assertEq(strategyManager.sharesOf(poolManager1),        0);
        assertEq(strategyManager.assetsOf(poolManager1),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager1), 0);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2InitialShares  - pm2SharesProcessed);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2InitialAssets  - pm2AssetsReceived);
        assertEq(strategyManager.pendingSharesOf(poolManager2), pm2InitialRequest - pm2SharesProcessed + pm2AdditionalRequest);

        assertEq(MockERC20(asset).balanceOf(pool1), pm1InitialAssets);
        assertEq(MockERC20(asset).balanceOf(pool2), pm2AssetsReceived);

        /**********************************************************************************************************************************/
        /*** Step 7: Second pool manager processes redemption                                                                           ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.processRedemption(poolManager2, pm2InitialRequest - pm2SharesProcessed + pm2AdditionalRequest, "");

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager1),        0);
        assertEq(strategyManager.assetsOf(poolManager1),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager1), 0);

        assertEq(strategyManager.sharesOf(poolManager2),        0);
        assertEq(strategyManager.assetsOf(poolManager2),        0);
        assertEq(strategyManager.pendingSharesOf(poolManager2), 0);

        assertEq(MockERC20(asset).balanceOf(pool1), pm1InitialAssets);
        assertEq(MockERC20(asset).balanceOf(pool2), pm2InitialAssets);
    }

}
