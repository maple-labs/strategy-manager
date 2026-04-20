// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleStrategyDeployer } from "./interfaces/IMapleStrategyDeployer.sol";

contract MapleStrategyDeployer is IMapleStrategyDeployer {

    address public override globals;

    constructor(address globals_) {
        globals = globals_;
    }

}
