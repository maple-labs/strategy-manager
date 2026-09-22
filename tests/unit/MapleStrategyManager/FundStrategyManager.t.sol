// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { stdError } from "../../../modules/forge-std/src/StdError.sol";

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals, MockPoolManager, MockPoolManagerFactory, MockStrategy, MockStrategyFactory } from "../../utils/Mocks.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract FundStrategyManagerFailureTests is TestBase {

    function test_fundStrategyManager_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.fundStrategyManager.selector, true);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PAUSED");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_reentrancy() external {
        strategyManager.__setLocked(2);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:LOCKED");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_notAuthorized() external {
        vm.expectRevert("MSM:NOT_OPERATOR");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_impairment_liquidityBot() external {
        MockStrategy(underlyingStrategy).__setImpairedAssets(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_impairment_liquidityRouter() external {
        MockStrategy(underlyingStrategy).__setImpairedAssets(1);

        vm.prank(liquidityRouter);
        vm.expectRevert("MSM:NOT_OPERATOR");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_calledByOperationalAdmin() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("MSM:NOT_OPERATOR");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_notActive() external {
        strategyManager.__setActive(false);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:NOT_ACTIVE");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_zeroAssets() external {
        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:ZERO_ASSETS");
        strategyManager.fundStrategyManager(poolManager, 0, "");
    }

    function test_fundStrategyManager_revert_invalidPMFactory() external {
        address otherFactory     = address(new MockPoolManagerFactory());
        address otherPoolManager = address(new MockPoolManager());

        MockPoolManager(otherPoolManager).__setFactory(otherFactory);
        MockPoolManagerFactory(otherFactory).__setIsInstance(otherPoolManager, true);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:INVALID_PM");
        strategyManager.fundStrategyManager(otherPoolManager, 1, "");
    }

    function test_fundStrategyManager_revert_invalidPM() external {
        address otherPoolManager = address(new MockPoolManager());

        MockPoolManager(otherPoolManager).__setFactory(poolManagerFactory);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:INVALID_PM");
        strategyManager.fundStrategyManager(otherPoolManager, 1, "");
    }

    function test_fundStrategyManager_revert_invalidUSFactory() external {
        address otherFactory            = address(new MockStrategyFactory(globals));
        address otherUnderlyingStrategy = address(new MockStrategy());

        MockStrategy(otherUnderlyingStrategy).__setFactory(otherFactory);

        strategyManager.__setUnderlyingStrategy(otherUnderlyingStrategy);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:INVALID_US");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_invalidUS() external {
        address otherUnderlyingStrategy = address(new MockStrategy());

        MockStrategy(otherUnderlyingStrategy).__setFactory(address(strategyFactory));

        strategyManager.__setUnderlyingStrategy(otherUnderlyingStrategy);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:INVALID_US");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_zeroTotalAssetsWithNonZeroShares() external {
        setStrategyLiquidityCap(type(uint256).max);

        setStrategyManagerState({
            aum_:         0,
            totalShares_: 100
        });

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        vm.expectRevert(stdError.divisionError);
        strategyManager.fundStrategyManager(poolManager, 100, "");
    }

    function test_fundStrategyManager_revert_zeroShares() external {
        setStrategyLiquidityCap(type(uint256).max);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(0);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:ZERO_SHARES");
        strategyManager.fundStrategyManager(poolManager, 100, "");
    }

    function test_fundStrategyManager_revert_zeroShares_roundsDown() external {
        setStrategyLiquidityCap(type(uint256).max);

        setStrategyManagerState({
            aum_:         100,
            totalShares_: 1
        });

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:ZERO_SHARES");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_poolManagerCap() external {
        setStrategyLiquidityCap(type(uint256).max);

        setPoolManagerCap(poolManager, 99);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        strategyManager.fundStrategyManager(poolManager, 100, "");
    }

    function test_fundStrategyManager_revert_poolManagerCap_secondFunding() external {
        setStrategyLiquidityCap(type(uint256).max);

        setPoolManagerCap(poolManager, 100);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, 100, "");

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_poolManagerCap_afterLoweringCap() external {
        setStrategyLiquidityCap(type(uint256).max);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, 100, "");

        setPoolManagerCap(poolManager, 50);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_poolManagerCap_maxCapBlocksEmptyStrategy() external {
        setStrategyLiquidityCap(type(uint256).max);

        setPoolManagerCap(poolManager, type(uint256).max);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_poolManagerCap_maxCapBlocksExistingPosition() external {
        setStrategyLiquidityCap(type(uint256).max);

        setPoolManagerCap(poolManager, 100);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, 100, "");

        setPoolManagerCap(poolManager, type(uint256).max);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_zeroPoolManagerCap_stillEnforcesStrategyLiquidityCap() external {
        // Pool manager cap is unset (zero) so it is ignored, but the strategy liquidity cap still applies.
        setStrategyLiquidityCap(99);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);
        assertEq(strategyManager.strategyLiquidityCap(),        99);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        strategyManager.fundStrategyManager(poolManager, 100, "");
    }

    function test_fundStrategyManager_revert_strategyLiquidityCap() external {
        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        strategyManager.fundStrategyManager(poolManager, 100, "");

        setStrategyLiquidityCap(99);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        strategyManager.fundStrategyManager(poolManager, 99, "");
    }

    function test_fundStrategyManager_revert_strategyLiquidityCap_secondFunding() external {
        setStrategyLiquidityCap(100);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, 100, "");

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_strategyLiquidityCap_secondPoolManager() external {
        address poolManager2 = address(new MockPoolManager());

        MockPoolManager(poolManager2).__setFactory(poolManagerFactory);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager2, true);

        setStrategyLiquidityCap(150);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, 100, "");

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(51);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        strategyManager.fundStrategyManager(poolManager2, 51, "");
    }

    function test_fundStrategyManager_revert_strategyLiquidityCap_afterRevocation() external {
        setStrategyLiquidityCap(type(uint256).max);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, 100, "");

        setStrategyLiquidityCap(0);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

    function test_fundStrategyManager_revert_strategyLiquidityCap_afterLoweringCap() external {
        setStrategyLiquidityCap(type(uint256).max);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, 100, "");

        setStrategyLiquidityCap(50);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        strategyManager.fundStrategyManager(poolManager, 1, "");
    }

}

