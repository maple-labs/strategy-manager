// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyDeployer } from "../../../contracts/interfaces/IMapleStrategyDeployer.sol";
import { IMapleStrategyManager }  from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyDeployer } from "../../../contracts/MapleStrategyDeployer.sol";

import {
    MockDeployableStrategy,
    MockDeployableStrategyInitializer,
    MockERC20,
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
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(false), "");
    }

    function test_deploy_revert_invalidStrategyManagerFactory() external {
        MockGlobals(globals).__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(factory), false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_SM_FACTORY");
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(false), "");
    }

    function test_deploy_revert_invalidStrategyFactory() external {
        MockGlobals(globals).__setIsInstanceOf("UNDERLYING_STRATEGY_FACTORY", address(strategyFactory), false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_STRATEGY_FACTORY");
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(false), "");
    }

    function test_deploy_revert_invalidStrategy() external {
        strategyFactory.__setInvalidInstance(address(new MockDeployableStrategy()));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_STRATEGY");
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(false), "");
    }

    function test_deploy_revert_invalidStrategyManager() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_STRATEGY_MANAGER");
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(true), "");
    }

    function test_deploy_revert_duplicateDeployment() external {
        bytes memory strategyDeploymentData_ = abi.encode(false);

        vm.prank(strategyDelegate);
        strategyDeployer.deploy(address(factory), address(strategyFactory), strategyDeploymentData_, "");

        vm.prank(strategyDelegate);
        vm.expectRevert();
        strategyDeployer.deploy(address(factory), address(strategyFactory), strategyDeploymentData_, "");
    }

    function test_deploy_revert_bootstrapTransferFailed() external {
        uint256 bootstrapAssets = 1e6;

        MockGlobals(globals).__setBootstrapMint(address(asset), bootstrapAssets);
        strategyFactory.__setFundsAsset(address(asset));
        MockERC20(asset).__setTransferFromReturn(false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:BOOTSTRAP_TRANSFER_FAILED");
        strategyDeployer.deploy(address(factory), address(strategyFactory), abi.encode(false), "");
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
        uint256 bootstrapAssets = 1e6;

        bytes memory strategyDeploymentData_ = abi.encode(false);
        bytes memory bootstrapFundingData_   = abi.encode("bootstrap-funding-data");

        MockGlobals(globals).__setBootstrapMint(address(asset), bootstrapAssets);
        strategyFactory.__setFundsAsset(address(asset));
        MockERC20(asset).__mint(strategyDelegate, bootstrapAssets);

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) = strategyDeployer.getDeploymentAddresses(
            strategyDelegate,
            address(factory),
            address(strategyFactory),
            strategyDeploymentData_
        );

        assertEq(MockERC20(asset).balanceOf(strategyDelegate),           bootstrapAssets);
        assertEq(MockERC20(asset).balanceOf(expectedUnderlyingStrategy), 0);

        vm.expectCall(
            expectedUnderlyingStrategy,
            abi.encodeCall(MockDeployableStrategy.fundUnderlyingStrategy, (bootstrapAssets, bootstrapFundingData_))
        );

        vm.expectEmit();
        emit IMapleStrategyDeployer.StrategyManagerDeployed(
            strategyDelegate,
            expectedStrategyManager,
            expectedUnderlyingStrategy
        );

        vm.prank(strategyDelegate);
        ( address strategyManager, address underlyingStrategy ) =
            strategyDeployer.deploy(address(factory), address(strategyFactory), strategyDeploymentData_, bootstrapFundingData_);

        assertEq(strategyManager,    expectedStrategyManager);
        assertEq(underlyingStrategy, expectedUnderlyingStrategy);

        assertEq(factory.isInstance(strategyManager),            true);
        assertEq(strategyFactory.isInstance(underlyingStrategy), true);

        assertEq(IMapleStrategyManager(strategyManager).strategyDelegate(),   strategyDelegate);
        assertEq(IMapleStrategyManager(strategyManager).underlyingStrategy(), underlyingStrategy);
        assertEq(IMapleStrategyManager(strategyManager).configured(),         true);

        assertEq(IMapleStrategyManager(strategyManager).totalShares(),        bootstrapAssets);
        assertEq(IMapleStrategyManager(strategyManager).sharesOf(address(0)), bootstrapAssets);

        assertEq(MockDeployableStrategy(underlyingStrategy).strategyManager(), strategyManager);

        assertEq(MockERC20(asset).balanceOf(strategyDelegate),   0);
        assertEq(MockERC20(asset).balanceOf(underlyingStrategy), bootstrapAssets);
    }

    function test_deploy_success_zeroBootstrap() external {
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
            strategyDeployer.deploy(address(factory), address(strategyFactory), strategyDeploymentData_, "");

        assertEq(strategyManager,    expectedStrategyManager);
        assertEq(underlyingStrategy, expectedUnderlyingStrategy);

        assertEq(factory.isInstance(strategyManager),            true);
        assertEq(strategyFactory.isInstance(underlyingStrategy), true);

        assertEq(IMapleStrategyManager(strategyManager).strategyDelegate(),   strategyDelegate);
        assertEq(IMapleStrategyManager(strategyManager).underlyingStrategy(), underlyingStrategy);
        assertEq(IMapleStrategyManager(strategyManager).configured(),         true);

        assertEq(IMapleStrategyManager(strategyManager).totalShares(),        0);
        assertEq(IMapleStrategyManager(strategyManager).sharesOf(address(0)), 0);

        assertEq(MockDeployableStrategy(underlyingStrategy).strategyManager(), strategyManager);
    }

}
