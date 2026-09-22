// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.34;

import { IMapleStrategyManagerInitializer } from "./interfaces/IMapleStrategyManagerInitializer.sol";
import { IGlobalsLike, IProxyFactoryLike } from "./interfaces/Interfaces.sol";

import { MapleStrategyManagerStorage } from "./MapleStrategyManagerStorage.sol";

contract MapleStrategyManagerInitializer is IMapleStrategyManagerInitializer, MapleStrategyManagerStorage {

    function _initialize(IMapleStrategyManagerInitializer.Parameters memory params_) internal {
        require(params_.strategyDelegate != address(0), "MSMI:I:ZERO_STRATEGY_DELEGATE");

        address globals_ = IProxyFactoryLike(msg.sender).mapleGlobals();

        require(IGlobalsLike(globals_).isStrategyDelegate(params_.strategyDelegate), "MSMI:I:INVALID_DELEGATE");

        strategyDelegate = params_.strategyDelegate;

        _locked = 1;

        emit Initialized(params_);
    }

    fallback() external {
        _initialize(abi.decode(msg.data, (Parameters)));
    }

}
