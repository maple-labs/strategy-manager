// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../../modules/forge-std/src/Test.sol";

import { MapleLiquidityRouter } from "../../../contracts/MapleLiquidityRouter.sol";

contract ConstructorTests is Test {

    function test_constructor_revert_zeroGlobals() external {
        vm.expectRevert("MLR:C:ZERO_GLOBALS");
        new MapleLiquidityRouter(address(0));
    }

    function test_constructor_success() external {
        address globals = makeAddr("globals");

        MapleLiquidityRouter router = new MapleLiquidityRouter(globals);

        assertEq(router.globals(), globals);
    }

}
