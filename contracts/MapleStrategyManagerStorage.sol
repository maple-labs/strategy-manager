// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleStrategyManagerStorage } from "./interfaces/IMapleStrategyManagerStorage.sol";

contract MapleStrategyManagerStorage is IMapleStrategyManagerStorage {

    uint256 internal _locked;

    address public override strategy;

}
