// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines a contract that deploys Maple strategies.
 */
interface IMapleStrategyDeployer {

    /**
     *  @dev    Returns the address of the Maple globals contract.
     *  @return globals The address of the globals contract.
     */
    function globals() external view returns (address globals);

}
