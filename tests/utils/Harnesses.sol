// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleStrategyManager }            from "../../contracts/MapleStrategyManager.sol";
import { MapleStrategyManagerInitializer } from "../../contracts/MapleStrategyManagerInitializer.sol";

contract MapleStrategyManagerHarness is MapleStrategyManager {

    function __setLocked(uint256 locked_) external {
        _locked = locked_;
    }

    function __setPoolCap(address poolManager_, uint256 poolCap_) external {
        poolCap[poolManager_] = poolCap_;
    }

    function __setSharesOf(address poolManager_, uint256 sharesOf_) external {
        sharesOf[poolManager_] = sharesOf_;
    }

    function __setTotalCap(uint256 totalCap_) external {
        totalCap = totalCap_;
    }

    function __setTotalShares(uint256 totalShares_) external {
        totalShares = totalShares_;
    }

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

}

contract MapleStrategyManagerInitializerHarness is MapleStrategyManagerInitializer {

    function __initialize(Parameters memory params_) external {
        _initialize(params_);
    }

}
