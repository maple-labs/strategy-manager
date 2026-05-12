// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleStrategyManagerStorage } from "./interfaces/IMapleStrategyManagerStorage.sol";

contract MapleStrategyManagerStorage is IMapleStrategyManagerStorage {

    uint256 internal _locked;  // Used when checking for reentrancy.

    address public override underlyingStrategy;

    uint256 public override totalCap;
    uint256 public override totalShares;

    mapping(address => uint256) public override poolCap;
    mapping(address => uint256) public override sharesOf;

}
