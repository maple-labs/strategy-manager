// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { 
    Action,
    ActionType,
    IMapleLiquidityRouter 
} from "./interfaces/IMapleLiquidityRouter.sol";

import { IGlobalsLike, IProxyFactoryLike, IStrategyManagerLike } from "./interfaces/Interfaces.sol";

contract MapleLiquidityRouter is IMapleLiquidityRouter {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address public immutable override globals;

    uint256 internal _locked;  // Used when checking for reentrancy.

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier nonReentrant() {
        require(_locked == 1, "MLR:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier whenNotPaused() {
        require(!IGlobalsLike(globals).isFunctionPaused(msg.sig), "MLR:PAUSED");

        _;
    }

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(address globals_) {
        require(globals_ != address(0), "MLR:C:ZERO_GLOBALS");

        globals = globals_;
        _locked = 1;
    }

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function executeActions(Action[] calldata actions_, uint256 deadline_) external override whenNotPaused nonReentrant {
        address globals_ = globals;

        require(IGlobalsLike(globals_).isInstanceOf("LIQUIDITY_ROUTER_BOT", msg.sender), "MLR:NOT_LIQUIDITY_BOT");
        require(block.timestamp <= deadline_,                                            "MLR:EA:EXPIRED");
        require(actions_.length != 0,                                                    "MLR:EA:EMPTY_ACTIONS");

        uint256 actionCount_ = actions_.length;

        for (uint256 i_; i_ < actionCount_; ++i_) {
            Action calldata action_ = actions_[i_];

            ActionType actionType_      = action_.actionType;
            address    strategyManager_ = action_.strategyManager;
            address    poolManager_     = action_.poolManager;
            uint256    amount_          = action_.amount;

            require(strategyManager_ != address(0), "MLR:EA:ZERO_SM");
            require(poolManager_     != address(0), "MLR:EA:ZERO_PM");

            IStrategyManagerLike strategyManagerContract_ = IStrategyManagerLike(strategyManager_);
            address              strategyManagerFactory_  = strategyManagerContract_.factory();

            require(IGlobalsLike(globals_).isInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory_), "MLR:EA:INVALID_SM_FACTORY");
            require(IProxyFactoryLike(strategyManagerFactory_).isInstance(strategyManager_),                  "MLR:EA:INVALID_SM");

            if (actionType_ == ActionType.FUND_STRATEGY) {
                strategyManagerContract_.fundStrategyManager(poolManager_, amount_, action_.strategyData);
            } else if (actionType_ == ActionType.REQUEST_REDEEM) {
                strategyManagerContract_.requestRedeem(poolManager_, amount_);
            } else if (actionType_ == ActionType.CANCEL_REDEMPTION) {
                strategyManagerContract_.cancelRedemption(poolManager_, amount_);
            } else if (actionType_ == ActionType.PROCESS_REDEMPTION) {
                strategyManagerContract_.processRedemption(poolManager_, amount_, action_.strategyData);
            }

            emit ActionExecuted(i_, actionType_, strategyManager_, poolManager_, amount_);
        }
    }

}
