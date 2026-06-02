// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines the storage layout of a Maple strategy manager.
 */
interface IMapleStrategyManagerStorage {

    /**
     *  @dev    Returns whether or not the strategy manager is active.
     *  @return active True if the strategy manager is active.
     */
    function active() external view returns (bool active);

    /**
     *  @dev    Returns whether or not the strategy manager is configured.
     *  @return configured True if the strategy manager is configured.
     */
    function configured() external view returns (bool configured);

    /**
     *  @dev    Returns the per-pool-manager maximum asset position for a given pool manager.
     *  @param  poolManager      Address of the pool manager.
     *  @return poolManagerCapOf The maximum asset position the pool manager is authorized to hold.
     */
    function poolManagerCapOf(address poolManager) external view returns (uint256 poolManagerCapOf);

    /**
     *  @dev    Returns the address of the pending strategy delegate.
     *  @return pendingStrategyDelegate The address of the pending strategy delegate.
     */
    function pendingStrategyDelegate() external view returns (address pendingStrategyDelegate);

    /**
     *  @dev    Returns the number of pending redemption shares held by a given pool manager.
     *  @param  poolManager     Address of the pool manager.
     *  @return pendingSharesOf Number of shares the pool manager has requested to redeem but has not yet processed.
     */
    function pendingSharesOf(address poolManager) external view returns (uint256 pendingSharesOf);

    /**
     *  @dev    Returns the share balance held by a given pool manager.
     *  @param  poolManager Address of the pool manager.
     *  @return sharesOf    Number of shares owned by the pool manager.
     */
    function sharesOf(address poolManager) external view returns (uint256 sharesOf);

    /**
     *  @dev    Returns the address of the strategy delegate.
     *  @return strategyDelegate The address of the strategy delegate.
     */
    function strategyDelegate() external view returns (address strategyDelegate);

    /**
     *  @dev    Returns the maximum exposure to the strategy.
     *  @return strategyLiquidityCap The maximum total asset position the strategy manager is authorized to hold.
     */
    function strategyLiquidityCap() external view returns (uint256 strategyLiquidityCap);

    /**
     *  @dev    Returns the total number of pending redemption shares across all pool managers.
     *  @return totalPendingShares Sum of all pending redemption shares.
     */
    function totalPendingShares() external view returns (uint256 totalPendingShares);

    /**
     *  @dev    Returns the total number of shares issued by the strategy manager.
     *  @return totalShares Sum of all shares across pool managers.
     */
    function totalShares() external view returns (uint256 totalShares);

    /**
     *  @dev    Returns the address of the underlying strategy contract.
     *  @return underlyingStrategy Address of the underlying strategy.
     */
    function underlyingStrategy() external view returns (address underlyingStrategy);

}
