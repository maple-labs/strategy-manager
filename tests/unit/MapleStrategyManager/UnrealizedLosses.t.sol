// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MockStrategy } from "../../utils/Mocks.sol";
import { TestBase } from "../../utils/TestBase.sol";

contract UnrealizedLossesTests is TestBase {

    function test_unrealizedLosses_success_zero() external {
        assertEq(strategyManager.unrealizedLosses(), 0);
    }

    function test_unrealizedLosses_success_belowAum() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(40);

        assertEq(strategyManager.unrealizedLosses(), 40);
    }

    function test_unrealizedLosses_success_equalsAum() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(100);

        assertEq(strategyManager.unrealizedLosses(), 100);
    }

    function test_unrealizedLosses_success_clampsToAum() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(200);

        assertEq(strategyManager.unrealizedLosses(), 100);
    }

}
