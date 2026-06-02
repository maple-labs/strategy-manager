// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxyFactory } from "../../../modules/proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import { IMapleStrategyManagerInitializer } from "../../../contracts/interfaces/IMapleStrategyManagerInitializer.sol";

import { MapleStrategyManagerHarness } from "../../utils/Harnesses.sol";
import { MockGlobals }                 from "../../utils/Mocks.sol";
import { TestBase }                    from "../../utils/TestBase.sol";

contract CreateInstanceTests is TestBase {

    function test_createInstance_revert_invalidDeployer() external {
        MockGlobals(globals).__setCanDeploy(deployer, false);

        vm.prank(deployer);
        vm.expectRevert("MSMF:CI:CANNOT_DEPLOY");
        factory.createInstance(abi.encode(params), "");
    }

    function test_createInstance_revert_protocolPaused() external {
        MockGlobals(globals).__setProtocolPaused(true);

        vm.prank(deployer);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        factory.createInstance(abi.encode(params), "");
    }

    function test_createInstance_revert_malformedArguments() external {
        vm.prank(deployer);
        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance("", "");
    }

    function test_createInstance_success() external {
        bytes32 salt           = keccak256("salt");
        bytes memory arguments = abi.encode(params);

        address expectedInstance = factory.getInstanceAddress(arguments, salt);

        assertEq(factory.isInstance(expectedInstance), false);

        vm.expectEmit();
        emit IMapleStrategyManagerInitializer.Initialized(params);

        vm.expectEmit();
        emit IMapleProxyFactory.InstanceDeployed(100, expectedInstance, arguments);

        vm.prank(deployer);
        strategyManager = MapleStrategyManagerHarness(factory.createInstance(arguments, salt));

        assertEq(address(strategyManager),             expectedInstance);
        assertEq(strategyManager.factory(),            address(factory));
        assertEq(strategyManager.implementation(),     implementation);
        assertEq(strategyManager.strategyDelegate(),   strategyDelegate);
        assertEq(strategyManager.underlyingStrategy(), underlyingStrategy);
        assertEq(strategyManager.active(),             false);
        assertEq(strategyManager.locked(),             1);

        assertEq(factory.isInstance(expectedInstance), true);
    }

}
