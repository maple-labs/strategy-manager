// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IGlobalsLike {

    function canDeploy(address caller) external view returns (bool);

    function isFunctionPaused(bytes4 signature) external view returns (bool);

    function isInstanceOf(bytes32 instanceId, address instance) external view returns (bool isInstance);

    function securityAdmin() external view returns (address);

    function strategyDelegateOf(address strategyManager) external view returns (address);

}

interface IProxyFactoryLike {

    function isInstance(address instance) external view returns (bool isInstance);

    function mapleGlobals() external view returns (address);

    function upgradeInstance(uint256 version, bytes calldata arguments) external;

}

interface IPoolManagerLike {

    function factory() external view returns (address factory);

    function pool() external view returns (address pool);

    function requestFunds(address destination, uint256 principal) external;

}

interface IUnderlyingStrategyLike {

    function availableToWithdraw() external view returns (uint256 availableToWithdraw);

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    function fundUnderlyingStrategy(uint256 assets, bytes calldata data) external returns (uint256 amount);

    function withdrawFromUnderlyingStrategy(address destination, uint256 assets, bytes calldata data) external;

}
