// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

contract ConvertToAssetsTests is TestBase {

    function test_convertToAssets_success_zeroTotalShares() external view {
        assertEq(strategyManager.convertToAssets(100), 100);
    }

    function test_convertToAssets_success_proRata() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        assertEq(strategyManager.convertToAssets(5), 50);
    }

    function test_convertToAssets_success_roundsDown() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 3
        });

        assertEq(strategyManager.convertToAssets(1), 33);
    }

    function test_convertToAssets_success_zeroTotalAssetsWithNonZeroShares() external {
        setStrategyManagerState({
            aum_:         0,
            totalShares_: 100
        });

        assertEq(strategyManager.convertToAssets(100), 0);
    }

}
