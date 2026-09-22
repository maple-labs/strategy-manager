// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxied } from "../../../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals, MockMigrator } from "../../utils/Mocks.sol";
import { TestBase } from "../../utils/TestBase.sol";

contract UpgradeTests is TestBase {

    address migrator          = address(new MockMigrator());
    address newImplementation = address(new MapleStrategyManager());

    bytes arguments = abi.encode(address(1337));

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);
        factory.registerImplementation(200, newImplementation, initializer);
        factory.enableUpgradePath(100, 200, migrator);
        vm.stopPrank();
    }

    function test_upgrade_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.upgrade.selector, true);

        vm.prank(securityAdmin);
        vm.expectRevert("MSM:PAUSED");
        strategyManager.upgrade(200, arguments);
    }

    function test_upgrade_revert_protocolPaused() external {
        MockGlobals(globals).__setProtocolPaused(true);

        vm.prank(securityAdmin);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        strategyManager.upgrade(200, arguments);
    }

    function test_upgrade_revert_notAuthorized() external {
        vm.expectRevert("MSM:U:NOT_AUTHORIZED");
        strategyManager.upgrade(200, arguments);
    }

    function test_upgrade_revert_notAllowed() external {
        vm.prank(governor);
        factory.disableUpgradePath(100, 200);

        vm.prank(securityAdmin);
        vm.expectRevert("MPF:UI:NOT_ALLOWED");
        strategyManager.upgrade(200, arguments);
    }

    function test_upgrade_revert_internalFailure() external {
        vm.prank(securityAdmin);
        vm.expectRevert("MPF:UI:FAILED");
        strategyManager.upgrade(200, "");
    }

    function test_upgrade_success() external {
        assertEq(strategyManager.implementation(),     implementation);
        assertEq(strategyManager.underlyingStrategy(), underlyingStrategy);

        vm.expectEmit();
        emit IMapleProxied.Upgraded(200, arguments);

        vm.prank(securityAdmin);
        strategyManager.upgrade(200, arguments);

        assertEq(strategyManager.implementation(),     newImplementation);
        assertEq(strategyManager.underlyingStrategy(), address(1337));
    }

}
