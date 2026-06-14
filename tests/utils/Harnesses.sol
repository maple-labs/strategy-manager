// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleStrategyManager }            from "../../contracts/MapleStrategyManager.sol";
import { MapleStrategyManagerInitializer } from "../../contracts/MapleStrategyManagerInitializer.sol";

contract MapleStrategyManagerHarness is MapleStrategyManager {

    function __setActive(bool active_) external {
        active = active_;
    }

    function __setConfigured(bool configured_) external {
        configured = configured_;
    }

    function __setLocked(uint256 locked_) external {
        _locked = locked_;
    }

    function __setPendingSharesOf(address poolManager_, uint256 pendingSharesOf_) external {
        pendingSharesOf[poolManager_] = pendingSharesOf_;
    }

    function __setSharesOf(address poolManager_, uint256 sharesOf_) external {
        sharesOf[poolManager_] = sharesOf_;
    }

    function __setTotalPendingShares(uint256 totalPendingShares_) external {
        totalPendingShares = totalPendingShares_;
    }

    function __setTotalShares(uint256 totalShares_) external {
        totalShares = totalShares_;
    }

    function __setUnderlyingStrategy(address underlyingStrategy_) external {
        underlyingStrategy = underlyingStrategy_;
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
