// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleProxiedInternals } from "../../modules/proxy-factory/contracts/MapleProxiedInternals.sol";
import { MapleProxyFactory }     from "../../modules/proxy-factory/contracts/MapleProxyFactory.sol";

import { Action, IMapleLiquidityRouter } from "../../contracts/interfaces/IMapleLiquidityRouter.sol";
import { IGlobalsLike }                  from "../../contracts/interfaces/Interfaces.sol";

import { MapleStrategyManagerStorage } from "../../contracts/MapleStrategyManagerStorage.sol";

contract MockGlobals {

    address public governor;
    address public operationalAdmin;
    address public securityAdmin;

    bool public failTransferOwnedStrategyManager;
    bool public protocolPaused;

    mapping(address => bool) public canDeploy;

    mapping(bytes4 => bool) public isFunctionPaused;

    mapping(bytes32 => mapping(address => bool)) public isInstanceOf;

    mapping(address => bool) public isStrategyDelegate;

    mapping(address => address) public strategyDelegateOf;

    function __setCanDeploy(address caller_, bool canDeploy_) external {
        canDeploy[caller_] = canDeploy_;
    }

    function __setFailTransferOwnedStrategyManager(bool failTransferOwnedStrategyManager_) external {
        failTransferOwnedStrategyManager = failTransferOwnedStrategyManager_;
    }

    function __setGovernor(address governor_) external {
        governor = governor_;
    }

    function __setIsFunctionPaused(bytes4 signature_, bool isFunctionPaused_) external {
        isFunctionPaused[signature_] = isFunctionPaused_;
    }

    function __setIsInstanceOf(bytes32 instanceId_, address instance_, bool isInstance_) external {
        isInstanceOf[instanceId_][instance_] = isInstance_;
    }

    function __setIsStrategyDelegate(address account_, bool isStrategyDelegate_) external {
        isStrategyDelegate[account_] = isStrategyDelegate_;
    }

    function __setOperationalAdmin(address operationalAdmin_) external {
        operationalAdmin = operationalAdmin_;
    }

    function __setProtocolPaused(bool protocolPaused_) external {
        protocolPaused = protocolPaused_;
    }

    function __setSecurityAdmin(address securityAdmin_) external {
        securityAdmin = securityAdmin_;
    }

    function __setStrategyDelegate(address strategyManager_, address strategyDelegate_) external {
        strategyDelegateOf[strategyManager_] = strategyDelegate_;
    }

    function transferOwnedStrategyManager(address, address toStrategyDelegate_) external {
        require(!failTransferOwnedStrategyManager, "MG:TOSM:FAILED");

        strategyDelegateOf[msg.sender] = toStrategyDelegate_;
    }

}

contract MockMigrator is MapleStrategyManagerStorage {

    fallback() external {
        underlyingStrategy = abi.decode(msg.data, (address));
    }

}

contract MockPoolManager {

    address public factory;
    address public pool;

    function requestFunds(address, uint256) external {}

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setPool(address pool_) external {
        pool = pool_;
    }

}

contract MockPoolManagerFactory {

    mapping(address => bool) public isInstance;

    function __setIsInstance(address instance_, bool isInstance_) external {
        isInstance[instance_] = isInstance_;
    }

}

contract MockStrategyManager {

    address public factory;

    uint256 public assetsUnderManagement;
    uint256 public totalPendingShares;
    uint256 public totalShares;

    mapping(address => uint256) public pendingSharesOf;
    mapping(address => uint256) public sharesOf;

    function __setAssetsUnderManagement(uint256 assetsUnderManagement_) external {
        assetsUnderManagement = assetsUnderManagement_;
    }

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setSharesOf(address poolManager_, uint256 shares_) external {
        sharesOf[poolManager_] = shares_;
    }

    function __setTotalShares(uint256 totalShares_) external {
        totalShares = totalShares_;
    }

    function assetsOf(address poolManager_) external view returns (uint256 assets_) {
        uint256 totalShares_ = totalShares;

        if (totalShares_ == 0) return 0;

        assets_ = sharesOf[poolManager_] * assetsUnderManagement / totalShares_;
    }

    function cancelRedemption(address poolManager_, uint256 shares_) external virtual {
        pendingSharesOf[poolManager_] -= shares_;
        totalPendingShares            -= shares_;
    }

    function fundStrategyManager(address poolManager_, uint256 assetsIn_, bytes calldata) external virtual {
        assetsUnderManagement  += assetsIn_;
        totalShares            += assetsIn_;
        sharesOf[poolManager_] += assetsIn_;
    }

    function processRedemption(address poolManager_, uint256 shares_, bytes calldata) external virtual {
        uint256 assets_ = shares_ * assetsUnderManagement / totalShares;

        pendingSharesOf[poolManager_] -= shares_;
        sharesOf[poolManager_]        -= shares_;
        totalPendingShares            -= shares_;
        totalShares                   -= shares_;
        assetsUnderManagement         -= assets_;
    }

    function requestRedeem(address poolManager_, uint256 shares_) external virtual {
        pendingSharesOf[poolManager_] += shares_;
        totalPendingShares            += shares_;
    }

}

