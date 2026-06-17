// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { stdError } from "../../../modules/forge-std/src/StdError.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract ConvertToSharesTests is TestBase {

    function test_convertToShares_success_zeroTotalShares() external view {
        assertEq(strategyManager.convertToShares(100), 100);
    }

    function test_convertToShares_success_proRata() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 10
        });

        assertEq(strategyManager.convertToShares(50), 5);
    }

    function test_convertToShares_success_roundsDown() external {
        setStrategyManagerState({
            aum_:         100,
            totalShares_: 3
        });

        assertEq(strategyManager.convertToShares(1), 0);
    }

    function test_convertToShares_revert_zeroTotalAssetsWithNonZeroShares() external {
        setStrategyManagerState({
            aum_:         0,
            totalShares_: 100
        });

        vm.expectRevert(stdError.divisionError);
        strategyManager.convertToShares(100);
    }

}
