// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**************************************************************************************************************************************/
/*** Enums                                                                                                                          ***/
/**************************************************************************************************************************************/

enum ActionType {
    FUND_STRATEGY,
    REQUEST_REDEEM,
    CANCEL_REDEMPTION,
    PROCESS_REDEMPTION
}

/**************************************************************************************************************************************/
/*** Structs                                                                                                                        ***/
/**************************************************************************************************************************************/

/**
 *  @param actionType      Type of action to execute.
 *  @param strategyManager Strategy manager the action runs against.
 *  @param poolManager     Pool manager the action concerns.
 *  @param amount          Assets to fund for `FUND_STRATEGY`, otherwise shares. Computed off-chain by the liquidity bot.
 *  @param strategyData    Data forwarded to the underlying strategy on `FUND_STRATEGY` and `PROCESS_REDEMPTION`. Unused otherwise.
 */
struct Action {
    ActionType actionType;
    address strategyManager;
    address poolManager;
    uint256 amount;
    bytes strategyData;
}

/**
 *  @title Defines a Maple liquidity router.
 */
interface IMapleLiquidityRouter {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted after an action is executed.
     *  @param actionIndex     Index of the action in the batch.
     *  @param actionType      Type of action that was executed.
     *  @param strategyManager Strategy manager the action ran against.
     *  @param poolManager     Pool manager the action concerned.
     *  @param amount          Assets for funding and shares for redemption actions.
     */
    event ActionExecuted(
        uint256 actionIndex,
        ActionType indexed actionType,
        address indexed strategyManager,
        address indexed poolManager,
        uint256 amount
    );

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Executes actions atomically in their listed order. Only a registered liquidity bot can call this function.
     *         The call reverts when the deadline has passed or any action fails.
     *  @param actions  Ordered actions to execute.
     *  @param deadline Latest timestamp at which the batch can execute.
     */
    function executeActions(Action[] calldata actions, uint256 deadline) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the Maple globals contract used for access control and function pausing.
     *  @return globals Address of the Maple globals contract.
     */
    function globals() external view returns (address globals);

}
