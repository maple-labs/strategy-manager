// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

contract AssetsUnderManagementTests is TestBase {

    function test_assetsUnderManagement_success_zero() external view {
        assertEq(strategyManager.assetsUnderManagement(), 0);
    }

    function test_assetsUnderManagement_success_nonZero() external {
        uint256 aum = 100;

        setStrategyManagerState({
            aum_:         aum,
            totalShares_: 0
        });

        assertEq(strategyManager.assetsUnderManagement(), aum);
    }

}
