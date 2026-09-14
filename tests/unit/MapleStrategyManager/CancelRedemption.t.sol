// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import {
    MockGlobals,
    MockPoolManager,
    MockPoolManagerFactory,
    MockStrategy
} from "../../utils/Mocks.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract CancelRedemptionFailureTests is TestBase {

    function test_cancelRedemption_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.cancelRedemption.selector, true);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PAUSED");
        strategyManager.cancelRedemption(poolManager, 1);
    }

    function test_cancelRedemption_revert_reentrancy() external {
        strategyManager.__setLocked(2);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:LOCKED");
        strategyManager.cancelRedemption(poolManager, 1);
    }

    function test_cancelRedemption_revert_notAuthorized() external {
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        strategyManager.cancelRedemption(poolManager, 1);
    }

    function test_cancelRedemption_revert_impairment_liquidityBot() external {
        MockStrategy(underlyingStrategy).__setImpairedAssets(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        strategyManager.cancelRedemption(poolManager, 1);
    }

    function test_cancelRedemption_revert_impairment_liquidityRouter() external {
        MockStrategy(underlyingStrategy).__setImpairedAssets(1);

        vm.prank(liquidityRouter);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        strategyManager.cancelRedemption(poolManager, 1);
    }

    function test_cancelRedemption_revert_calledByOperationalAdmin() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        strategyManager.cancelRedemption(poolManager, 1);
    }

    function test_cancelRedemption_revert_notPoolManagerFactory() external {
        address otherFactory     = address(new MockPoolManagerFactory());
        address otherPoolManager = address(new MockPoolManager());

        MockPoolManager(otherPoolManager).__setFactory(otherFactory);
        MockPoolManagerFactory(otherFactory).__setIsInstance(otherPoolManager, true);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:CR:INVALID_PM");
        strategyManager.cancelRedemption(otherPoolManager, 1);
    }

    function test_cancelRedemption_revert_invalidPoolManagerInstance() external {
        address otherPoolManager = address(new MockPoolManager());

        MockPoolManager(otherPoolManager).__setFactory(poolManagerFactory);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:CR:INVALID_PM");
        strategyManager.cancelRedemption(otherPoolManager, 1);
    }

    function test_cancelRedemption_revert_wrongPoolDelegate() external {
        address otherPoolManager  = address(new MockPoolManager());
        address otherPoolDelegate = makeAddr("otherPoolDelegate");

        MockPoolManager(otherPoolManager).__setFactory(poolManagerFactory);
        MockPoolManager(otherPoolManager).__setPoolDelegate(otherPoolDelegate);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(otherPoolManager, true);

        vm.prank(poolDelegate);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        strategyManager.cancelRedemption(otherPoolManager, 1);
    }

    function test_cancelRedemption_revert_zeroShares() external {
        vm.prank(liquidityBot);
        vm.expectRevert("MSM:CR:ZERO_SHARES");
        strategyManager.cancelRedemption(poolManager, 0);
    }

    function test_cancelRedemption_revert_insufficientShares() external {
        vm.prank(liquidityBot);
        vm.expectRevert("MSM:CR:INSUFFICIENT_SHARES");
        strategyManager.cancelRedemption(poolManager, 1);
    }

    function test_cancelRedemption_revert_insufficientShares_exceedsPending() external {
        strategyManager.__setPendingSharesOf(poolManager, 5);
        strategyManager.__setTotalPendingShares(5);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:CR:INSUFFICIENT_SHARES");
        strategyManager.cancelRedemption(poolManager, 6);
    }

}

