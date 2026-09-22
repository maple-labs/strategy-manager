// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MockStrategy } from "../../utils/Mocks.sol";
import { TestBase } from "../../utils/TestBase.sol";

contract UnrealizedLossesOfTests is TestBase {

    function test_unrealizedLossesOf_success_zeroTotalShares() external {
        MockStrategy(underlyingStrategy).__setUnrealizedLosses(100);

        assertEq(strategyManager.unrealizedLossesOf(poolManager), 0);
    }

    function test_unrealizedLossesOf_success_zeroPoolManagerShares() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(20);

        assertEq(strategyManager.unrealizedLossesOf(poolManager), 0);
    }

    function test_unrealizedLossesOf_success_proRata() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });
        strategyManager.__setSharesOf(poolManager, 4);

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(50);

        assertEq(strategyManager.unrealizedLossesOf(poolManager), 20);
    }

    function test_unrealizedLossesOf_success_roundsUp() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 3
        });
        strategyManager.__setSharesOf(poolManager, 1);

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(2);

        assertEq(strategyManager.unrealizedLossesOf(poolManager), 1);
    }

    function test_unrealizedLossesOf_success_totalUnrealizedLossesEqualsAum() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });
        strategyManager.__setSharesOf(poolManager, 5);

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(100);

        assertEq(strategyManager.unrealizedLossesOf(poolManager), 50);
    }

    function test_unrealizedLossesOf_success_clampsUnrealizedLossesToAum() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });
        strategyManager.__setSharesOf(poolManager, 5);

        MockStrategy(underlyingStrategy).__setUnrealizedLosses(200);

        assertEq(strategyManager.unrealizedLossesOf(poolManager), 50);
    }

}
