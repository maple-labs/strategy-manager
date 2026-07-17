// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IGlobalsLike {

    function bootstrapMint(address asset) external view returns (uint256 bootstrapMint);

    function canDeploy(address caller) external view returns (bool);

    function governor() external view returns (address);

    function isFunctionPaused(bytes4 signature) external view returns (bool);

    function isInstanceOf(bytes32 instanceId, address instance) external view returns (bool isInstance);

    function isStrategyDelegate(address account) external view returns (bool isStrategyDelegate);

    function operationalAdmin() external view returns (address);

    function securityAdmin() external view returns (address);

    function transferOwnedStrategyManager(address fromStrategyDelegate, address toStrategyDelegate) external;

}

interface IERC20Like {

    function transferFrom(address owner, address recipient, uint256 amount) external returns (bool success);

}

interface IProxyFactoryLike {

    function isInstance(address instance) external view returns (bool isInstance);

    function mapleGlobals() external view returns (address);

    function upgradeInstance(uint256 version, bytes calldata arguments) external;

}

interface IPoolManagerLike {

    function factory() external view returns (address factory);

    function pool() external view returns (address pool);

    function poolDelegate() external view returns (address poolDelegate);

    function requestFunds(address destination, uint256 principal) external;

}

interface IStrategyLike {

    function strategyManager() external view returns (address strategyManager);

}

interface IStrategyManagerLike {

    function cancelRedemption(address poolManager, uint256 shares) external;

    function factory() external view returns (address factory);

    function fundStrategyManager(address poolManager, uint256 assetsIn, bytes calldata data) external;

    function processRedemption(address poolManager, uint256 shares, bytes calldata data) external;

    function requestRedeem(address poolManager, uint256 shares) external;

}

interface IUnderlyingStrategyLike {

    function availableToWithdraw() external view returns (uint256 availableToWithdraw);

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    function fundsAsset() external view returns (address fundsAsset);

    function fundUnderlyingStrategy(uint256 assets, bytes calldata data) external returns (uint256 amount);

    function impairedAssets() external view returns (uint256 impairedAssets);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses);

    function withdrawFromUnderlyingStrategy(address destination, uint256 assets, bytes calldata data) external;

}
