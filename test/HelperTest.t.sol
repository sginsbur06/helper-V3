// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {Helper} from "../src/Helper.sol";

contract HelperTest is Test {
    uint256 private constant COEFF = 1000;
    uint256 private constant PRECISION_A = 1e18;
    uint256 private constant PRECISION_B = 1e9;

    Helper public helper;
    address public user;

    address constant factoryUniswapV3Addr =
        0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7;
    address constant poolAddress = 0xF9878A5dD55EdC120Fde01893ea713a4f032229c;

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/bsc", 36073780);

        user = address(0x1);
    }

    function testMakePosition() public {
        vm.rollFork(36073780);

        helper = new Helper(factoryUniswapV3Addr);

        address token0 = IUniswapV3Pool(poolAddress).token0();
        address token1 = IUniswapV3Pool(poolAddress).token1();

        uint256 amount0 = 1e18;
        uint256 amount1 = 4_000e18;

        uint256 width = 100;

        deal(token0, user, 10_000e18);
        deal(token1, user, 10_000e18);

        vm.startPrank(user);
        IERC20(token0).approve(address(helper), 10_000e18);
        IERC20(token1).approve(address(helper), 10_000e18);

        (
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 realAmount0,
            uint256 realAmount1
        ) = helper.makePosition(
                IUniswapV3Pool(poolAddress),
                amount0,
                amount1,
                width
            );
        vm.stopPrank();

        console.log("tickLower");
        console.logInt(tickLower);
        console.log("tickUpper");
        console.logInt(tickUpper);
        console.log("liquidity", liquidity);
        console.log("realAmount0", realAmount0);
        console.log("realAmount1", realAmount1);

        console.log(
            "---------------------------------------------------------------------------------------"
        );

        uint160 sqrtRatioLowX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        console.log("sqrtRatioLowX96", sqrtRatioLowX96);
        console.log("sqrtRatioUpperX96", sqrtRatioUpperX96);

        console.log(
            "---------------------------------------------------------------------------------------"
        );

        uint256 baseCondition = ((COEFF + width) * PRECISION_A) /
            (COEFF - width);

        console.log("baseCondition", baseCondition);

        uint256 resultCondition = ((sqrtRatioUpperX96 * PRECISION_B) /
            sqrtRatioLowX96) ** 2;

        console.log("resultCondition", resultCondition);

        uint256 delta = baseCondition > resultCondition
            ? baseCondition - resultCondition
            : resultCondition - baseCondition;

        vm.assertLt((delta * 1e36) / baseCondition, 1e34);

        console.log(
            "---------------------------------------------------------------------------------------"
        );
    }
}
