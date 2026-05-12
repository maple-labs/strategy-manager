// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleStrategyManagerStorage } from "../../contracts/MapleStrategyManagerStorage.sol";

contract MockGlobals {

    address public governor;
    address public securityAdmin;

    bool public protocolPaused;

    mapping(address => bool) public canDeploy;

    mapping(bytes4 => bool) public isFunctionPaused;

    mapping(bytes32 => mapping(address => bool)) public isInstanceOf;

    mapping(address => address) public strategyDelegateOf;

    function __setCanDeploy(address caller_, bool canDeploy_) external {
        canDeploy[caller_] = canDeploy_;
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

    function __setProtocolPaused(bool protocolPaused_) external {
        protocolPaused = protocolPaused_;
    }

    function __setSecurityAdmin(address securityAdmin_) external {
        securityAdmin = securityAdmin_;
    }

    function __setStrategyDelegate(address strategyManager_, address strategyDelegate_) external {
        strategyDelegateOf[strategyManager_] = strategyDelegate_;
    }

}

contract MockMigrator is MapleStrategyManagerStorage {

    fallback() external {
        underlyingStrategy = abi.decode(msg.data, (address));
    }

}

contract MockPoolManager {

    address public factory;

    function requestFunds(address, uint256) external {}

    function __setFactory(address factory_) external {
        factory = factory_;
    }

}

contract MockPoolManagerFactory {

    mapping(address => bool) public isInstance;

    function __setIsInstance(address instance_, bool isInstance_) external {
        isInstance[instance_] = isInstance_;
    }

}

contract MockStrategy {

    uint256 public assetsUnderManagement;

    uint256 internal _fundReturn;

    function fundUnderlyingStrategy(uint256, bytes calldata) external returns (uint256 amount_) {
        amount_ = _fundReturn;

        assetsUnderManagement += _fundReturn;
    }

    function __setAssetsUnderManagement(uint256 assetsUnderManagement_) external {
        assetsUnderManagement = assetsUnderManagement_;
    }

    function __setFundUnderlyingStrategyReturn(uint256 fundReturn_) external {
        _fundReturn = fundReturn_;
    }

}
