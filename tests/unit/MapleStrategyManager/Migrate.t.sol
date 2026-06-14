// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals, MockMigrator } from "../../utils/Mocks.sol";
import { TestBase }                  from "../../utils/TestBase.sol";

contract MigrateTests is TestBase {

    address migrator = address(new MockMigrator());

    bytes arguments = abi.encode(address(1337));

    function test_migrate_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.migrate.selector, true);

        vm.expectRevert("MSM:PAUSED");
        strategyManager.migrate(migrator, arguments);
    }

    function test_migrate_revert_notFactory() external {
        vm.expectRevert("MSM:NOT_FACTORY");
        strategyManager.migrate(migrator, arguments);
    }

    function test_migrate_revert_invalidArguments() external {
        vm.prank(address(factory));
        vm.expectRevert("MSM:M:FAILED");
        strategyManager.migrate(migrator, "");
    }

    function test_migrate_revert_invalidMigrator() external {
        vm.prank(address(factory));
        vm.expectRevert("MSM:M:FAILED");
        strategyManager.migrate(makeAddr("randomAddress"), arguments);
    }

    function test_migrate_success() external {
        assertEq(strategyManager.underlyingStrategy(), underlyingStrategy);

        vm.prank(address(factory));
        strategyManager.migrate(migrator, arguments);

        assertEq(strategyManager.underlyingStrategy(), address(1337));
    }

}
