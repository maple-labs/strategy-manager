// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { MapleProxiedInternals } from "../modules/proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleStrategyManager }           from "./interfaces/IMapleStrategyManager.sol";
import { IGlobalsLike, IProxyFactoryLike } from "./interfaces/Interfaces.sol";

import { MapleStrategyManagerStorage } from "./MapleStrategyManagerStorage.sol";

contract MapleStrategyManager is IMapleStrategyManager, MapleStrategyManagerStorage, MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier nonReentrant() {
        require(_locked == 1, "MSM:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyFactory() {
        require(msg.sender == _factory(), "MSM:NOT_FACTORY");

        _;
    }

    // TODO: Determine where the strategy delegate address will be retrieved from.
    modifier onlyStrategyDelegate() {
        require(msg.sender == IGlobalsLike(globals()).strategyDelegateOf(address(this)), "MSM:NOT_STRATEGY_DELEGATE");

        _;
    }

    // TODO: Should this be renamed to `whenNotPaused`?
    modifier whenProtocolNotPaused() {
        require(!IGlobalsLike(globals()).isFunctionPaused(msg.sig), "MSM:PAUSED");

        _;
    }

    /**************************************************************************************************************************************/
    /*** Proxy Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override whenProtocolNotPaused onlyFactory {
        require(_migrate(migrator_, arguments_), "MSM:M:FAILED");
    }

    function setImplementation(address implementation_) external override whenProtocolNotPaused onlyFactory {
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenProtocolNotPaused {
        require(msg.sender == securityAdmin(), "MSM:U:NOT_AUTHORIZED");

        IProxyFactoryLike(_factory()).upgradeInstance(version_, arguments_);

        emit Upgraded(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function factory() external view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view override returns (address globals_) {
        globals_ = IProxyFactoryLike(_factory()).mapleGlobals();
    }

    function implementation() external view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function securityAdmin() public view override returns (address securityAdmin_) {
        securityAdmin_ = IGlobalsLike(globals()).securityAdmin();
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

}
