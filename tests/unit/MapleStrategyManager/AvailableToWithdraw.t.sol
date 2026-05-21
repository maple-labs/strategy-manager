// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

contract AvailableToWithdrawTests is TestBase {

    function test_availableToWithdraw_success() external {
        uint256 availableToWithdraw = 100;

        setStrategyManagerState({
            aum_:         availableToWithdraw,
            totalShares_: 0
        });

        assertEq(strategyManager.availableToWithdraw(), availableToWithdraw);
    }

}
