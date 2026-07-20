// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines a contract that deploys Maple strategies.
 */
interface IMapleStrategyDeployer {

    /**
     *  @dev   Emitted when a new strategy manager and its underlying strategy are deployed.
     *  @param strategyDelegate   Address of the strategy delegate.
     *  @param strategyManager    Address of the deployed strategy manager.
     *  @param underlyingStrategy Address of the deployed underlying strategy.
     */
    event StrategyManagerDeployed(
        address indexed strategyDelegate,
        address indexed strategyManager,
        address indexed underlyingStrategy
    );

    /**
     *  @dev    Deploys a strategy manager and underlying strategy.
     *  @param  strategyManagerFactory Address of the strategy manager factory.
     *  @param  strategyFactory        Address of the underlying strategy factory.
     *  @param  strategyLiquidityCap   Maximum total asset position the strategy manager can hold. A value of zero is
     *                                 left unset and can be configured later by an admin.
     *  @param  strategyDeploymentData Strategy initialization data.
     *  @param  bootstrapFundingData   Data forwarded to the underlying strategy when funding the bootstrap assets.
     *  @return strategyManager        Address of the deployed strategy manager.
     *  @return underlyingStrategy     Address of the deployed underlying strategy.
     */
    function deploy(
        address strategyManagerFactory,
        address strategyFactory,
        uint256 strategyLiquidityCap,
        bytes   calldata strategyDeploymentData,
        bytes   calldata bootstrapFundingData
    ) external returns (address strategyManager, address underlyingStrategy);

    /**
     *  @dev    Returns the address of the Maple globals contract.
     *  @return globals The address of the globals contract.
     */
    function globals() external view returns (address globals);

    /**
     *  @dev    Returns the addresses that would result from a deployment.
     *  @param  strategyDelegate       Address of the strategy delegate.
     *  @param  strategyManagerFactory Address of the strategy manager factory.
     *  @param  strategyFactory        Address of the underlying strategy factory.
     *  @param  strategyDeploymentData Strategy initialization data.
     *  @return strategyManager        Address of the strategy manager that will be deployed.
     *  @return underlyingStrategy     Address of the underlying strategy that will be deployed.
     */
    function getDeploymentAddresses(
        address strategyDelegate,
        address strategyManagerFactory,
        address strategyFactory,
        bytes calldata strategyDeploymentData
    )
        external view
        returns (address strategyManager, address underlyingStrategy);

}
