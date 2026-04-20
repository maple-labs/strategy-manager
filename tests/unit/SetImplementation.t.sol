// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleStrategyManager } from "../../contracts/MapleStrategyManager.sol";

import { TestBase } from "../utils/TestBase.sol";

contract SetImplementationTests is TestBase {

    address internal newImplementation;

    function setUp() public override {
        super.setUp();

        newImplementation = address(new MapleStrategyManager());
    }

    function test_setImplementation_protocolPaused() external {
        globals.__setIsFunctionPaused(MapleStrategyManager.setImplementation.selector, true);

        vm.expectRevert("MSM:PAUSED");
        manager.setImplementation(newImplementation);
    }

    function test_setImplementation_notFactory() external {
        vm.expectRevert("MSM:NOT_FACTORY");
        manager.setImplementation(newImplementation);
    }

    function test_setImplementation_success() external {
        assertEq(manager.implementation(), implementation);

        vm.prank(address(factory));
        manager.setImplementation(newImplementation);

        assertEq(manager.implementation(), newImplementation);
    }

}
