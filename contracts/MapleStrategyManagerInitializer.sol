// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleStrategyManagerInitializer } from "./interfaces/IMapleStrategyManagerInitializer.sol";

import { MapleStrategyManagerStorage } from "./MapleStrategyManagerStorage.sol";

contract MapleStrategyManagerInitializer is IMapleStrategyManagerInitializer, MapleStrategyManagerStorage {

    // TODO: check whether further parameters such as fee or strategy metadata should be passed
    function _initialize(IMapleStrategyManagerInitializer.Parameters memory params_) internal {
        underlyingStrategy = params_.underlyingStrategy;

        _locked = 1;

        emit Initialized(params_);
    }

    fallback() external {
        _initialize(abi.decode(msg.data, (Parameters)));
    }

}
