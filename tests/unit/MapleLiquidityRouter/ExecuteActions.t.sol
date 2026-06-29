// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Action, ActionType, IMapleLiquidityRouter } from "../../../contracts/interfaces/IMapleLiquidityRouter.sol";

import { MapleLiquidityRouter } from "../../../contracts/MapleLiquidityRouter.sol";

import {
    MockGlobals,
    MockReentrantStrategyManager,
    MockStrategyManager,
    MockStrategyManagerFactory
} from "../../utils/Mocks.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract ExecuteActionsTestBase is TestBase {

    MapleLiquidityRouter       router;
    MockStrategyManager        mockStrategyManager;
    MockStrategyManagerFactory mockStrategyManagerFactory;

    function setUp() public override {
        super.setUp();

        router = new MapleLiquidityRouter(globals);

        mockStrategyManagerFactory = new MockStrategyManagerFactory();
        mockStrategyManager        = new MockStrategyManager();

        mockStrategyManager.__setFactory(address(mockStrategyManagerFactory));
        mockStrategyManagerFactory.__setIsInstance(address(mockStrategyManager), true);

        MockGlobals(globals).__setIsInstanceOf("LIQUIDITY_ROUTER_BOT",     liquidityBot,                        true);
        MockGlobals(globals).__setIsInstanceOf("LIQUIDITY_ROUTER",         address(router),                     true);
        MockGlobals(globals).__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(mockStrategyManagerFactory), true);
    }

    function _setMockStrategyManagerState(uint256 aum_, uint256 totalShares_) internal {
        mockStrategyManager.__setAssetsUnderManagement(aum_);
        mockStrategyManager.__setTotalShares(totalShares_);
    }

    function _cancelRedemptionAction(address strategyManager_, address poolManager_, uint256 shares_)
        internal pure returns (Action memory action_)
    {
        action_ = Action({
            actionType:      ActionType.CANCEL_REDEMPTION,
            strategyManager: strategyManager_,
            poolManager:     poolManager_,
            amount:          shares_,
            strategyData:    ""
        });
    }

    function _fundStrategyAction(address strategyManager_, address poolManager_, uint256 assets_, bytes memory strategyData_)
        internal pure returns (Action memory action_)
    {
        action_ = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: strategyManager_,
            poolManager:     poolManager_,
            amount:          assets_,
            strategyData:    strategyData_
        });
    }

    function _processRedemptionAction(address strategyManager_, address poolManager_, uint256 shares_, bytes memory strategyData_)
        internal pure returns (Action memory action_)
    {
        action_ = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: strategyManager_,
            poolManager:     poolManager_,
            amount:          shares_,
            strategyData:    strategyData_
        });
    }

    function _requestRedeemAction(address strategyManager_, address poolManager_, uint256 shares_)
        internal pure returns (Action memory action_)
    {
        action_ = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: strategyManager_,
            poolManager:     poolManager_,
            amount:          shares_,
            strategyData:    ""
        });
    }

}

