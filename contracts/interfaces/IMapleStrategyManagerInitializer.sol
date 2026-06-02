// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines a contract used to initialize new Maple strategy managers.
 */
interface IMapleStrategyManagerInitializer {

    /**
     *  @dev   Parameters required to initialize a strategy manager.
     *  @param strategyDelegate   Address of the strategy delegate.
     *  @param underlyingStrategy Address of the underlying strategy.
     */
    struct Parameters {
        address strategyDelegate;
        address underlyingStrategy;
    }

    /**
     *  @dev   Emitted when the strategy manager proxy is initialized.
     *  @param params Strategy manager parameters set during initialization.
     */
    event Initialized(Parameters params);

}
