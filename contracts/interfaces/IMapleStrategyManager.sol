// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxied } from "../../modules/proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleStrategyManagerStorage } from "./IMapleStrategyManagerStorage.sol";

/**
 *  @title Defines a Maple strategy manager.
 */
interface IMapleStrategyManager is IMapleStrategyManagerStorage, IMapleProxied {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted when a pool manager funds the strategy manager.
     *  @param poolManager     Address of the pool manager that received shares.
     *  @param assetsIn        Amount of assets pulled from the pool.
     *  @param assetsDeposited Amount of assets deposited into the underlying strategy.
     *  @param sharesMinted    Number of shares credited to the pool manager.
     */
    event StrategyManagerFunded(
        address indexed poolManager,
        uint256 assetsIn,
        uint256 assetsDeposited,
        uint256 sharesMinted
    );

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Pulls assets from a pool manager into the underlying strategy and credits the pool manager with shares.
     *  @param poolManager Address of the pool manager being funded.
     *  @param assetsIn    Amount of assets to pull from the pool.
     *  @param data        Arbitrary data forwarded to the underlying strategy on `fundUnderlyingStrategy`.
     */
    function fundStrategyManager(address poolManager, uint256 assetsIn, bytes calldata data) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the assets that belong to a given pool manager based on its share of total shares.
     *  @param  poolManager Address of the pool manager.
     *  @return assets      Assets currently belonging to the pool manager.
     */
    function assetsOf(address poolManager) external view returns (uint256 assets);

    /**
     *  @dev    Returns the total assets currently under management by the underlying strategy.
     *  @return assetsUnderManagement The total assets under management.
     */
    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    /**
     *  @dev    Returns the address of the Maple globals contract.
     *  @return globals Address of the Maple globals contract.
     */
    function globals() external view returns (address globals);

    /**
     *  @dev    Returns the address of the security admin.
     *  @return securityAdmin Address of the security admin.
     */
    function securityAdmin() external view returns (address securityAdmin);

}