contract FundStrategyManagerSuccessTests is TestBase {

    function setUp() public override {
        super.setUp();

        setStrategyLiquidityCap(type(uint256).max);
    }

    function test_fundStrategyManager_success_emptyStrategy_atPoolManagerCap() external {
        uint256 assets = 100;

        setPoolManagerCap(poolManager, assets);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assets);

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assets, assets, assets);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assets, "");

        assertEq(strategyManager.assetsUnderManagement(), assets);
        assertEq(strategyManager.totalShares(),           assets);

        assertEq(strategyManager.sharesOf(poolManager), assets);
        assertEq(strategyManager.assetsOf(poolManager), assets);
    }

    function test_fundStrategyManager_success_zeroPoolManagerCap_noLimit() external {
        uint256 assets = 1_000_000e18;

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assets);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assets, assets, assets);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assets, "");

        assertEq(strategyManager.assetsUnderManagement(), assets);
        assertEq(strategyManager.totalShares(),           assets);

        assertEq(strategyManager.sharesOf(poolManager), assets);
        assertEq(strategyManager.assetsOf(poolManager), assets);
    }

    function test_fundStrategyManager_success_afterRevocationToZeroCap() external {
        setPoolManagerCap(poolManager, 100);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 100);

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(100);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, 100, 100, 100);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, 100, "");

        assertEq(strategyManager.assetsUnderManagement(), 100);
        assertEq(strategyManager.totalShares(),           100);

        assertEq(strategyManager.sharesOf(poolManager), 100);
        assertEq(strategyManager.assetsOf(poolManager), 100);

        setPoolManagerCap(poolManager, 0);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(50);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, 50, 50, 50);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, 50, "");

        assertEq(strategyManager.assetsUnderManagement(), 150);
        assertEq(strategyManager.totalShares(),           150);

        assertEq(strategyManager.poolManagerCapOf(poolManager), 0);

        assertEq(strategyManager.sharesOf(poolManager), 150);
        assertEq(strategyManager.assetsOf(poolManager), 150);
    }

    function test_fundStrategyManager_success_emptyStrategy_atStrategyLiquidityCap() external {
        uint256 assets = 100;

        setStrategyLiquidityCap(assets);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assets);

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assets, assets, assets);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assets, "");

        assertEq(strategyManager.assetsUnderManagement(), assets);
        assertEq(strategyManager.totalShares(),           assets);

        assertEq(strategyManager.sharesOf(poolManager), assets);
        assertEq(strategyManager.assetsOf(poolManager), assets);
    }

    function test_fundStrategyManager_success_emptyStrategy_UnderlyingReturnsEqualsAssets_calledByLiquidityRouter() external {
        uint256 assets = 100;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assets);

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assets, assets, assets);

        vm.prank(liquidityRouter);
        strategyManager.fundStrategyManager(poolManager, assets, "");

        assertEq(strategyManager.assetsUnderManagement(), assets);
        assertEq(strategyManager.totalShares(),           assets);

        assertEq(strategyManager.sharesOf(poolManager), assets);
        assertEq(strategyManager.assetsOf(poolManager), assets);
    }

    function test_fundStrategyManager_success_emptyStrategy_UnderlyingReturnsEqualsAssets_calledByStrategyDelegate() external {
        uint256 assets = 100;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assets);

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assets, assets, assets);

        vm.prank(strategyDelegate);
        strategyManager.fundStrategyManager(poolManager, assets, "");

        assertEq(strategyManager.assetsUnderManagement(), assets);
        assertEq(strategyManager.totalShares(),           assets);

        assertEq(strategyManager.sharesOf(poolManager), assets);
        assertEq(strategyManager.assetsOf(poolManager), assets);
    }

    function test_fundStrategyManager_success_emptyStrategy_UnderlyingReturnsLessAssets_calledByLiquidityBot() external {
        uint256 assets         = 100;
        uint256 assetsDeployed = 70;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsDeployed);

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assets, assetsDeployed, assetsDeployed);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assets, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsDeployed);
        assertEq(strategyManager.totalShares(),           assetsDeployed);

        assertEq(strategyManager.sharesOf(poolManager), assetsDeployed);
        assertEq(strategyManager.assetsOf(poolManager), assetsDeployed);
    }

    function test_fundStrategyManager_success_emptyStrategy_UnderlyingReturnsMoreAssets() external {
        uint256 assets         = 100;
        uint256 assetsDeployed = 134;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsDeployed);

        assertEq(strategyManager.assetsUnderManagement(), 0);
        assertEq(strategyManager.totalShares(),           0);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assets, assetsDeployed, assetsDeployed);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assets, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsDeployed);
        assertEq(strategyManager.totalShares(),           assetsDeployed);

        assertEq(strategyManager.sharesOf(poolManager), assetsDeployed);
        assertEq(strategyManager.assetsOf(poolManager), assetsDeployed);
    }

    function test_fundStrategyManager_success_strategyHasUnaccountedAssets_firstDepositorClaimsAll() external {
        uint256 unaccountedAssets = 50;
        uint256 assetsToFund      = 100;

        MockStrategy(underlyingStrategy).__setAssetsUnderManagement(unaccountedAssets);

        assertEq(strategyManager.assetsUnderManagement(), unaccountedAssets);
        assertEq(strategyManager.totalShares(),           0);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsToFund);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assetsToFund, assetsToFund, assetsToFund);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.assetsUnderManagement(), unaccountedAssets + assetsToFund);
        assertEq(strategyManager.totalShares(),           assetsToFund);

        assertEq(strategyManager.sharesOf(poolManager), assetsToFund);
        assertEq(strategyManager.assetsOf(poolManager), unaccountedAssets + assetsToFund);
    }

    function test_fundStrategyManager_success_secondFunding_strategyHasYield_strategyReturnsEqualAssets() external {
        uint256 totalSharesBeforeFund           = 100;
        uint256 assetsUnderManagementBeforeFund = 200;

        setStrategyManagerState({
            aum_:         assetsUnderManagementBeforeFund,
            totalShares_: totalSharesBeforeFund
        });

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        uint256 assetsToFund            = 100;
        uint256 expectedSharesToReceive = 50;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsToFund);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund + assetsToFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund + expectedSharesToReceive);

        assertEq(strategyManager.sharesOf(poolManager), expectedSharesToReceive);
        assertEq(strategyManager.assetsOf(poolManager), assetsToFund);
    }

    function test_fundStrategyManager_success_secondFunding_strategyHasYield_strategyReturnsLessAssets() external {
        uint256 totalSharesBeforeFund           = 100;
        uint256 assetsUnderManagementBeforeFund = 200;

        setStrategyManagerState({
            aum_:         assetsUnderManagementBeforeFund,
            totalShares_: totalSharesBeforeFund
        });

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        uint256 assetsToFund            = 100;
        uint256 assetsDeployed          = 70;
        uint256 expectedSharesToReceive = 35;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsDeployed);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assetsToFund, assetsDeployed, expectedSharesToReceive);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund + assetsDeployed);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund + expectedSharesToReceive);

        assertEq(strategyManager.sharesOf(poolManager), expectedSharesToReceive);
        assertEq(strategyManager.assetsOf(poolManager), assetsDeployed);
    }

    function test_fundStrategyManager_success_secondFunding_strategyHasYield_strategyReturnsMoreAssets() external {
        uint256 totalSharesBeforeFund           = 100;
        uint256 assetsUnderManagementBeforeFund = 200;

        setStrategyManagerState({
            aum_:         assetsUnderManagementBeforeFund,
            totalShares_: totalSharesBeforeFund
        });

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        uint256 assetsToFund            = 100;
        uint256 assetsDeployed          = 134;
        uint256 expectedSharesToReceive = 67;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsDeployed);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assetsToFund, assetsDeployed, expectedSharesToReceive);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund + assetsDeployed);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund + expectedSharesToReceive);

        assertEq(strategyManager.sharesOf(poolManager), expectedSharesToReceive);
        assertEq(strategyManager.assetsOf(poolManager), assetsDeployed);
    }

    function test_fundStrategyManager_success_secondFunding_strategyHasYield_depositorRoundsDown() external {
        uint256 totalSharesBeforeFund           = 10;
        uint256 assetsUnderManagementBeforeFund = 15;

        setStrategyManagerState({
            aum_:         assetsUnderManagementBeforeFund,
            totalShares_: totalSharesBeforeFund
        });

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        uint256 assetsToFund            = 7;
        uint256 expectedSharesToReceive = 4;
        uint256 expectedAssetsOf        = 6;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsToFund);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assetsToFund, assetsToFund, expectedSharesToReceive);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund + assetsToFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund + expectedSharesToReceive);

        assertEq(strategyManager.sharesOf(poolManager), expectedSharesToReceive);
        assertEq(strategyManager.assetsOf(poolManager), expectedAssetsOf);
        assertLt(strategyManager.assetsOf(poolManager), assetsToFund);
    }

    function test_fundStrategyManager_success_secondFunding_strategyHasLoss_strategyReturnsEqualAssets() external {
        uint256 totalSharesBeforeFund           = 100;
        uint256 assetsUnderManagementBeforeFund = 40;

        setStrategyManagerState({
            aum_:         assetsUnderManagementBeforeFund,
            totalShares_: totalSharesBeforeFund
        });

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        uint256 assetsToFund            = 100;
        uint256 expectedSharesToReceive = 250;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsToFund);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assetsToFund, assetsToFund, expectedSharesToReceive);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund + assetsToFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund + expectedSharesToReceive);

        assertEq(strategyManager.sharesOf(poolManager), expectedSharesToReceive);
        assertEq(strategyManager.assetsOf(poolManager), assetsToFund);
    }

    function test_fundStrategyManager_success_secondFunding_strategyHasLoss_strategyReturnsLessAssets() external {
        uint256 totalSharesBeforeFund           = 100;
        uint256 assetsUnderManagementBeforeFund = 40;

        setStrategyManagerState({
            aum_:         assetsUnderManagementBeforeFund,
            totalShares_: totalSharesBeforeFund
        });

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        uint256 assetsToFund            = 100;
        uint256 assetsDeployed          = 70;
        uint256 expectedSharesToReceive = 175;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsDeployed);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assetsToFund, assetsDeployed, expectedSharesToReceive);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund + assetsDeployed);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund + expectedSharesToReceive);

        assertEq(strategyManager.sharesOf(poolManager), expectedSharesToReceive);
        assertEq(strategyManager.assetsOf(poolManager), assetsDeployed);
    }

    function test_fundStrategyManager_success_secondFunding_strategyHasLoss_strategyReturnsMoreAssets() external {
        uint256 totalSharesBeforeFund           = 100;
        uint256 assetsUnderManagementBeforeFund = 40;

        setStrategyManagerState({
            aum_:         assetsUnderManagementBeforeFund,
            totalShares_: totalSharesBeforeFund
        });

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        uint256 assetsToFund            = 100;
        uint256 assetsDeployed          = 134;
        uint256 expectedSharesToReceive = 335;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsDeployed);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assetsToFund, assetsDeployed, expectedSharesToReceive);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund + assetsDeployed);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund + expectedSharesToReceive);

        assertEq(strategyManager.sharesOf(poolManager), expectedSharesToReceive);
        assertEq(strategyManager.assetsOf(poolManager), assetsDeployed);
    }

    function test_fundStrategyManager_success_secondFunding_strategyHasLoss_depositorRoundsToZero() external {
        uint256 totalSharesBeforeFund           = 10;
        uint256 assetsUnderManagementBeforeFund = 3;

        setStrategyManagerState({
            aum_:         assetsUnderManagementBeforeFund,
            totalShares_: totalSharesBeforeFund
        });

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        uint256 assetsToFund            = 1;
        uint256 expectedSharesToReceive = 3;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsToFund);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assetsToFund, assetsToFund, expectedSharesToReceive);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund + assetsToFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund + expectedSharesToReceive);

        assertEq(strategyManager.sharesOf(poolManager), expectedSharesToReceive);
        assertEq(strategyManager.assetsOf(poolManager), 0);
    }

    function test_fundStrategyManager_success_secondFunding_strategyHasImpairment_exchangeRateUnaffected() external {
        uint256 totalSharesBeforeFund           = 100;
        uint256 assetsUnderManagementBeforeFund = 200;
        uint256 impairedAssets                  = 50;

        setStrategyManagerState({
            aum_:         assetsUnderManagementBeforeFund,
            totalShares_: totalSharesBeforeFund
        });

        MockStrategy(underlyingStrategy).__setImpairedAssets(impairedAssets);
        MockStrategy(underlyingStrategy).__setUnrealizedLosses(impairedAssets);

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund);
        assertEq(strategyManager.unrealizedLosses(),      impairedAssets);

        assertEq(strategyManager.sharesOf(poolManager), 0);
        assertEq(strategyManager.assetsOf(poolManager), 0);

        uint256 assetsToFund            = 100;
        uint256 expectedSharesToReceive = 50;

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsToFund);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(poolManager, assetsToFund, assetsToFund, expectedSharesToReceive);

        vm.prank(strategyDelegate);
        strategyManager.fundStrategyManager(poolManager, assetsToFund, "");

        assertEq(strategyManager.assetsUnderManagement(), assetsUnderManagementBeforeFund + assetsToFund);
        assertEq(strategyManager.totalShares(),           totalSharesBeforeFund + expectedSharesToReceive);
        assertEq(strategyManager.unrealizedLosses(),      impairedAssets);

        assertEq(strategyManager.sharesOf(poolManager), expectedSharesToReceive);
        assertEq(strategyManager.assetsOf(poolManager), assetsToFund);
    }

    function test_fundStrategyManager_success_multiplePoolManagers() external {
        uint256 fundAmount1 = 100;
        uint256 fundAmount2 = 60;

        address poolManager1 = address(new MockPoolManager());
        address poolManager2 = address(new MockPoolManager());

        MockPoolManager(poolManager1).__setFactory(poolManagerFactory);
        MockPoolManager(poolManager2).__setFactory(poolManagerFactory);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager1, true);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager2, true);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(fundAmount1);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager1, fundAmount1, "");

        assertEq(strategyManager.assetsUnderManagement(), fundAmount1);
        assertEq(strategyManager.totalShares(),           fundAmount1);

        assertEq(strategyManager.sharesOf(poolManager1), fundAmount1);
        assertEq(strategyManager.assetsOf(poolManager1), fundAmount1);
        assertEq(strategyManager.sharesOf(poolManager2), 0);
        assertEq(strategyManager.assetsOf(poolManager2), 0);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(fundAmount2);

        vm.prank(liquidityBot);
        strategyManager.fundStrategyManager(poolManager2, fundAmount2, "");

        assertEq(strategyManager.assetsUnderManagement(), fundAmount1 + fundAmount2);
        assertEq(strategyManager.totalShares(),           fundAmount1 + fundAmount2);

        assertEq(strategyManager.sharesOf(poolManager1), fundAmount1);
        assertEq(strategyManager.assetsOf(poolManager1), fundAmount1);
        assertEq(strategyManager.sharesOf(poolManager2), fundAmount2);
        assertEq(strategyManager.assetsOf(poolManager2), fundAmount2);
    }

}
