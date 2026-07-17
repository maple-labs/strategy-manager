// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleStrategyManager } from "../../../contracts/interfaces/IMapleStrategyManager.sol";

import { MapleStrategyManager } from "../../../contracts/MapleStrategyManager.sol";

import { MockGlobals, MockStrategy } from "../../utils/Mocks.sol";
import { TestBase }                  from "../../utils/TestBase.sol";

contract CompleteConfigurationFailureTests is TestBase {

    function test_completeConfiguration_revert_functionPaused() external {
        MockGlobals(globals).__setIsFunctionPaused(MapleStrategyManager.completeConfiguration.selector, true);

        vm.expectRevert("MSM:PAUSED");
        strategyManager.completeConfiguration(0, "");
    }

    function test_completeConfiguration_revert_reentrancy() external {
        strategyManager.__setLocked(2);

        vm.expectRevert("MSM:LOCKED");
        strategyManager.completeConfiguration(0, "");
    }

    function test_completeConfiguration_revert_alreadyConfigured() external {
        assertEq(strategyManager.configured(), true);

        vm.expectRevert("MSM:CC:ALREADY_CONFIGURED");
        strategyManager.completeConfiguration(0, "");
    }

    function test_completeConfiguration_revert_zeroAssets() external {
        strategyManager.__setConfigured(false);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(0);

        vm.expectRevert("MSM:CC:ZERO_ASSETS");
        strategyManager.completeConfiguration(1e6, "");
    }

}

contract CompleteConfigurationSuccessTests is TestBase {

    function test_completeConfiguration_success() external {
        strategyManager.__setConfigured(false);

        assertEq(strategyManager.configured(),         false);
        assertEq(strategyManager.totalShares(),        0);
        assertEq(strategyManager.sharesOf(address(0)), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerConfigurationComplete();

        strategyManager.completeConfiguration(0, "");

        assertEq(strategyManager.configured(),         true);
        assertEq(strategyManager.totalShares(),        0);
        assertEq(strategyManager.sharesOf(address(0)), 0);
    }

    function test_completeConfiguration_success_withBootstrap() external {
        uint256 bootstrapAssets = 1e6;

        bytes memory bootstrapFundingData = abi.encode("bootstrap-funding-data");

        strategyManager.__setConfigured(false);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(bootstrapAssets);

        assertEq(strategyManager.configured(),         false);
        assertEq(strategyManager.totalShares(),        0);
        assertEq(strategyManager.sharesOf(address(0)), 0);

        vm.expectCall(
            underlyingStrategy,
            abi.encodeCall(MockStrategy.fundUnderlyingStrategy, (bootstrapAssets, bootstrapFundingData))
        );

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(address(0), bootstrapAssets, bootstrapAssets, bootstrapAssets);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerConfigurationComplete();

        strategyManager.completeConfiguration(bootstrapAssets, bootstrapFundingData);

        assertEq(strategyManager.configured(),         true);
        assertEq(strategyManager.totalShares(),        bootstrapAssets);
        assertEq(strategyManager.sharesOf(address(0)), bootstrapAssets);
    }

    function test_completeConfiguration_success_underlyingDepositsDifferentAmount() external {
        uint256 bootstrapAssets = 1e6;
        uint256 assetsDeposited = bootstrapAssets / 3;

        strategyManager.__setConfigured(false);

        MockStrategy(underlyingStrategy).__setFundUnderlyingStrategyReturn(assetsDeposited);

        assertEq(strategyManager.configured(),         false);
        assertEq(strategyManager.totalShares(),        0);
        assertEq(strategyManager.sharesOf(address(0)), 0);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerFunded(address(0), bootstrapAssets, assetsDeposited, assetsDeposited);

        vm.expectEmit();
        emit IMapleStrategyManager.StrategyManagerConfigurationComplete();

        strategyManager.completeConfiguration(bootstrapAssets, "");

        assertEq(strategyManager.configured(),         true);
        assertEq(strategyManager.totalShares(),        assetsDeposited);
        assertEq(strategyManager.sharesOf(address(0)), assetsDeposited);
    }

}
