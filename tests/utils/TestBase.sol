// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../modules/forge-std/src/Test.sol";

import { IMapleStrategyManagerInitializer } from "../../contracts/interfaces/IMapleStrategyManagerInitializer.sol";

import { MapleStrategyManagerFactory } from "../../contracts/MapleStrategyManagerFactory.sol";

import { MapleStrategyManagerHarness, MapleStrategyManagerInitializerHarness } from "./Harnesses.sol";

import { MockGlobals, MockStrategy } from "./Mocks.sol";

contract TestBase is Test {

    address deployer      = makeAddr("deployer");
    address governor      = makeAddr("governor");
    address securityAdmin = makeAddr("securityAdmin");

    address implementation = address(new MapleStrategyManagerHarness());
    address initializer    = address(new MapleStrategyManagerInitializerHarness());

    uint32 startingTime;

    IMapleStrategyManagerInitializer.Parameters params;

    MockGlobals  globals            = new MockGlobals();
    MockStrategy underlyingStrategy = new MockStrategy();

    MapleStrategyManagerFactory factory;
    MapleStrategyManagerHarness manager;

    function setUp() public virtual {
        startingTime = uint32(block.timestamp);

        globals.__setCanDeploy(deployer, true);
        globals.__setGovernor(governor);
        globals.__setSecurityAdmin(securityAdmin);

        factory = new MapleStrategyManagerFactory(address(globals));

        vm.startPrank(governor);
        factory.registerImplementation(100, implementation, initializer);
        factory.setDefaultVersion(100);
        vm.stopPrank();

        params = IMapleStrategyManagerInitializer.Parameters({
            underlyingStrategy: address(underlyingStrategy)
        });

        vm.prank(deployer);
        manager = MapleStrategyManagerHarness(factory.createInstance(abi.encode(params), "DEFAULT"));
    }

}
