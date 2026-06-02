// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MockStrategy } from "../../utils/Mocks.sol";
import { TestBase }     from "../../utils/TestBase.sol";

contract IsAssetSupportedTests is TestBase {

    function test_isAssetSupported_success_supported() external view {
        assertEq(strategyManager.isAssetSupported(asset), true);
    }

    function test_isAssetSupported_success_notSupported() external {
        address otherAsset = makeAddr("otherAsset");

        assertEq(strategyManager.isAssetSupported(otherAsset), false);
    }

    function test_isAssetSupported_success_zeroAddress() external view {
        assertEq(strategyManager.isAssetSupported(address(0)), false);
    }

    function test_isAssetSupported_success_fundsAssetMutated() external {
        address newAsset = makeAddr("newAsset");

        assertEq(strategyManager.isAssetSupported(asset),    true);
        assertEq(strategyManager.isAssetSupported(newAsset), false);

        MockStrategy(underlyingStrategy).__setFundsAsset(newAsset);

        assertEq(strategyManager.isAssetSupported(asset),    false);
        assertEq(strategyManager.isAssetSupported(newAsset), true);
    }

}
