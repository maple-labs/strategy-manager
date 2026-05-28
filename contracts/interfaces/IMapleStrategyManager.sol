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
     *  @dev   Emitted when a pool manager's maximum asset position is set.
     *  @param poolManager Address of the pool manager whose cap was set.
     *  @param cap         The maximum asset position the pool manager is authorized to hold.
     */
    event PoolManagerCapSet(address indexed poolManager, uint256 cap);

    /**
     *  @dev   Emitted when a pending redemption is cancelled for a pool manager.
     *  @param poolManager     Address of the pool manager whose pending shares were reduced.
     *  @param sharesCancelled Number of pending shares cancelled.
     */
    event RedemptionCancelled(address indexed poolManager, uint256 sharesCancelled);

    /**
     *  @dev   Emitted when a pending redemption is processed for a pool manager.
     *  @param poolManager     Address of the pool manager whose shares were redeemed.
     *  @param sharesProcessed Number of shares processed for redemption.
     *  @param assetsWithdrawn  Number of assets withdrawn from the underlying strategy.
     */
    event RedemptionProcessed(address indexed poolManager, uint256 sharesProcessed, uint256 assetsWithdrawn);

    /**
     *  @dev   Emitted when a redemption is requested for a pool manager.
     *  @param poolManager     Address of the pool manager whose shares are being queued for redemption.
     *  @param sharesRequested Number of shares queued for redemption.
     */
    event RedemptionRequested(address indexed poolManager, uint256 sharesRequested);

    /**
     *  @dev   Emitted when the strategy manager's maximum total asset position is set.
     *  @param cap The maximum total asset position the strategy manager is authorized to hold.
     */
    event StrategyLiquidityCapSet(uint256 cap);

    /**
     *  @dev Emitted when the strategy manager configuration is marked as complete.
     */
    event StrategyManagerConfigurationComplete();

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
    /*** Initial Configuration Functions                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev Complete the configuration.
     */
    function completeConfiguration() external;

    /**************************************************************************************************************************************/
    /*** Liquidity Management Functions                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Cancels a previously queued redemption, reducing the pool manager's pending shares.
     *  @param poolManager Address of the pool manager whose redemption is being cancelled.
     *  @param shares      Number of pending shares to cancel.
     */
    function cancelRedemption(address poolManager, uint256 shares) external;

    /**
     *  @dev   Pulls assets from a pool manager into the underlying strategy and credits the pool manager with shares.
     *  @param poolManager Address of the pool manager being funded.
     *  @param assetsIn    Amount of assets to pull from the pool.
     *  @param data        Arbitrary data forwarded to the underlying strategy on `fundUnderlyingStrategy`.
     */
    function fundStrategyManager(address poolManager, uint256 assetsIn, bytes calldata data) external;

    /**
     *  @dev    Process a pending redemption.
     *          Withdraws from underlying strategy and sends assets directly to pool.
     *  @param  poolManager Address of the pool manager whose redemption to process.
     *  @param  shares      Amount of shares to process.
     *  @param  data        Arbitrary data forwarded to the underlying strategy on `withdrawFromUnderlyingStrategy`.
     */
    function processRedemption(address poolManager, uint256 shares, bytes calldata data) external;

    /**
     *  @dev   Requests a redemption of shares for a pool manager. Does not reduce the pool manager's share balance until
     *         the redemption is processed.
     *  @param poolManager Address of the pool manager requesting the redemption.
     *  @param shares      Number of shares to queue for redemption.
     */
    function requestRedeem(address poolManager, uint256 shares) external;

    /**************************************************************************************************************************************/
    /*** Administrative Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Sets the maximum asset position a pool manager can have in the strategy manager.
     *  @param poolManager Address of the pool manager whose cap is being set.
     *  @param cap         Maximum asset position the pool manager can have in the strategy manager.
     */
    function setPoolManagerCap(address poolManager, uint256 cap) external;

    /**
     *  @dev   Sets the maximum total asset position the strategy manager can have.
     *  @param cap Maximum total asset position the strategy manager can have.
     */
    function setStrategyLiquidityCap(uint256 cap) external;

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
     *  @dev    Returns the assets currently available to withdraw from the underlying strategy.
     *  @return availableToWithdraw Assets available to withdraw.
     */
    function availableToWithdraw() external view returns (uint256 availableToWithdraw);

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
