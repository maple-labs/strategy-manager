// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MockStrategy } from "../../utils/Mocks.sol";
import { TestBase }     from "../../utils/TestBase.sol";

contract ConvertToExitAssetsTests is TestBase {

    function test_convertToExitAssets_success_zeroTotalShares() external view {
        assertEq(strategyManager.convertToExitAssets(100), 100);
    }

    function test_convertToExitAssets_success_noUnrealizedLosses() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        assertEq(strategyManager.convertToExitAssets(5), 50);
    }

    function test_convertToExitAssets_success_subtractsUnrealizedLosses() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(20);

        assertEq(strategyManager.convertToExitAssets(5), 40);
    }

    function test_convertToExitAssets_success_roundsDown() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 3
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(20);

        assertEq(strategyManager.convertToExitAssets(1), 26);
    }

    function test_convertToExitAssets_success_zeroTotalExitAssets() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(100);

        assertEq(strategyManager.convertToExitAssets(5), 0);
    }

    function test_convertToExitAssets_success_clampsUnrealizedLossesToAum() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(200);

        assertEq(strategyManager.convertToExitAssets(5), 0);
    }

}
