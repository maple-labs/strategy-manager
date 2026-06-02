// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleStrategyManagerInitializer } from "./interfaces/IMapleStrategyManagerInitializer.sol";
import { IGlobalsLike, IProxyFactoryLike }  from "./interfaces/Interfaces.sol";

import { MapleStrategyManagerStorage } from "./MapleStrategyManagerStorage.sol";

contract MapleStrategyManagerInitializer is IMapleStrategyManagerInitializer, MapleStrategyManagerStorage {

    // TODO: check whether further parameters such as fee or strategy metadata should be passed
    function _initialize(IMapleStrategyManagerInitializer.Parameters memory params_) internal {
        require(params_.strategyDelegate   != address(0), "MSMI:I:ZERO_STRATEGY_DELEGATE");
        require(params_.underlyingStrategy != address(0), "MSMI:I:ZERO_UNDERLYING_STRATEGY");

        address globals_ = IProxyFactoryLike(msg.sender).mapleGlobals();

        require(IGlobalsLike(globals_).isStrategyDelegate(params_.strategyDelegate), "MSMI:I:INVALID_DELEGATE");

        strategyDelegate   = params_.strategyDelegate;
        underlyingStrategy = params_.underlyingStrategy;

        _locked = 1;

        emit Initialized(params_);
    }

    fallback() external {
        _initialize(abi.decode(msg.data, (Parameters)));
    }

}
