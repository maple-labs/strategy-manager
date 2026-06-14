// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../modules/forge-std/src/Test.sol";

import { IMapleStrategyManagerInitializer } from "../../contracts/interfaces/IMapleStrategyManagerInitializer.sol";

import { MapleStrategyDeployer }       from "../../contracts/MapleStrategyDeployer.sol";
import { MapleStrategyManagerFactory } from "../../contracts/MapleStrategyManagerFactory.sol";

import { MapleStrategyManagerHarness, MapleStrategyManagerInitializerHarness } from "./Harnesses.sol";

import {
    MockERC20,
    MockGlobals,
    MockPoolManager,
    MockPoolManagerFactory,
    MockStrategy,
    MockStrategyFactory
} from "./Mocks.sol";

contract TestBase is Test {

    address deployer         = makeAddr("deployer");
    address governor         = makeAddr("governor");
    address liquidityBot     = makeAddr("liquidityBot");
    address liquidityRouter  = makeAddr("liquidityRouter");
    address operationalAdmin = makeAddr("operationalAdmin");
    address securityAdmin    = makeAddr("securityAdmin");
    address strategyDelegate = makeAddr("strategyDelegate");

    address implementation = address(new MapleStrategyManagerHarness());
    address initializer    = address(new MapleStrategyManagerInitializerHarness());

    uint32 startingTime;

    IMapleStrategyManagerInitializer.Parameters params;

    address globals            = address(new MockGlobals());
    address pool               = makeAddr("pool");
    address poolManagerFactory = address(new MockPoolManagerFactory());
    address poolManager        = address(new MockPoolManager());
    address asset              = address(new MockERC20());
    address underlyingStrategy = address(new MockStrategy());

    MapleStrategyDeployer       strategyDeployer;
    MapleStrategyManagerHarness strategyManager;
    MapleStrategyManagerFactory factory;
    MockStrategyFactory         strategyFactory;

    function setUp() public virtual {
        startingTime = uint32(block.timestamp);

        MockGlobals(globals).__setCanDeploy(deployer, true);
        MockGlobals(globals).__setGovernor(governor);
        MockGlobals(globals).__setIsInstanceOf("LIQUIDITY_BOT",        liquidityBot,       true);
        MockGlobals(globals).__setIsInstanceOf("LIQUIDITY_ROUTER",     liquidityRouter,    true);
        MockGlobals(globals).__setIsInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, true);
        MockGlobals(globals).__setOperationalAdmin(operationalAdmin);
        MockGlobals(globals).__setSecurityAdmin(securityAdmin);

        MockPoolManager(poolManager).__setFactory(poolManagerFactory);
        MockPoolManager(poolManager).__setPool(pool);
        MockPoolManagerFactory(poolManagerFactory).__setIsInstance(poolManager, true);

        MockStrategy(underlyingStrategy).__setFundsAsset(address(asset));

        factory = new MapleStrategyManagerFactory(globals);

        vm.startPrank(governor);
        factory.registerImplementation(100, implementation, initializer);
        factory.setDefaultVersion(100);
        vm.stopPrank();

        params = IMapleStrategyManagerInitializer.Parameters({
            strategyDelegate: strategyDelegate
        });

        MockGlobals(globals).__setIsStrategyDelegate(strategyDelegate, true);

        vm.prank(deployer);
        strategyManager = MapleStrategyManagerHarness(factory.createInstance(abi.encode(params), "DEFAULT"));

        MockGlobals(globals).__setStrategyDelegate(address(strategyManager), strategyDelegate);

        strategyManager.setUnderlyingStrategy(underlyingStrategy);
        strategyManager.completeConfiguration();
        strategyManager.__setActive(true);
    }

    function setStrategyManagerState(uint256 aum_, uint256 totalShares_) internal {
        MockStrategy(underlyingStrategy).__setAssetsUnderManagement(aum_);
        // TODO: Consider adding availableToWithdraw_ as a separate parameter if tests need to model partial liquidity.
        MockStrategy(underlyingStrategy).__setAvailableToWithdraw(aum_);
        strategyManager.__setTotalShares(totalShares_);
    }

    function setPoolManagerCap(address poolManager_, uint256 cap_) internal {
        vm.prank(strategyDelegate);
        strategyManager.setPoolManagerCap(poolManager_, cap_);
    }

    function setStrategyLiquidityCap(uint256 cap_) internal {
        vm.prank(strategyDelegate);
        strategyManager.setStrategyLiquidityCap(cap_);
    }

}
