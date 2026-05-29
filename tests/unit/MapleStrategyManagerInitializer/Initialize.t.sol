// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManagerInitializer } from "../../../contracts/interfaces/IMapleStrategyManagerInitializer.sol";

import { MapleStrategyManagerInitializerHarness } from "../../utils/Harnesses.sol";
import { TestBase }                               from "../../utils/TestBase.sol";

contract InitializeTests is TestBase {

    MapleStrategyManagerInitializerHarness proxy = MapleStrategyManagerInitializerHarness(initializer);

    function test_initialize_success() external {
        vm.expectEmit();
        emit IMapleStrategyManagerInitializer.Initialized(params);

        vm.prank(address(factory));
        proxy.__initialize(params);

        assertEq(proxy.underlyingStrategy(), underlyingStrategy);
        assertEq(proxy.active(),             false);
    }

}