contract CancelRedemptionSuccessTests is TestBase {

    function test_cancelRedemption_success_partial_calledByLiquidityRouter() external {
        uint256 totalAum      = 100;
        uint256 totalShares   = 10;
        uint256 pendingShares = 6;

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

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, pendingShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares);

        /**********************************************************************************************************************************/
        /*** Step 2: Cancel redemption                                                                                                  ***/
        /**********************************************************************************************************************************/

        uint256 sharesToCancel = 4;

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionCancelled(poolManager, sharesToCancel);

        vm.prank(liquidityRouter);
        strategyManager.cancelRedemption(poolManager, sharesToCancel);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares - sharesToCancel);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares - sharesToCancel);
    }

    function test_cancelRedemption_success_partial_calledByStrategyDelegate() external {
        uint256 totalAum      = 100;
        uint256 totalShares   = 10;
        uint256 pendingShares = 6;

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

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, pendingShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares);

        /**********************************************************************************************************************************/
        /*** Step 2: Cancel redemption                                                                                                  ***/
        /**********************************************************************************************************************************/

        uint256 sharesToCancel = 4;
        uint256 impairedAssets = 23;

        // NOTE: Strategy delegate can cancel redemptions even during impairments.
        MockStrategy(underlyingStrategy).__setImpairedAssets(impairedAssets);
        MockStrategy(underlyingStrategy).__setUnrealizedLosses(impairedAssets);

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionCancelled(poolManager, sharesToCancel);

        vm.prank(strategyDelegate);
        strategyManager.cancelRedemption(poolManager, sharesToCancel);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares - sharesToCancel);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares - sharesToCancel);
    }

    function test_cancelRedemption_success_partial_calledByLiquidityBot() external {
        uint256 totalAum      = 100;
        uint256 totalShares   = 10;
        uint256 pendingShares = 6;

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

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, pendingShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares);

        /**********************************************************************************************************************************/
        /*** Step 2: Cancel redemption                                                                                                  ***/
        /**********************************************************************************************************************************/

        uint256 sharesToCancel = 4;

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionCancelled(poolManager, sharesToCancel);

        vm.prank(liquidityBot);
        strategyManager.cancelRedemption(poolManager, sharesToCancel);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares - sharesToCancel);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares - sharesToCancel);
    }

    function test_cancelRedemption_success_partial_calledByPoolDelegate() external {
        uint256 totalAum      = 100;
        uint256 totalShares   = 10;
        uint256 pendingShares = 6;

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

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        strategyManager.requestRedeem(poolManager, pendingShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares);

        /**********************************************************************************************************************************/
        /*** Step 2: Cancel redemption                                                                                                  ***/
        /**********************************************************************************************************************************/

        uint256 sharesToCancel = 4;
        uint256 impairedAssets = 23;

        // NOTE: Pool delegate can cancel redemptions even during impairments.
        MockStrategy(underlyingStrategy).__setImpairedAssets(impairedAssets);
        MockStrategy(underlyingStrategy).__setUnrealizedLosses(impairedAssets);

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionCancelled(poolManager, sharesToCancel);

        vm.prank(poolDelegate);
        strategyManager.cancelRedemption(poolManager, sharesToCancel);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares - sharesToCancel);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares - sharesToCancel);
    }

    function test_cancelRedemption_success_full() external {
        uint256 totalAum      = 100;
        uint256 totalShares   = 10;
        uint256 pendingShares = 6;

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

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, pendingShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares);

        /**********************************************************************************************************************************/
        /*** Step 2: Cancel redemption                                                                                                  ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.cancelRedemption(poolManager, pendingShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
    }

    function test_cancelRedemption_success_multipleCancellations_sumToFull() external {
        uint256 totalAum      = 100;
        uint256 totalShares   = 10;
        uint256 pendingShares = 10;

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

        /**********************************************************************************************************************************/
        /*** Step 1: Request redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, pendingShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares);

        /**********************************************************************************************************************************/
        /*** Step 2: Cancel first portion                                                                                               ***/
        /**********************************************************************************************************************************/

        uint256 firstCancel = 3;

        vm.prank(liquidityBot);
        strategyManager.cancelRedemption(poolManager, firstCancel);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares - firstCancel);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares - firstCancel);

        /**********************************************************************************************************************************/
        /*** Step 3: Cancel second portion                                                                                              ***/
        /**********************************************************************************************************************************/

        uint256 secondCancel = 4;

        vm.prank(liquidityBot);
        strategyManager.cancelRedemption(poolManager, secondCancel);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pendingShares - firstCancel - secondCancel);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), pendingShares - firstCancel - secondCancel);

        /**********************************************************************************************************************************/
        /*** Step 4: Cancel third portion                                                                                               ***/
        /**********************************************************************************************************************************/

        uint256 thirdCancel = 3;

        vm.prank(liquidityBot);
        strategyManager.cancelRedemption(poolManager, thirdCancel);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);
    }

    function test_cancelRedemption_success_multiplePoolManagers() external {
        address poolManager1 = address(new MockPoolManager());
        address poolManager2 = address(new MockPoolManager());

        MockPoolManager(poolManager1).__setFactory(poolManagerFactory);
        MockPoolManager(poolManager2).__setFactory(poolManagerFactory);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager1, true);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager2, true);

        uint256 totalAum    = 300;
        uint256 totalShares = 30;

        uint256 pm1SharesHeld = 10;
        uint256 pm2SharesHeld = 20;

        uint256 pm1Assets = 100;
        uint256 pm2Assets = 200;

        uint256 pm1Pending = 4;
        uint256 pm2Pending = 5;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager1, pm1SharesHeld);
        strategyManager.__setSharesOf(poolManager2, pm2SharesHeld);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    0);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), 0);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager2), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: First pool manager requests redemption                                                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager1, pm1Pending);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pm1Pending);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1Pending);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager2), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Second pool manager requests redemption                                                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager2, pm2Pending);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pm1Pending + pm2Pending);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1Pending);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager2), pm2Pending);

        /**********************************************************************************************************************************/
        /*** Step 3: First pool manager cancels                                                                                         ***/
        /**********************************************************************************************************************************/

        uint256 pm1Cancel = 2;

        vm.prank(liquidityBot);
        strategyManager.cancelRedemption(poolManager1, pm1Cancel);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pm1Pending + pm2Pending - pm1Cancel);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1Pending - pm1Cancel);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager2), pm2Pending);

        /**********************************************************************************************************************************/
        /*** Step 4: Second pool manager cancels                                                                                        ***/
        /**********************************************************************************************************************************/

        uint256 pm2Cancel = 3;

        vm.prank(liquidityBot);
        strategyManager.cancelRedemption(poolManager2, pm2Cancel);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pm1Pending + pm2Pending - pm1Cancel - pm2Cancel);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1Pending - pm1Cancel);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager2), pm2Pending - pm2Cancel);
    }

}
