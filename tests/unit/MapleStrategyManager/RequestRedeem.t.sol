// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import {
    MockGlobals,
    MockPoolManager,
    MockStrategy
} from "../../utils/Mocks.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract RequestRedeemFailureTests is TestBase {

    function test_requestRedeem_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.requestRedeem.selector, true);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PAUSED");
        strategyManager.requestRedeem(poolManager, 1);
    }

    function test_requestRedeem_revert_reentrancy() external {
        strategyManager.__setLocked(2);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:LOCKED");
        strategyManager.requestRedeem(poolManager, 1);
    }

    function test_requestRedeem_revert_notAuthorized() external {
        vm.expectRevert("MSM:NOT_AUTHORIZED");
        strategyManager.requestRedeem(poolManager, 1);
    }

    function test_requestRedeem_revert_zeroShares() external {
        vm.prank(liquidityBot);
        vm.expectRevert("MSM:RR:ZERO_SHARES");
        strategyManager.requestRedeem(poolManager, 0);
    }

    function test_requestRedeem_revert_insufficientShares() external {
        vm.prank(liquidityBot);
        vm.expectRevert("MSM:RR:INSUFFICIENT_SHARES");
        strategyManager.requestRedeem(poolManager, 1);
    }

    function test_requestRedeem_revert_insufficientShares_exceedsRemainingAfterPending() external {
        strategyManager.__setSharesOf(poolManager, 10);

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, 6);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:RR:INSUFFICIENT_SHARES");
        strategyManager.requestRedeem(poolManager, 5);
    }

}

contract RequestRedeemSuccessTests is TestBase {

    function test_requestRedeem_success_calledByLiquidityRouter() external {
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

        uint256 sharesToRedeem = 5;

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionRequested(poolManager, sharesToRedeem);

        vm.prank(liquidityRouter);
        strategyManager.requestRedeem(poolManager, sharesToRedeem);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesToRedeem);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesToRedeem);
    }

    function test_requestRedeem_success_calledByStrategyDelegate() external {
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

        uint256 sharesToRedeem = 5;

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionRequested(poolManager, sharesToRedeem);

        vm.prank(strategyDelegate);
        strategyManager.requestRedeem(poolManager, sharesToRedeem);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesToRedeem);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesToRedeem);
    }

    function test_requestRedeem_success_partial() external {
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

        uint256 sharesToRedeem = 5;

        vm.expectEmit();
        emit IMapleStrategyManager.RedemptionRequested(poolManager, sharesToRedeem);

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, sharesToRedeem);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    sharesToRedeem);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), sharesToRedeem);
    }

    function test_requestRedeem_success_full() external {
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

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, totalShares);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    totalShares);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), totalShares);
    }

    function test_requestRedeem_success_multipleRequests_sumToFull() external {
        uint256 totalAum    = 100;
        uint256 totalShares = 10;

        setStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });
        strategyManager.__setSharesOf(poolManager, totalShares);

        assertEq(strategyManager.totalPendingShares(),         0);
        assertEq(strategyManager.pendingSharesOf(poolManager), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Make first request                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 firstRequest = 3;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, firstRequest);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    firstRequest);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), firstRequest);

        /**********************************************************************************************************************************/
        /*** Step 2: Make second request                                                                                                ***/
        /**********************************************************************************************************************************/

        uint256 secondRequest = 4;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, secondRequest);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    firstRequest + secondRequest);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), firstRequest + secondRequest);

        /**********************************************************************************************************************************/
        /*** Step 3: Make third request                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 thirdRequest = 3;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, thirdRequest);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    totalShares);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), totalShares);
    }

    function test_requestRedeem_success_multiplePoolManagers() external {
        address poolManager1 = address(new MockPoolManager());
        address poolManager2 = address(new MockPoolManager());

        uint256 totalAum    = 300;
        uint256 totalShares = 30;

        uint256 pm1SharesHeld = 10;
        uint256 pm2SharesHeld = 20;

        uint256 pm1Assets = 100;
        uint256 pm2Assets = 200;

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

        uint256 pm1Request = 4;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager1, pm1Request);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pm1Request);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1Request);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager2), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Second pool manager requests redemption                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 pm2Request = 5;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager2, pm2Request);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    pm1Request + pm2Request);

        assertEq(strategyManager.sharesOf(poolManager1),        pm1SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager1),        pm1Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager1), pm1Request);

        assertEq(strategyManager.sharesOf(poolManager2),        pm2SharesHeld);
        assertEq(strategyManager.assetsOf(poolManager2),        pm2Assets);
        assertEq(strategyManager.pendingSharesOf(poolManager2), pm2Request);
    }

    function test_requestRedeem_success_strategyHasLoss() external {
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

        /**********************************************************************************************************************************/
        /*** Step 1: Make first request                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 firstRequest = 3;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, firstRequest);

        assertEq(strategyManager.assetsUnderManagement(), totalAum);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    firstRequest);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAum);
        assertEq(strategyManager.pendingSharesOf(poolManager), firstRequest);

        /**********************************************************************************************************************************/
        /*** Step 2: Strategy incurs a loss                                                                                             ***/
        /**********************************************************************************************************************************/

        uint256 totalAumAfterLoss = 50;

        MockStrategy(underlyingStrategy).__setAssetsUnderManagement(totalAumAfterLoss);

        assertEq(strategyManager.assetsUnderManagement(), totalAumAfterLoss);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    firstRequest);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAumAfterLoss);
        assertEq(strategyManager.pendingSharesOf(poolManager), firstRequest);

        /**********************************************************************************************************************************/
        /*** Step 3: Make second request                                                                                                ***/
        /**********************************************************************************************************************************/

        uint256 secondRequest = 4;

        vm.prank(liquidityBot);
        strategyManager.requestRedeem(poolManager, secondRequest);

        assertEq(strategyManager.assetsUnderManagement(), totalAumAfterLoss);
        assertEq(strategyManager.totalShares(),           totalShares);
        assertEq(strategyManager.totalPendingShares(),    firstRequest + secondRequest);

        assertEq(strategyManager.sharesOf(poolManager),        totalShares);
        assertEq(strategyManager.assetsOf(poolManager),        totalAumAfterLoss);
        assertEq(strategyManager.pendingSharesOf(poolManager), firstRequest + secondRequest);
    }

}
