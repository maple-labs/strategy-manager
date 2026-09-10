// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { stdError } from "../../../modules/forge-std/src/StdError.sol";

import { MockStrategy } from "../../utils/Mocks.sol";
import { TestBase }     from "../../utils/TestBase.sol";

contract ConvertToExitSharesTests is TestBase {

    function test_convertToExitShares_revert_underflow_zeroAssetsZeroTotalExitAssets() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(100);

        vm.expectRevert(stdError.arithmeticError);
        strategyManager.convertToExitShares(0);
    }

    function test_convertToExitShares_revert_zeroTotalExitAssets() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(100);

        vm.expectRevert(stdError.divisionError);
        strategyManager.convertToExitShares(1);
    }

    function test_convertToExitShares_revert_clampsUnrealizedLossesToAum() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(200);

        vm.expectRevert(stdError.divisionError);
        strategyManager.convertToExitShares(1);
    }

    function test_convertToExitShares_success_zeroTotalShares() external view {
        assertEq(strategyManager.convertToExitShares(100), 100);
    }

    function test_convertToExitShares_success_zeroAssetsNonZeroTotalExitAssets() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(20);

        assertEq(strategyManager.convertToExitShares(0), 0);
    }

    function test_convertToExitShares_success_noUnrealizedLosses() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        assertEq(strategyManager.convertToExitShares(50), 5);
    }

    function test_convertToExitShares_success_subtractsUnrealizedLosses() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(20);

        assertEq(strategyManager.convertToExitShares(40), 5);
    }

    function test_convertToExitShares_success_roundsUp() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 3
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(20);

        assertEq(strategyManager.convertToExitShares(1), 1);
    }

}
