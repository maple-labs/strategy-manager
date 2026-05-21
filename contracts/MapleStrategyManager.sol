// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { MapleProxiedInternals } from "../modules/proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleStrategyManager } from "./interfaces/IMapleStrategyManager.sol";

import {
    IGlobalsLike,
    IProxyFactoryLike,
    IPoolManagerLike,
    IUnderlyingStrategyLike
} from "./interfaces/Interfaces.sol";

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

    modifier onlyOperator() {
        address globals_ = globals();

        require(
            IGlobalsLike(globals_).isInstanceOf("LIQUIDITY_BOT",    msg.sender) ||
            IGlobalsLike(globals_).isInstanceOf("LIQUIDITY_ROUTER", msg.sender) ||
            msg.sender == IGlobalsLike(globals_).strategyDelegateOf(address(this)),
            "MSM:NOT_AUTHORIZED"
        );

        _;
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

    function cancelRedemption(address poolManager_, uint256 shares_) external override whenProtocolNotPaused nonReentrant onlyOperator {
        require(shares_ != 0,                             "MSM:CR:ZERO_SHARES");
        require(shares_ <= pendingSharesOf[poolManager_], "MSM:CR:INSUFFICIENT_SHARES");

        pendingSharesOf[poolManager_] -= shares_;
        totalPendingShares            -= shares_;

        emit RedemptionCancelled(poolManager_, shares_);
    }

    // TODO: Consider adding minShares. What can go wrong if bot key gets compromised.
    function fundStrategyManager(address poolManager_, uint256 assetsIn_, bytes calldata data_)
        external override whenProtocolNotPaused nonReentrant onlyOperator
    {
        require(assetsIn_ != 0, "MSM:FSM:ZERO_ASSETS");

        address factory_ = IPoolManagerLike(poolManager_).factory();

        require(IGlobalsLike(globals()).isInstanceOf("POOL_MANAGER_FACTORY", factory_), "MSM:FSM:INVALID_PM_FACTORY");
        // TODO: validate the poolManager is also attached to the strategy
        require(IProxyFactoryLike(factory_).isInstance(poolManager_),                   "MSM:FSM:INVALID_PM");

        address underlyingStrategy_ = underlyingStrategy;
        uint256 totalAssetsBefore_  = assetsUnderManagement();

        IPoolManagerLike(poolManager_).requestFunds(underlyingStrategy_, assetsIn_);

        // TODO: Check if underlying strategy will always implement this function or we need to check before calling.
        uint256 assetsDeposited_ = IUnderlyingStrategyLike(underlyingStrategy_).fundUnderlyingStrategy(assetsIn_, data_);
        uint256 sharesMinted_    = _convertToShares(assetsDeposited_, totalAssetsBefore_);

        require(sharesMinted_ != 0, "MSM:FSM:ZERO_SHARES");

        sharesOf[poolManager_] += sharesMinted_;
        totalShares            += sharesMinted_;

        require(assetsOf(poolManager_)  <= poolCap[poolManager_], "MSM:FSM:POOL_CAP");
        require(assetsUnderManagement() <= totalCap,              "MSM:FSM:TOTAL_CAP");

        emit StrategyManagerFunded(poolManager_, assetsIn_, assetsDeposited_, sharesMinted_);
    }

    // TODO: Do we need to validate poolManager here? Consider adding minAssets?
    function processRedemption(
        address poolManager_,
        uint256 shares_,
        bytes calldata data_
    )
        external override whenProtocolNotPaused nonReentrant onlyOperator
    {
        require(shares_ != 0,                             "MSM:PR:ZERO_SHARES");
        require(shares_ <= pendingSharesOf[poolManager_], "MSM:PR:EXCEEDS_REQUESTED");

        uint256 assets_ = _convertToAssets(shares_, assetsUnderManagement());

        require(assets_ != 0,                     "MSM:PR:ZERO_ASSETS");
        require(assets_ <= availableToWithdraw(), "MSM:PR:NOT_ENOUGH_LIQUIDITY");

        pendingSharesOf[poolManager_] -= shares_;
        totalPendingShares            -= shares_;

        sharesOf[poolManager_] -= shares_;
        totalShares            -= shares_;

        IUnderlyingStrategyLike(underlyingStrategy).withdrawFromUnderlyingStrategy(
            IPoolManagerLike(poolManager_).pool(),
            assets_,
            data_
        );

        // TODO: Consider emitting data as well?
        emit RedemptionProcessed(poolManager_, shares_, assets_);
    }

    // TODO: Do we need to validate poolManager here?
    function requestRedeem(address poolManager_, uint256 shares_) external override whenProtocolNotPaused nonReentrant onlyOperator {
        uint256 remainingShares_ = sharesOf[poolManager_] - pendingSharesOf[poolManager_];

        require(shares_ != 0,                "MSM:RR:ZERO_SHARES");
        require(shares_ <= remainingShares_, "MSM:RR:INSUFFICIENT_SHARES");

        pendingSharesOf[poolManager_] += shares_;
        totalPendingShares            += shares_;

        emit RedemptionRequested(poolManager_, shares_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function assetsOf(address poolManager_) public view override returns (uint256 assets_) {
        assets_ = _convertToAssets(sharesOf[poolManager_], assetsUnderManagement());
    }

    function availableToWithdraw() public view override returns (uint256 availableToWithdraw_) {
        availableToWithdraw_ = IUnderlyingStrategyLike(underlyingStrategy).availableToWithdraw();
    }

    function assetsUnderManagement() public view override returns (uint256 assetsUnderManagement_) {
        assetsUnderManagement_ = IUnderlyingStrategyLike(underlyingStrategy).assetsUnderManagement();
    }

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

    function _convertToAssets(uint256 shares_, uint256 totalAssets_) internal view returns (uint256 assets_) {
        uint256 totalShares_ = totalShares;

        if (totalShares_ == 0) return shares_;

        assets_ = shares_ * totalAssets_ / totalShares_;
    }

    function _convertToShares(uint256 assets_, uint256 totalAssets_) internal view returns (uint256 shares_) {
        uint256 totalShares_ = totalShares;

        if (totalShares_ == 0) return assets_;

        // TODO: What if totalAssets_ = 0 but totalShares_ > 0? Currently we are following the same pattern as we have in MaplePool.sol
        //       Reconsider if this is the desired behavior.
        shares_ = assets_ * totalShares_ / totalAssets_;
    }

}