contract MockReentrantStrategyManager is MockStrategyManager {

    IMapleLiquidityRouter router;

    function __setRouter(address router_) external {
        router = IMapleLiquidityRouter(router_);
    }

    function requestRedeem(address, uint256) external override {
        Action[] memory actions = new Action[](0);

        router.executeActions(actions, block.timestamp);
    }

}

contract MockStrategyFactory is MapleProxyFactory {

    address public invalidInstance;

    constructor(address globals_) MapleProxyFactory(globals_) {}

    function __setInvalidInstance(address invalidInstance_) external {
        invalidInstance = invalidInstance_;
    }

    function createInstance(bytes calldata arguments_, bytes32 salt_) public override returns (address instance_) {
        require(IGlobalsLike(mapleGlobals).canDeploy(msg.sender), "MSF:CI:CANNOT_DEPLOY");

        if (address(invalidInstance) != address(0)) return invalidInstance;

        instance_ = super.createInstance(arguments_, salt_);
    }

}

contract MockStrategyManagerFactory {

    mapping(address => bool) public isInstance;

    function __setIsInstance(address instance_, bool isInstance_) external {
        isInstance[instance_] = isInstance_;
    }

}

contract MockERC20 {

    mapping(address => uint256) public balanceOf;

    uint256 public totalSupply;

    function transfer(address to_, uint256 amount_) external returns (bool success_) {
        balanceOf[msg.sender] -= amount_;
        balanceOf[to_]        += amount_;

        return true;
    }

    function __mint(address account_, uint256 amount_) external {
        totalSupply         += amount_;
        balanceOf[account_] += amount_;
    }

    function __setBalance(address account_, uint256 balance_) external {
        totalSupply         = totalSupply - balanceOf[account_] + balance_;
        balanceOf[account_] = balance_;
    }

}

contract MockDeployableStrategy is MapleProxiedInternals {

    address public strategyManager;

    function factory() external view returns (address factory_) {
        factory_ = _factory();
    }

    function implementation() external view returns (address implementation_) {
        implementation_ = _implementation();
    }

    function migrate(address migrator_, bytes calldata arguments_) external {
        require(_migrate(migrator_, arguments_), "MDS:M:FAILED");
    }

    function setImplementation(address implementation_) external {
        _setImplementation(implementation_);
    }

}

contract MockDeployableStrategyInitializer {

    address public strategyManager;

    fallback() external {
        address strategyManager_ = abi.decode(msg.data[:32], (address));

        if (msg.data.length > 32 && abi.decode(msg.data[32:], (bool))) {
            strategyManager_ = address(1);
        }

        strategyManager = strategyManager_;
    }

}

contract MockStrategy {

    address public fundsAsset;

    uint256 public assetsUnderManagement;
    uint256 public availableToWithdraw;
    uint256 public unrealizedLosses;

    uint256 internal _fundReturn;

    function __setFundsAsset(address fundsAsset_) external {
        fundsAsset = fundsAsset_;
    }

    function __setAvailableToWithdraw(uint256 availableToWithdraw_) external {
        availableToWithdraw = availableToWithdraw_;
    }

    function __setAssetsUnderManagement(uint256 assetsUnderManagement_) external {
        assetsUnderManagement = assetsUnderManagement_;

        MockERC20(fundsAsset).__setBalance(address(this), assetsUnderManagement_);
    }

    function __setFundUnderlyingStrategyReturn(uint256 fundReturn_) external {
        _fundReturn = fundReturn_;
    }

    function __setUnrealizedLosses(uint256 unrealizedLosses_) external {
        unrealizedLosses = unrealizedLosses_;
    }

    function fundUnderlyingStrategy(uint256, bytes calldata) external returns (uint256 amount_) {
        amount_ = _fundReturn;

        assetsUnderManagement += _fundReturn;
        availableToWithdraw   += _fundReturn;

        MockERC20(fundsAsset).__mint(address(this), _fundReturn);
    }

    function withdrawFromUnderlyingStrategy(address destination_, uint256 assets_, bytes calldata) external {
        assetsUnderManagement -= assets_;
        availableToWithdraw   -= assets_;

        MockERC20(fundsAsset).transfer(destination_, assets_);
    }

}