contract ExecuteActionsFailureTests is ExecuteActionsTestBase {

    function test_executeActions_revert_functionPaused() external {
        Action[] memory actions = new Action[](1);

        actions[0] = _requestRedeemAction(address(mockStrategyManager), poolManager, 1);

        MockGlobals(globals).__setIsFunctionPaused(MapleLiquidityRouter.executeActions.selector, true);

        vm.prank(liquidityBot);
        vm.expectRevert("MLR:PAUSED");
        router.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_reentrancy() external {
        MockReentrantStrategyManager reentrantStrategyManager = new MockReentrantStrategyManager();

        reentrantStrategyManager.__setFactory(address(mockStrategyManagerFactory));
        reentrantStrategyManager.__setRouter(address(router));

        mockStrategyManagerFactory.__setIsInstance(address(reentrantStrategyManager), true);

        Action[] memory actions = new Action[](1);

        actions[0] = _requestRedeemAction(address(reentrantStrategyManager), poolManager, 1);

        vm.prank(liquidityBot);
        vm.expectRevert("MLR:LOCKED");
        router.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_notLiquidityBot() external {
        Action[] memory actions = new Action[](1);

        actions[0] = _requestRedeemAction(address(mockStrategyManager), poolManager, 1);

        vm.expectRevert("MLR:NOT_LIQUIDITY_BOT");
        router.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_expired() external {
        Action[] memory actions = new Action[](1);

        actions[0] = _requestRedeemAction(address(mockStrategyManager), poolManager, 1);

        vm.prank(liquidityBot);
        vm.expectRevert("MLR:EA:EXPIRED");
        router.executeActions(actions, block.timestamp - 1 seconds);
    }

    function test_executeActions_revert_empty() external {
        Action[] memory actions = new Action[](0);

        vm.prank(liquidityBot);
        vm.expectRevert("MLR:EA:EMPTY_ACTIONS");
        router.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_zeroStrategyManager() external {
        Action[] memory actions = new Action[](1);

        actions[0] = _fundStrategyAction(address(0), poolManager, 1, "");

        vm.prank(liquidityBot);
        vm.expectRevert("MLR:EA:ZERO_SM");
        router.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_zeroPoolManager() external {
        Action[] memory actions = new Action[](1);

        actions[0] = _fundStrategyAction(address(mockStrategyManager), address(0), 1, "");

        vm.prank(liquidityBot);
        vm.expectRevert("MLR:EA:ZERO_PM");
        router.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_invalidStrategyManagerFactory() external {
        MockStrategyManagerFactory invalidStrategyManagerFactory = new MockStrategyManagerFactory();
        MockStrategyManager        invalidStrategyManager        = new MockStrategyManager();

        invalidStrategyManager.__setFactory(address(invalidStrategyManagerFactory));

        Action[] memory actions = new Action[](1);

        actions[0] = _requestRedeemAction(address(invalidStrategyManager), poolManager, 1);

        vm.prank(liquidityBot);
        vm.expectRevert("MLR:EA:INVALID_SM_FACTORY");
        router.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_invalidStrategyManager() external {
        MockStrategyManager invalidStrategyManager = new MockStrategyManager();

        invalidStrategyManager.__setFactory(address(mockStrategyManagerFactory));

        Action[] memory actions = new Action[](1);

        actions[0] = _requestRedeemAction(address(invalidStrategyManager), poolManager, 1);

        vm.prank(liquidityBot);
        vm.expectRevert("MLR:EA:INVALID_SM");
        router.executeActions(actions, block.timestamp);
    }

}

contract ExecuteActionsSuccessTests is ExecuteActionsTestBase {

    function test_executeActions_success_fundStrategy() external {
        uint256 assets = 100;

        Action[] memory actions = new Action[](1);

        actions[0] = _fundStrategyAction(address(mockStrategyManager), poolManager, assets, "strategyData");

        vm.expectEmit(address(router));
        emit IMapleLiquidityRouter.ActionExecuted(
            0,
            ActionType.FUND_STRATEGY,
            address(mockStrategyManager),
            poolManager,
            assets
        );

        vm.prank(liquidityBot);
        router.executeActions(actions, block.timestamp);

        assertEq(mockStrategyManager.sharesOf(poolManager),        assets);
        assertEq(mockStrategyManager.assetsOf(poolManager),        assets);
        assertEq(mockStrategyManager.pendingSharesOf(poolManager), 0);
    }

    function test_executeActions_success_endToEnd() external {
        uint256 assetsToFund   = 100;
        uint256 sharesToRedeem = 40;

        Action[] memory actions = new Action[](3);

        actions[0] = _fundStrategyAction(address(mockStrategyManager), poolManager, assetsToFund, "strategyData");
        actions[1] = _requestRedeemAction(address(mockStrategyManager), poolManager, sharesToRedeem);
        actions[2] = _processRedemptionAction(address(mockStrategyManager), poolManager, sharesToRedeem, "strategyData");

        vm.expectEmit(address(router));
        emit IMapleLiquidityRouter.ActionExecuted(
            0,
            ActionType.FUND_STRATEGY,
            address(mockStrategyManager),
            poolManager,
            assetsToFund
        );

        vm.expectEmit(address(router));
        emit IMapleLiquidityRouter.ActionExecuted(
            1,
            ActionType.REQUEST_REDEEM,
            address(mockStrategyManager),
            poolManager,
            sharesToRedeem
        );

        vm.expectEmit(address(router));
        emit IMapleLiquidityRouter.ActionExecuted(
            2,
            ActionType.PROCESS_REDEMPTION,
            address(mockStrategyManager),
            poolManager,
            sharesToRedeem
        );

        vm.prank(liquidityBot);
        router.executeActions(actions, block.timestamp);

        assertEq(mockStrategyManager.assetsUnderManagement(),      assetsToFund - sharesToRedeem);
        assertEq(mockStrategyManager.totalShares(),                assetsToFund - sharesToRedeem);
        assertEq(mockStrategyManager.totalPendingShares(),         0);
        assertEq(mockStrategyManager.sharesOf(poolManager),        assetsToFund - sharesToRedeem);
        assertEq(mockStrategyManager.pendingSharesOf(poolManager), 0);
    }

    function test_executeActions_success_redemptionLifecycle() external {
        uint256 totalAum        = 100;
        uint256 totalShares     = 10;
        uint256 sharesRequested = 6;
        uint256 sharesCancelled = 1;
        uint256 sharesProcessed = 5;
        uint256 assetsReceived  = 50;

        _setMockStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });

        mockStrategyManager.__setSharesOf(poolManager, totalShares);

        Action[] memory actions = new Action[](3);

        actions[0] = _requestRedeemAction(address(mockStrategyManager), poolManager, sharesRequested);
        actions[1] = _cancelRedemptionAction(address(mockStrategyManager), poolManager, sharesCancelled);
        actions[2] = _processRedemptionAction(address(mockStrategyManager), poolManager, sharesProcessed, "strategyData");

        vm.expectEmit(address(router));
        emit IMapleLiquidityRouter.ActionExecuted(
            0,
            ActionType.REQUEST_REDEEM,
            address(mockStrategyManager),
            poolManager,
            sharesRequested
        );

        vm.expectEmit(address(router));
        emit IMapleLiquidityRouter.ActionExecuted(
            1,
            ActionType.CANCEL_REDEMPTION,
            address(mockStrategyManager),
            poolManager,
            sharesCancelled
        );

        vm.expectEmit(address(router));
        emit IMapleLiquidityRouter.ActionExecuted(
            2,
            ActionType.PROCESS_REDEMPTION,
            address(mockStrategyManager),
            poolManager,
            sharesProcessed
        );

        vm.prank(liquidityBot);
        router.executeActions(actions, block.timestamp);

        assertEq(mockStrategyManager.assetsUnderManagement(),      totalAum - assetsReceived);
        assertEq(mockStrategyManager.totalShares(),                totalShares - sharesProcessed);
        assertEq(mockStrategyManager.totalPendingShares(),         0);
        assertEq(mockStrategyManager.sharesOf(poolManager),        totalShares - sharesProcessed);
        assertEq(mockStrategyManager.pendingSharesOf(poolManager), 0);
    }

    function test_executeActions_success_redeemThenFundDifferentStrategy() external {
        uint256 totalAum       = 100;
        uint256 totalShares    = 10;
        uint256 sharesToRedeem = 5;
        uint256 assetsReceived = 50;
        uint256 assetsToFund   = 50;

        address secondPoolManager = makeAddr("secondPoolManager");

        _setMockStrategyManagerState({
            aum_:         totalAum,
            totalShares_: totalShares
        });

        mockStrategyManager.__setSharesOf(poolManager, totalShares);

        MockStrategyManager secondStrategyManager = new MockStrategyManager();

        secondStrategyManager.__setFactory(address(mockStrategyManagerFactory));
        mockStrategyManagerFactory.__setIsInstance(address(secondStrategyManager), true);

        Action[] memory actions = new Action[](3);

        actions[0] = _requestRedeemAction(address(mockStrategyManager), poolManager, sharesToRedeem);
        actions[1] = _processRedemptionAction(address(mockStrategyManager), poolManager, sharesToRedeem, "");
        actions[2] = _fundStrategyAction(address(secondStrategyManager), secondPoolManager, assetsToFund, "");

        vm.prank(liquidityBot);
        router.executeActions(actions, block.timestamp);

        assertEq(mockStrategyManager.assetsUnderManagement(),       totalAum - assetsReceived);
        assertEq(mockStrategyManager.pendingSharesOf(poolManager),  0);
        assertEq(secondStrategyManager.sharesOf(secondPoolManager), assetsToFund);
        assertEq(secondStrategyManager.assetsOf(secondPoolManager), assetsToFund);
    }

}
