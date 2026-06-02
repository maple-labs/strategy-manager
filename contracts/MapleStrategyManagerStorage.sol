// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleStrategyManagerStorage } from "./interfaces/IMapleStrategyManagerStorage.sol";

contract MapleStrategyManagerStorage is IMapleStrategyManagerStorage {

    uint256 internal _locked;  // Used when checking for reentrancy.

    address public override pendingStrategyDelegate;
    address public override strategyDelegate;
    address public override underlyingStrategy;

    bool public override active;
    bool public override configured;

    uint256 public override strategyLiquidityCap;
    uint256 public override totalPendingShares;  // TODO: Do we need this slot?
    uint256 public override totalShares;

    mapping(address => uint256) public override poolManagerCapOf;
    mapping(address => uint256) public override pendingSharesOf;
    mapping(address => uint256) public override sharesOf;

}
