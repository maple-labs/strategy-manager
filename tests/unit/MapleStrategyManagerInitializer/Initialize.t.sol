// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManagerInitializer } from "../../../contracts/interfaces/IMapleStrategyManagerInitializer.sol";

import { MapleStrategyManagerInitializerHarness } from "../../utils/Harnesses.sol";
import { TestBase }                               from "../../utils/TestBase.sol";

contract InitializeTests is TestBase {

    MapleStrategyManagerInitializerHarness proxy = MapleStrategyManagerInitializerHarness(initializer);

    function test_initialize_revert_zeroStrategyDelegate() external {
        params.strategyDelegate = address(0);

        vm.prank(address(factory));
        vm.expectRevert("MSMI:I:ZERO_STRATEGY_DELEGATE");
        proxy.__initialize(params);
    }

    function test_initialize_revert_zeroUnderlyingStrategy() external {
        params.underlyingStrategy = address(0);

        vm.prank(address(factory));
        vm.expectRevert("MSMI:I:ZERO_UNDERLYING_STRATEGY");
        proxy.__initialize(params);
    }

    function test_initialize_revert_invalidStrategyDelegate() external {
        params.strategyDelegate = makeAddr("invalidStrategyDelegate");

        vm.prank(address(factory));
        vm.expectRevert("MSMI:I:INVALID_DELEGATE");
        proxy.__initialize(params);
    }

    function test_initialize_success() external {
        vm.expectEmit();
        emit IMapleStrategyManagerInitializer.Initialized(params);

        vm.prank(address(factory));
        proxy.__initialize(params);

        assertEq(proxy.strategyDelegate(),   strategyDelegate);
        assertEq(proxy.underlyingStrategy(), underlyingStrategy);
        assertEq(proxy.active(),             false);
    }

}
