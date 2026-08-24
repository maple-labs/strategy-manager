// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.34;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { IMapleProxyFactory } from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import { IMapleStrategyDeployer } from "./interfaces/IMapleStrategyDeployer.sol";
import { IMapleStrategyManager }  from "./interfaces/IMapleStrategyManager.sol";

import {
    IGlobalsLike,
    IStrategyLike,
    IUnderlyingStrategyLike
} from "./interfaces/Interfaces.sol";

contract MapleStrategyDeployer is IMapleStrategyDeployer {

    address public override immutable globals;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(address globals_) {
        require(globals_ != address(0), "MSD:C:ZERO_GLOBALS");

        globals = globals_;
    }

    /**************************************************************************************************************************************/
    /*** Deployment Functions                                                                                                           ***/
    /**************************************************************************************************************************************/

    function deploy(
        address        strategyManagerFactory_,
        address        strategyFactory_,
        uint256        strategyLiquidityCap_,
        bytes calldata strategyDeploymentData_,
        bytes calldata bootstrapFundingData_
    )
        external override returns (address strategyManager_, address underlyingStrategy_)
    {
        address      strategyDelegate_ = msg.sender;
        bytes32      salt_             = keccak256(abi.encode(strategyDelegate_));
        IGlobalsLike globals_          = IGlobalsLike(globals);

        require(globals_.isStrategyDelegate(strategyDelegate_),                                "MSD:D:INVALID_SD");
        require(globals_.isInstanceOf("STRATEGY_MANAGER_FACTORY",    strategyManagerFactory_), "MSD:D:INVALID_SM_FACTORY");
        require(globals_.isInstanceOf("UNDERLYING_STRATEGY_FACTORY", strategyFactory_),        "MSD:D:INVALID_STRATEGY_FACTORY");

        strategyManager_ = IMapleProxyFactory(strategyManagerFactory_).createInstance(abi.encode(strategyDelegate_), salt_);

        bytes memory fullStrategyDeploymentData_ = bytes.concat(abi.encode(strategyManager_), strategyDeploymentData_);

        address underlyingStrategyPredicted_ =
            IMapleProxyFactory(strategyFactory_).getInstanceAddress(fullStrategyDeploymentData_, salt_);

        IMapleStrategyManager(strategyManager_).setUnderlyingStrategy(underlyingStrategyPredicted_);

        underlyingStrategy_ = IMapleProxyFactory(strategyFactory_).createInstance(fullStrategyDeploymentData_, salt_);

        require(IMapleStrategyManager(strategyManager_).underlyingStrategy() == underlyingStrategy_, "MSD:D:INVALID_STRATEGY");
        require(IStrategyLike(underlyingStrategy_).strategyManager()         == strategyManager_,    "MSD:D:INVALID_STRATEGY_MANAGER");

        address fundsAsset_      = IUnderlyingStrategyLike(underlyingStrategy_).fundsAsset();
        uint256 bootstrapAssets_ = globals_.bootstrapMint(fundsAsset_);

        if (bootstrapAssets_ != 0) {
            require(
                ERC20Helper.transferFrom(fundsAsset_, strategyDelegate_, underlyingStrategy_, bootstrapAssets_),
                "MSD:D:BOOTSTRAP_TRANSFER_FAILED"
            );
        }

        if (strategyLiquidityCap_ != 0) {
            IMapleStrategyManager(strategyManager_).setStrategyLiquidityCap(strategyLiquidityCap_);
        }

        IMapleStrategyManager(strategyManager_).completeConfiguration(bootstrapAssets_, bootstrapFundingData_);

        emit StrategyManagerDeployed(strategyDelegate_, strategyManager_, underlyingStrategy_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function getDeploymentAddresses(
        address        strategyDelegate_,
        address        strategyManagerFactory_,
        address        strategyFactory_,
        bytes calldata strategyDeploymentData_
    )
        external view override returns (address strategyManager_, address underlyingStrategy_)
    {
        bytes32 salt_ = keccak256(abi.encode(strategyDelegate_));

        strategyManager_ = IMapleProxyFactory(strategyManagerFactory_).getInstanceAddress(abi.encode(strategyDelegate_), salt_);

        bytes memory fullStrategyDeploymentData_ = bytes.concat(abi.encode(strategyManager_), strategyDeploymentData_);

        underlyingStrategy_ = IMapleProxyFactory(strategyFactory_).getInstanceAddress(fullStrategyDeploymentData_, salt_);
    }

}
