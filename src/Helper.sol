// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {FixedPoint96} from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";

    /**
    * @title Helper Contract for Uniswap V3
    * @dev This contract provides functions to interact with Uniswap V3 pools,
    *      including minting liquidity positions and handling callbacks.
    */
    contract Helper {
        using SafeERC20 for IERC20;

        // Constants for calculations
        uint256 private constant COEFF = 1000; // Coefficient for liquidity calculations
        uint256 private constant PRECISION_A = 1e18; // Precision constant for calculations
        uint256 private constant PRECISION_B = 1e9; // Another precision constant for calculations

        // Structure to hold data for minting callbacks
        struct MintCallbackData {
            PoolAddress.PoolKey poolKey; // Key identifying the pool
            address payer; // Address that will pay for the minting
        }

        // Address of the Uniswap V3 factory
        address public factoryUniswapV3;

        // Event emitted when a position is made
        event PositionMade(
            address indexed user, // Address of the user who made the position
            address indexed pool, // Address of the pool where the position is made
            uint128 liquidity, // Amount of liquidity minted
            uint256 amount0, // Amount of token0 sent to the pool
            uint256 amount1 // Amount of token1 sent to the pool
        );

        // Custom errors for invalid inputs
        error InvalidAddress(address account); // Error for invalid address
        error InvalidWidth(uint256 width); // Error for invalid width parameter

        /**
        * @dev Constructor to set the Uniswap V3 factory address.
        * @param factory_ Address of the Uniswap V3 factory.
        */
        constructor(address factory_) {
            if (factory_ == address(0)) revert InvalidAddress(address(0));
            factoryUniswapV3 = factory_;
        }

        /**
     * @dev Creates a liquidity position in a Uniswap V3 pool.
     * @param pool Address of the Uniswap V3 pool where liquidity will be added.
     * @param amount0 Amount of token0 to provide as liquidity.
     * @param amount1 Amount of token1 to provide as liquidity.
     * @param width The width parameter.
     * @return tickLower The lower tick of the position.
     * @return tickUpper The upper tick of the position.
     * @return liquidity The amount of liquidity minted for the position.
     * @return realAmount0 The actual amount of token0 transferred to the pool.
     * @return realAmount1 The actual amount of token1 transferred to the pool.
     * @notice The width must be less than 1000.
     * @dev The function calculates the square root price ranges based on the current price,
     *      the specified amounts, and the width. It then mints the liquidity position
     *      in the specified pool and emits an event with the position details.
     */
     function makePosition(
        IUniswapV3Pool pool,
        uint256 amount0,
        uint256 amount1,
        uint256 width
    )
        external
        returns (
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 realAmount0,
            uint256 realAmount1
        )
    {
        // Validate the width; it must be less than 1000
        if (width >= 1000) revert InvalidWidth(width);

        // Retrieve the addresses of token0 and token1 from the pool
        address token0 = pool.token0();
        address token1 = pool.token1();
        // Retrieve the fee tier of the pool
        uint24 fee = pool.fee();

        // Get the tick spacing of the pool
        int24 tickSpacing = pool.tickSpacing();

        // Create a key for the pool with the token addresses and fee
        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({
            token0: token0,
            token1: token1,
            fee: fee
        });

        // Get the current square root price from the pool
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        // Calculate the lower and upper square root price ranges based on input amounts and width
        (uint160 sqrtRatioLowX96, uint160 sqrtRatioUpperX96) = _calculate(
            sqrtPriceX96,
            amount0,
            amount1,
            width
        );

        // Calculate the liquidity amount that can be minted for the given amounts
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioLowX96,
            sqrtRatioUpperX96,
            amount0,
            amount1
        );

        // Determine the lower and upper ticks from the square root price ranges
        tickLower = TickMath.getTickAtSqrtRatio(sqrtRatioLowX96);
        tickUpper = TickMath.getTickAtSqrtRatio(sqrtRatioUpperX96);

        // Adjust the ticks to align with the pool's tick spacing
        tickLower += (tickSpacing - (tickLower % tickSpacing));
        tickUpper -= tickUpper % tickSpacing;

        // Mint the liquidity position in the pool and encode callback data
        (realAmount0, realAmount1) = IUniswapV3Pool(pool).mint(
            msg.sender,
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
        );

        // Emit an event to indicate that a position has been made
        emit PositionMade(
            msg.sender,
            address(pool),
            liquidity,
            realAmount0,
            realAmount1
        );
    }
    
      /**
     * @dev Callback function called by the Uniswap V3 pool after a mint operation.
     * @param amount0 Amount of token0 that needs to be transferred.
     * @param amount1 Amount of token1 that needs to be transferred.
     * @param data Encoded data containing the MintCallbackData structure.
     * @notice This function verifies the callback and transfers the specified amounts
     *         of token0 and token1 from the payer to the pool.
     */
     function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        // Decode the callback data to retrieve the MintCallbackData structure
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        // Verify that the callback is valid for the provided pool key
        _verifyCallback(factoryUniswapV3, decoded.poolKey);

        // Transfer amount0 from the payer to the pool if amount0 is greater than zero
        if (amount0 > 0)
            IERC20(decoded.poolKey.token0).safeTransferFrom(
                decoded.payer,
                msg.sender,
                amount0
            );
        // Transfer amount1 from the payer to the pool if amount1 is greater than zero
        if (amount1 > 0)
            IERC20(decoded.poolKey.token1).safeTransferFrom(
                decoded.payer,
                msg.sender,
                amount1
            );
    }

    /**
     * @dev Returns the square root price for a given tick.
     * @param tick The tick for which to calculate the square root price.
     * @return sqrtPriceX96 The square root price at the given tick, expressed in Q96 format.
     */
    function getSqrtRatioAtTick(
        int24 tick
    ) external pure returns (uint160 sqrtPriceX96) {
        // Calculate and return the square root price at the specified tick
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
    }

    /**
     * @dev Calculates the lower and upper square root price ranges based on the current price,
     *      amounts, and specified width.
     * @dev The calculation is based on solving a quadratic equation.
     * @param sqrtPriceCurrentX96 The current square root price of the pool, expressed in Q96 format.
     * @param amount0 Amount of token0 to be used in the calculation.
     * @param amount1 Amount of token1 to be used in the calculation.
     * @param width The width parameter.
     * @return sqrtRatioLowX96 The lower square root price range, expressed in Q96 format.
     * @return sqrtRatioUpperX96 The upper square root price range, expressed in Q96 format.
     * @dev This function performs mathematical calculations to derive the square root price ranges
     *      based on the provided amounts and width. It uses the current price and performs a series
     *      of calculations to determine the low and upper bounds for the price range.
     */
     function _calculate(
        uint160 sqrtPriceCurrentX96,
        uint256 amount0,
        uint256 amount1,
        uint256 width
    )
        private
        pure
        returns (uint160 sqrtRatioLowX96, uint160 sqrtRatioUpperX96)
    {
        // Calculate the constant c based on the current square root price
        uint256 c = (sqrtPriceCurrentX96 * PRECISION_B) / FixedPoint96.Q96;

        // Calculate sqrtK based on the coefficient and width
        uint256 sqrtK = Math.sqrt((COEFF + width) * PRECISION_A) /
            Math.sqrt(COEFF - width);

        // Calculate intermediate values for the discriminant and square root calculations
        uint256 value1 = (amount0 * c * c * sqrtK) / PRECISION_B;
        uint256 value2 = (((amount1 * PRECISION_A * sqrtK) / PRECISION_B) -
            value1) / PRECISION_B;
        uint256 value3 = 4 * amount1 * value1;

        // Calculate the discriminant and its square root
        uint256 discriminant = value2 * value2 + value3;
        uint256 sqrtDiscriminant = Math.sqrt(discriminant) * PRECISION_B;

        // Calculate value4 for further calculations
        uint256 value4 = (2 * amount0 * c * sqrtK) / PRECISION_B;

        // Calculate the lower and upper square root price ranges
        uint256 low = (sqrtDiscriminant - value2 * PRECISION_B) / value4;
        uint256 upper = (low * sqrtK) / PRECISION_B;

        // Convert the results to Q96 format
        sqrtRatioLowX96 = uint160((low * FixedPoint96.Q96) / PRECISION_B);
        sqrtRatioUpperX96 = uint160((upper * FixedPoint96.Q96) / PRECISION_B);
    }

    /**
     * @dev Verifies that the callback is being called by the correct Uniswap V3 pool.
     * @param factory Address of the Uniswap V3 factory.
     * @param poolKey The key that identifies the pool (contains token addresses and fee).
     * @return pool The Uniswap V3 pool instance.
     * @notice This function computes the address of the pool using the factory and pool key,
     *         and checks that the caller is indeed the pool. If the check fails, the transaction
     *         will revert.
     */
    function _verifyCallback(
        address factory,
        PoolAddress.PoolKey memory poolKey
    ) private view returns (IUniswapV3Pool pool) {
        // Compute the address of the pool using the factory and pool key
        pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
        // Ensure that the caller of this function is the pool itself
        require(msg.sender == address(pool));
    }
}
