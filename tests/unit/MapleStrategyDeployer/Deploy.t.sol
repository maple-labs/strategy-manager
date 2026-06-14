// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyDeployer } from "../../../contracts/interfaces/IMapleStrategyDeployer.sol";
import { IMapleStrategyManager }  from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyDeployer } from "../../../contracts/MapleStrategyDeployer.sol";

import {
    MockDeployableStrategy,
    MockDeployableStrategyInitializer,
    MockGlobals,
    MockStrategyFactory
} from "../../utils/Mocks.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract DeployFailureTests is TestBase {

    function setUp() public override {
        super.setUp();

        strategyFactory  = new MockStrategyFactory(globals);
        strategyDeployer = new MapleStrategyDeployer(globals);

        vm.startPrank(governor);
        strategyFactory.registerImplementation(
            100,
            address(new MockDeployableStrategy()),
            address(new MockDeployableStrategyInitializer())
        );
        strategyFactory.setDefaultVersion(100);
        vm.stopPrank();

        MockGlobals(globals).__setCanDeploy(address(strategyDeployer), true);

        MockGlobals(globals).__setIsInstanceOf("UNDERLYING_STRATEGY_FACTORY", address(strategyFactory), true);
        MockGlobals(globals).__setIsInstanceOf("STRATEGY_MANAGER_FACTORY",    address(factory),         true);
    }

    function test_deploy_revert_invalidStrategyDelegate() external {
        MockGlobals(globals).__setIsStrategyDelegate(strategyDelegate, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_SD");
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(false));
    }

    function test_deploy_revert_invalidStrategyManagerFactory() external {
        MockGlobals(globals).__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(factory), false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_SM_FACTORY");
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(false));
    }

    function test_deploy_revert_invalidStrategyFactory() external {
        MockGlobals(globals).__setIsInstanceOf("UNDERLYING_STRATEGY_FACTORY", address(strategyFactory), false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_STRATEGY_FACTORY");
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(false));
    }

    function test_deploy_revert_invalidStrategy() external {
        strategyFactory.__setInvalidInstance(address(new MockDeployableStrategy()));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_STRATEGY");
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(false));
    }

    function test_deploy_revert_invalidStrategyManager() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_STRATEGY_MANAGER");
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(true));
    }

    function test_deploy_revert_duplicateDeployment() external {
        bytes memory strategyDeploymentData_ = abi.encode(false);

        vm.prank(strategyDelegate);
        strategyDeployer.deploy(address(factory), address(strategyFactory), strategyDeploymentData_);

        vm.prank(strategyDelegate);
        vm.expectRevert();
        strategyDeployer.deploy(address(factory), address(strategyFactory), strategyDeploymentData_);
    }

}

contract DeploySuccessTests is TestBase {

    function setUp() public override {
        super.setUp();

        strategyFactory  = new MockStrategyFactory(globals);
        strategyDeployer = new MapleStrategyDeployer(globals);

        vm.startPrank(governor);
        strategyFactory.registerImplementation(
            100,
            address(new MockDeployableStrategy()),
            address(new MockDeployableStrategyInitializer())
        );
        strategyFactory.setDefaultVersion(100);
        vm.stopPrank();

        MockGlobals(globals).__setCanDeploy(address(strategyDeployer), true);

        MockGlobals(globals).__setIsInstanceOf("UNDERLYING_STRATEGY_FACTORY", address(strategyFactory), true);
        MockGlobals(globals).__setIsInstanceOf("STRATEGY_MANAGER_FACTORY",    address(factory),         true);
    }

    function test_deploy_success() external {
        bytes memory strategyDeploymentData_ = abi.encode(false);

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) = strategyDeployer.getDeploymentAddresses(
            strategyDelegate,
            address(factory),
            address(strategyFactory),
            strategyDeploymentData_
        );

        vm.expectEmit();
        emit IMapleStrategyDeployer.StrategyManagerDeployed(
            strategyDelegate,
            expectedStrategyManager,
            expectedUnderlyingStrategy
        );

        vm.prank(strategyDelegate);
        ( address strategyManager, address underlyingStrategy ) =
            strategyDeployer.deploy(address(factory), address(strategyFactory), strategyDeploymentData_);

        assertEq(strategyManager,    expectedStrategyManager);
        assertEq(underlyingStrategy, expectedUnderlyingStrategy);

        assertEq(factory.isInstance(strategyManager),            true);
        assertEq(strategyFactory.isInstance(underlyingStrategy), true);

        assertEq(IMapleStrategyManager(strategyManager).strategyDelegate(),   strategyDelegate);
        assertEq(IMapleStrategyManager(strategyManager).underlyingStrategy(), underlyingStrategy);
        assertEq(IMapleStrategyManager(strategyManager).configured(),         true);

        assertEq(MockDeployableStrategy(underlyingStrategy).strategyManager(), strategyManager);
    }

}
