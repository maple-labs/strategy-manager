// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines the storage layout of a Maple strategy manager.
 */
interface IMapleStrategyManagerStorage {

    /**
     *  @dev    Returns the address of the underlying strategy contract.
     *  @return underlyingStrategy Address of the underlying strategy.
     */
    function underlyingStrategy() external view returns (address underlyingStrategy);

}
