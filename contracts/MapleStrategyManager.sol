// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { MapleProxiedInternals } from "../modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol";

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
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier nonReentrant() {
        require(_locked == 1, "MSM:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyAdminsOrNotConfigured() {
        if (configured) {
            address globals_ = globals();

            require(
                msg.sender == strategyDelegate ||
                msg.sender == IGlobalsLike(globals_).operationalAdmin(),
                "MSM:NOT_ADMIN"
            );
        }

        _;
    }

    modifier onlyFactory() {
        require(msg.sender == _factory(), "MSM:NOT_FACTORY");

        _;
    }

    modifier onlyOperator() {
        require(_isOperator(), "MSM:NOT_OPERATOR");

        _;
    }

    modifier onlyOperatorOrPoolDelegate(address poolManager_) {
        require(
            _isOperator() || msg.sender == IPoolManagerLike(poolManager_).poolDelegate(),
            "MSM:NOT_OPERATOR_OR_PD"
        );

        _;
    }

    modifier whenNotPaused() {
        require(!IGlobalsLike(globals()).isFunctionPaused(msg.sig), "MSM:PAUSED");

        _;
    }

    /**************************************************************************************************************************************/
    /*** Proxy Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override whenNotPaused onlyFactory {
        require(_migrate(migrator_, arguments_), "MSM:M:FAILED");
    }

    function setImplementation(address implementation_) external override whenNotPaused onlyFactory {
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenNotPaused {
        require(msg.sender == securityAdmin(), "MSM:U:NOT_AUTHORIZED");

        IProxyFactoryLike(_factory()).upgradeInstance(version_, arguments_);

        emit Upgraded(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** Initial Configuration Functions                                                                                                ***/
    /**************************************************************************************************************************************/

    // NOTE: This function is always called atomically during the deployment process so a DoS attack is not possible.
    function completeConfiguration(uint256 bootstrapAssets_, bytes calldata bootstrapFundingData_)
        external override whenNotPaused nonReentrant
    {
        require(!configured, "MSM:CC:ALREADY_CONFIGURED");

        if (bootstrapAssets_ != 0) {
            uint256 assetsDeposited_ =
                IUnderlyingStrategyLike(underlyingStrategy).fundUnderlyingStrategy(bootstrapAssets_, bootstrapFundingData_);

            require(assetsDeposited_ != 0, "MSM:CC:ZERO_ASSETS");

            sharesOf[address(0)] = assetsDeposited_;
            totalShares          = assetsDeposited_;

            emit StrategyManagerFunded(address(0), bootstrapAssets_, assetsDeposited_, assetsDeposited_);
        }

        configured = true;

        emit StrategyManagerConfigurationComplete();
    }

    // NOTE: This function is always called atomically during the deployment process so a DoS attack is not possible.
    function setUnderlyingStrategy(address underlyingStrategy_) external override whenNotPaused {
        require(!configured, "MSM:SUS:ALREADY_CONFIGURED");

        underlyingStrategy = underlyingStrategy_;

        emit UnderlyingStrategySet(underlyingStrategy_);
    }

    /**************************************************************************************************************************************/
    /*** Globals Admin Functions                                                                                                        ***/
    /**************************************************************************************************************************************/

    function setActive(bool active_) external override whenNotPaused {
        require(msg.sender == globals(), "MSM:SA:NOT_GLOBALS");

        active = active_;

        emit SetAsActive(active_);
    }

    /**************************************************************************************************************************************/
    /*** Ownership Transfer Functions                                                                                                   ***/
    /**************************************************************************************************************************************/

    function acceptStrategyDelegate() external override whenNotPaused {
        address pendingStrategyDelegate_ = pendingStrategyDelegate;
        address strategyDelegate_        = strategyDelegate;

        require(msg.sender == pendingStrategyDelegate_, "MSM:ASD:NOT_PENDING_SD");

        IGlobalsLike(globals()).transferOwnedStrategyManager(strategyDelegate_, pendingStrategyDelegate_);

        delete pendingStrategyDelegate;
        strategyDelegate = pendingStrategyDelegate_;

        emit PendingStrategyDelegateAccepted(strategyDelegate_, pendingStrategyDelegate_);
    }

    function setPendingStrategyDelegate(address pendingStrategyDelegate_) external override whenNotPaused {
        require(msg.sender == IGlobalsLike(globals()).operationalAdmin(), "MSM:SPSD:NOT_OPERATIONAL_ADMIN");

        pendingStrategyDelegate = pendingStrategyDelegate_;

        emit PendingStrategyDelegateSet(pendingStrategyDelegate_);
    }

    /**************************************************************************************************************************************/
    /*** Liquidity Management Functions                                                                                                ***/
    /**************************************************************************************************************************************/

    function cancelRedemption(
        address poolManager_,
        uint256 shares_
    )
        external override whenNotPaused nonReentrant onlyOperatorOrPoolDelegate(poolManager_)
    {
        require(_isValidPoolManager(poolManager_),        "MSM:CR:INVALID_PM");
        require(shares_ != 0,                             "MSM:CR:ZERO_SHARES");
        require(shares_ <= pendingSharesOf[poolManager_], "MSM:CR:INSUFFICIENT_SHARES");

        pendingSharesOf[poolManager_] -= shares_;
        totalPendingShares            -= shares_;

        emit RedemptionCancelled(poolManager_, shares_);
    }

    function fundStrategyManager(address poolManager_, uint256 assetsIn_, bytes calldata data_)
        external override whenNotPaused nonReentrant onlyOperator
    {
        require(active,                            "MSM:FSM:NOT_ACTIVE");
        require(assetsIn_ != 0,                    "MSM:FSM:ZERO_ASSETS");
        require(_isValidPoolManager(poolManager_), "MSM:FSM:INVALID_PM");

        address underlyingStrategy_ = underlyingStrategy;
        uint256 totalAssetsBefore_  = assetsUnderManagement();

        IPoolManagerLike(poolManager_).requestFunds(underlyingStrategy_, assetsIn_);

        uint256 assetsDeposited_ = IUnderlyingStrategyLike(underlyingStrategy_).fundUnderlyingStrategy(assetsIn_, data_);
        uint256 sharesMinted_    = _convertToShares(assetsDeposited_, totalAssetsBefore_);

        require(sharesMinted_ != 0, "MSM:FSM:ZERO_SHARES");

        sharesOf[poolManager_] += sharesMinted_;
        totalShares            += sharesMinted_;

        require(_isWithinPoolManagerCap(poolManager_),           "MSM:FSM:POOL_MANAGER_CAP");
        require(assetsUnderManagement() <= strategyLiquidityCap, "MSM:FSM:STRATEGY_LIQUIDITY_CAP");

        emit StrategyManagerFunded(poolManager_, assetsIn_, assetsDeposited_, sharesMinted_);
    }

    function processRedemption(
        address poolManager_,
        uint256 shares_,
        bytes calldata data_
    )
        external override whenNotPaused nonReentrant onlyOperator
    {
        require(_isValidPoolManager(poolManager_),        "MSM:PR:INVALID_PM");
        require(shares_ != 0,                             "MSM:PR:ZERO_SHARES");
        require(shares_ <= pendingSharesOf[poolManager_], "MSM:PR:EXCEEDS_REQUESTED");

        uint256 assets_ = _convertToExitAssets(shares_, assetsUnderManagement());

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

        emit RedemptionProcessed(poolManager_, shares_, assets_);
    }

    function requestRedeem(
        address poolManager_,
        uint256 shares_
    )
        external override whenNotPaused nonReentrant onlyOperatorOrPoolDelegate(poolManager_)
    {
        require(_isValidPoolManager(poolManager_), "MSM:RR:INVALID_PM");

        uint256 remainingShares_ = sharesOf[poolManager_] - pendingSharesOf[poolManager_];

        require(shares_ != 0,                "MSM:RR:ZERO_SHARES");
        require(shares_ <= remainingShares_, "MSM:RR:INSUFFICIENT_SHARES");

        pendingSharesOf[poolManager_] += shares_;
        totalPendingShares            += shares_;

        emit RedemptionRequested(poolManager_, shares_);
    }

    /**************************************************************************************************************************************/
    /*** Administrative Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function multicall(bytes[] calldata data_) external override {
        for (uint256 i = 0; i < data_.length; i++) {
            ( bool success_, bytes memory returnData_ ) = address(this).delegatecall(data_[i]);

            if (!success_) {
                assembly ("memory-safe") {
                    revert(add(32, returnData_), mload(returnData_))
                }
            }
        }
    }

    function setPoolManagerCap(address poolManager_, uint256 cap_) external override whenNotPaused onlyAdminsOrNotConfigured {
        require(poolManagerCapOf[poolManager_] != cap_,         "MSM:SPMC:NO_CHANGE");
        require(cap_ == 0 || _isValidPoolManager(poolManager_), "MSM:SPMC:INVALID_PM");

        poolManagerCapOf[poolManager_] = cap_;

        emit PoolManagerCapSet(poolManager_, cap_);
    }

    function setStrategyLiquidityCap(uint256 cap_) external override whenNotPaused onlyAdminsOrNotConfigured {
        require(strategyLiquidityCap != cap_, "MSM:SSC:NO_CHANGE");

        strategyLiquidityCap = cap_;

        emit StrategyLiquidityCapSet(cap_);
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

    function convertToAssets(uint256 shares_) external view override returns (uint256 assets_) {
        assets_ = _convertToAssets(shares_, assetsUnderManagement());
    }

    function convertToExitAssets(uint256 shares_) external view override returns (uint256 assets_) {
        assets_ = _convertToExitAssets(shares_, assetsUnderManagement());
    }

    function convertToExitShares(uint256 assets_) external view override returns (uint256 shares_) {
        shares_ = _convertToExitShares(assets_, assetsUnderManagement());
    }

    function convertToShares(uint256 assets_) external view override returns (uint256 shares_) {
        shares_ = _convertToShares(assets_, assetsUnderManagement());
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

    function isAssetSupported(address asset_) external view override returns (bool isSupported_) {
        isSupported_ = IUnderlyingStrategyLike(underlyingStrategy).fundsAsset() == asset_;
    }

    function securityAdmin() public view override returns (address securityAdmin_) {
        securityAdmin_ = IGlobalsLike(globals()).securityAdmin();
    }

    function unrealizedLosses() external view override returns (uint256 unrealizedLosses_) {
        unrealizedLosses_ = _unrealizedLosses(assetsUnderManagement());
    }

    function unrealizedLossesOf(address poolManager_) external view override returns (uint256 unrealizedLosses_) {
        uint256 totalShares_ = totalShares;

        if (totalShares_ == 0) return 0;

        unrealizedLosses_ = _divRoundUp(sharesOf[poolManager_] * _unrealizedLosses(assetsUnderManagement()), totalShares_);
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _convertToAssets(uint256 shares_, uint256 totalAssets_) internal view returns (uint256 assets_) {
        uint256 totalShares_ = totalShares;

        if (totalShares_ == 0) return shares_;

        assets_ = shares_ * totalAssets_ / totalShares_;
    }

    function _convertToExitAssets(uint256 shares_, uint256 totalAssets_) internal view returns (uint256 assets_) {
        assets_ = _convertToAssets(shares_, totalAssets_ - _unrealizedLosses(totalAssets_));
    }

    function _convertToExitShares(uint256 assets_, uint256 totalAssets_) internal view returns (uint256 shares_) {
        shares_ = _convertToShares(assets_, totalAssets_ - _unrealizedLosses(totalAssets_));
    }

    function _convertToShares(uint256 assets_, uint256 totalAssets_) internal view returns (uint256 shares_) {
        uint256 totalShares_ = totalShares;

        if (totalShares_ == 0) return assets_;

        shares_ = assets_ * totalShares_ / totalAssets_;
    }

    function _divRoundUp(uint256 numerator_, uint256 divisor_) internal pure returns (uint256 result_) {
        result_ = (numerator_ + divisor_ - 1) / divisor_;
    }

    function _isOperator() internal view returns (bool isOperator_) {
        if (msg.sender == strategyDelegate) return true;

        // NOTE: Bots can not operate on impaired strategies.
        if (IUnderlyingStrategyLike(underlyingStrategy).impairedAssets() != 0) return false;

        address globals_ = globals();

        isOperator_ =
            IGlobalsLike(globals_).isInstanceOf("LIQUIDITY_BOT",    msg.sender) ||
            IGlobalsLike(globals_).isInstanceOf("LIQUIDITY_ROUTER", msg.sender);
    }

    function _isValidPoolManager(address poolManager_) internal view returns (bool isValid_) {
        address factory_ = IPoolManagerLike(poolManager_).factory();

        isValid_ =
            IGlobalsLike(globals()).isInstanceOf("POOL_MANAGER_FACTORY", factory_) &&
            IProxyFactoryLike(factory_).isInstance(poolManager_);
    }

    function _isWithinPoolManagerCap(address poolManager_) internal view returns (bool withinCap_) {
        uint256 poolManagerCap_ = poolManagerCapOf[poolManager_];

        // A cap of the maximum value means the pool manager is completely blocked and can never be within cap.
        // A cap of zero means no cap is set, so it is always considered within cap (unlimited).
        if (poolManagerCap_ == type(uint256).max) return false;
        if (poolManagerCap_ == 0)                 return true;

        withinCap_ = assetsOf(poolManager_) <= poolManagerCap_;
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 min_) {
        min_ = a_ < b_ ? a_ : b_;
    }

    function _unrealizedLosses(uint256 totalAssets_) internal view returns (uint256 unrealizedLosses_) {
        unrealizedLosses_ = IUnderlyingStrategyLike(underlyingStrategy).unrealizedLosses();

        unrealizedLosses_ = _min(unrealizedLosses_, totalAssets_);
    }

}
