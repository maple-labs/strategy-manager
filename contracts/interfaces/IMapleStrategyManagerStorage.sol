// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines the storage layout of a Maple strategy manager.
 */
interface IMapleStrategyManagerStorage {

    /**
     *  @dev    Returns the per-pool deposit cap (in assets) for a given pool manager.
     *  @param  poolManager Address of the pool manager.
     *  @return poolCap     The maximum amount of assets the pool manager is authorized to deposit.
     */
    function poolCap(address poolManager) external view returns (uint256 poolCap);

    /**
     *  @dev    Returns the share balance held by a given pool manager.
     *  @param  poolManager Address of the pool manager.
     *  @return sharesOf    Number of shares owned by the pool manager.
     */
    function sharesOf(address poolManager) external view returns (uint256 sharesOf);

    /**
     *  @dev    Returns the total deposit cap (in assets) across all pool managers.
     *  @return totalCap The maximum total assets the strategy manager will accept.
     */
    function totalCap() external view returns (uint256 totalCap);

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
