// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleStrategyDeployer } from "../../../contracts/MapleStrategyDeployer.sol";

import { TestBase } from "../../utils/TestBase.sol";

import {
    MockDeployableStrategy,
    MockDeployableStrategyInitializer,
    MockStrategyFactory
} from "../../utils/Mocks.sol";

contract GetDeploymentAddressesTests is TestBase {

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
    }

    function test_getDeploymentAddresses_success() external view {
        bytes32 salt = keccak256(abi.encode(strategyDelegate));

        bytes memory strategyManagerDeploymentData = abi.encode(strategyDelegate);
        address expectedStrategyManager = factory.getInstanceAddress(strategyManagerDeploymentData, salt);

        bytes memory strategyDeploymentData = bytes.concat(
            abi.encode(expectedStrategyManager),
            abi.encode(false)
        );
        address expectedUnderlyingStrategy = strategyFactory.getInstanceAddress(strategyDeploymentData, salt);

        ( address strategyManager, address underlyingStrategy ) = strategyDeployer.getDeploymentAddresses(
            strategyDelegate,
            address(factory),
            address(strategyFactory),
            abi.encode(false)
        );

        assertEq(strategyManager,    expectedStrategyManager);
        assertEq(underlyingStrategy, expectedUnderlyingStrategy);
    }

}
