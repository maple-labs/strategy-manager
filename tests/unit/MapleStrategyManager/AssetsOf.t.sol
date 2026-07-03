// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

contract AssetsOfTests is TestBase {

    function test_assetsOf_success_zeroTotalShares() external view {
        assertEq(strategyManager.assetsOf(poolManager), 0);
    }

    function test_assetsOf_success_zeroPoolManagerShares() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        assertEq(strategyManager.assetsOf(poolManager), 0);
    }

    function test_assetsOf_success_proRata() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });
        strategyManager.__setSharesOf(poolManager, 5);

        assertEq(strategyManager.assetsOf(poolManager), 50);
    }

    function test_assetsOf_success_ownsAllShares() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });
        strategyManager.__setSharesOf(poolManager, 10);

        assertEq(strategyManager.assetsOf(poolManager), 100);
    }

    function test_assetsOf_success_roundsDown() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 3
        });
        strategyManager.__setSharesOf(poolManager, 1);

        assertEq(strategyManager.assetsOf(poolManager), 33);
    }

    function test_assetsOf_success_zeroTotalAssetsWithNonZeroShares() external {
        setStrategyManagerState({
            aum_:         0,
            totalShares_: 100
        });
        strategyManager.__setSharesOf(poolManager, 50);

        assertEq(strategyManager.assetsOf(poolManager), 0);
    }

}
