// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleStrategyManager }            from "../../contracts/MapleStrategyManager.sol";
import { MapleStrategyManagerInitializer } from "../../contracts/MapleStrategyManagerInitializer.sol";

contract MapleStrategyManagerHarness is MapleStrategyManager {

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

}

contract MapleStrategyManagerInitializerHarness is MapleStrategyManagerInitializer {

    function __initialize(Parameters memory params_) external {
        _initialize(params_);
    }

}
