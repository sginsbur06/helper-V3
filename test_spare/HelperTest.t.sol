// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
// import {NonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";


import {Helper} from "../src/Helper.sol";
// import {XGG} from "../src/XGG.sol";
// import {Ticket} from "../src/Ticket.sol";
// import {HMStaking} from "../src/HMStaking.sol";
// import {ExchangeGG} from "../src/ExchangeGG.sol";
// import {Airdrop} from "../src/Airdrop.sol";


contract HelperMTest is Test {

    Helper public helper;
    INonfungiblePositionManager public nonfungiblePositionManager;
    // XGG public xggToken;
    // Ticket public ticToken;
    // HMStaking public stakingContract;
    // ExchangeGG public exchange;
    // Airdrop public airdrop;
    



    address public wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;   


    address public usdt = 0x55d398326f99059fF775485246999027B3197955; 
    address public eth = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;   
//     address public usdc = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;  
//     address public emp = 0x3b248CEfA87F836a4e6f6d6c9b42991b88Dc1d58;  

//     address public cake = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;


    address public worker1 = 0x9544e0500407dad0765b11c67D6c94645Cf343Ca;
    address public worker2 = 0x3FCd74B5Da0E461d9e18f4151CDbD89Fd5eF7228;
    address public worker3 = 0x21f4dD6c491E04874f19F6Bc4fc1a3d0e661Ca39;


    address public treasury = 0x7c84F47216233b20e1c3e24C2Fb5EB75Ba401703;

    address public buyer = 0x595F12993486EbD019dA710dC15B6d5d7C236563;

    address public poolAddress = 0xF9878A5dD55EdC120Fde01893ea713a4f032229c;
    address public factory = 0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7;

    address public nonfungiblePositionManagerAddress = 0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613;



    // struct MintParams {
    //     address token0;
    //     address token1;
    //     uint24 fee;
    //     int24 tickLower;
    //     int24 tickUpper;
    //     uint256 amount0Desired;
    //     uint256 amount1Desired;
    //     uint256 amount0Min;
    //     uint256 amount1Min;
    //     address recipient;
    //     uint256 deadline;
    // }



    function setUp() public {
        // vm.createSelectFork("https://site1.moralis-nodes.com/bsc/aa5b557f81e94325a219aa88668960d2", 40780719);
        // vm.createSelectFork("https://pacific-rpc.manta.network/http", 1592844);

        vm.createSelectFork("https://rpc.ankr.com/bsc", 36073780);

    }




    function testAirdrop() public {
        vm.rollFork(36073780);

        // nonfungiblePositionManager = INonfungiblePositionManager(nonfungiblePositionManagerAddress);

        helper = new Helper(factory);

        uint256 amount0 = 1e18;
        uint256 amount1 = 4_000e18;

        uint256 width = 100;


        deal(eth, worker1, 10e18);
        deal(usdt, worker1, 10_000e18);



        // deal(eth, address(helper), 10_000e18);
        // deal(usdt, address(helper), 10_000e18);



        // deal(eth, address(this), 10_000e18);
        // deal(usdt, address(this), 10_000e18);


        vm.startPrank(worker1);
        IERC20(eth).approve(address(helper), 10_000e18);
        IERC20(usdt).approve(address(helper), 10_000e18);
        // (uint160 value0, uint160 value1, uint128 value2) = helper.makePosition(IUniswapV3Pool(poolAddress), amount0, amount1, width);

        (int24 value0, int24 value1, uint128 value2, uint256 value3, uint256 value4) = helper.makePosition(IUniswapV3Pool(poolAddress), amount0, amount1, width);
        vm.stopPrank();



        // (uint160 value0, uint160 value1, uint128 value2) = helper.makePosition(IUniswapV3Pool(poolAddress), amount0, amount1, width);

        console.logInt(value0);
        console.logInt(value1);
        console.log(value2);
        console.log(value3);
        console.log(value4);


        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(poolAddress).slot0();


        console.log("---------------------------------------------------------------------------------------");



        uint160 sqrtRatioLowX96 = TickMath.getSqrtRatioAtTick(value0);
        uint160 sqrtRatioUpperX96 = TickMath.getSqrtRatioAtTick(value1);


        console.log("sqrtPriceX96", sqrtPriceX96);


        console.log("sqrtRatioLowX96", sqrtRatioLowX96);
        console.log("sqrtRatioUpperX96", sqrtRatioUpperX96);


        // uint128 liquidity0 = LiquidityAmounts.getLiquidityForAmount0(value1, sqrtPriceX96, amount0);
        // uint128 liquidity1 = LiquidityAmounts.getLiquidityForAmount1(sqrtPriceX96, value0, amount1);


        // console.log(liquidity0);
        // console.log(liquidity1);
        // console.log(value2);



        // console.log("---------------------------------------------------------------------------------------");

    }








}
