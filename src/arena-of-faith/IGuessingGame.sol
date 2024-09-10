// SPDX-License-Identifier: MIT
import {GameState, PlayerState, System, DayInfo, Game, GameInfo, Player} from "./Structs.sol";


// MCO = 馃 Metis Champs Olympics
/**
    uint128 gameValue; // 340282366920938463463374607431768211456
    uint96 timestamp; // 79228162514264337593543950336
    uint48 teamId; // 281474976710656
    uint48 dayId;
    uint32 gameType; // 4294967296
    uint32 gameId;
    uint8 winOption; // 256
    uint8 state;
 */
interface IGuessingGame {
    // Events
    // -GameEvents
    event GameCreated(
        uint32 indexed gameId,
        uint48 xId,
        uint48 yId,
        uint32 gameType,
        uint96 gameStartTimestamp,
        uint96 gameEndTimestamp
    );
    event GameUpdate(
        uint32 indexed gameId,
        uint96 realGameStartTimestamp,
        uint96 newGameStartTimestamp,
        uint96 newGameEndTimestamp
    );
    event WinOptionSet(uint32 indexed gameId, uint8 optionId);
    event GameCanceled(uint32 indexed gameId);
    event GameEnded(uint32 indexed gameId, uint8 winOption);
    // -Player Events
    event PlayGame(
        uint32 indexed gameId,
        uint8 indexed optionId,
        uint128 guessingAmount
    );
    event PlayerClaimPrize(
        address indexed player,
        uint32 indexed gameId,
        uint128 prize
    );

    event RefundsForCanceledGame(
        address indexed player,
        uint32 indexed gameId,
        uint8[] optionIds,
        uint128 refundsAmount
    );

    // ======================================== FUNCTIONS ========================================
    // ---------------------------------------- FOR ADMIN ----------------------------------------
    // refs [state : {able funcs}] = [0:{A2,B2},1:{B2},2:{B1,B2,C}]
    function A1_createGame(
        uint48 xId,
        uint48 yId,
        uint32 gameType,
        uint96 realGameStartTimestamp,
        uint96 gameStartTimestamp,
        uint96 gameEndTimestamp
    ) external;
    function A1_batchCreate(
        uint48[] calldata xId,
        uint48[] calldata yId,
        uint32[] calldata gameType,
        uint96[] calldata realGameStartTimestamp,
        uint96[] calldata gameStartTimestamp,
        uint96[] calldata gameEndTimestamp
    ) external;
    function A2_updateGameTimestamps(
        uint32 gameId,
        uint96 realGameStartTimestamp,
        uint96 newGameStartTimestamp,
        uint96 newGameEndTimestamp
    ) external;

    function B1_setWinOption(uint32 gameId, uint8 winOption) external;
    function B2_cancelGame(uint32 gameId) external;
    function C_enablePrizeWithdraw(uint32 gameId) external;
    // ---------------------------------------- FOR USER ----------------------------------------
    function playGames(
        uint32[] calldata gameIds,
        uint8[] calldata optionIds,
        uint128[] calldata guessingAmounts
    ) external payable;
    // claimMyPlayPrizes based on
    function claimPlayerPrizes(
        address playerAddress,
        uint32[] calldata gameIds
    ) external; // 浠ｄ粯gas
    function claimMyPrizes(uint32[] calldata gameIds) external;

    function refundsForCanceledGames(
        address playerAddress,
        uint32[] calldata gameIds,
        uint8[][] calldata optionIdss
    ) external; // 浠ｄ粯gas
    function refundsMyFundsForCanceledGame_MCO(
        uint32[] calldata gameIds
    ) external;
    // ---------------------------------------- FOR ANYONE GET INFO ----------------------------------------
    function getGameIdsByDatesBatch(
        uint48 batchStartDayId,
        uint16 batchSize
    ) external view returns (uint32[][] memory batchGameIds);
    function getGameInfoByIds(
        uint32[] calldata gameIds,
        uint8[][] calldata optionIdss
    ) external view returns (GameInfo[] memory gameInfos);
    function getGameInfoByIds_MCO(
        uint32[] calldata gameIds
    ) external view returns (GameInfo[] memory gameInfos);

    // getPlayerStateOfGameId_MCO based on
    function getPlayerStateOfGameIds(
        uint32[] calldata gameIds,
        uint8[][] calldata optionIdss,
        address playerAddress
    )
        external
        view
        returns (uint128[][] memory valueOfOptionIdss, uint128[] memory prizes);
    function getPlayerStateOfGameIds_MCO(
        uint32[] calldata gameIds,
        address playerAddress
    )
        external
        view
        returns (uint128[][] memory valueOfOptionIdss, uint128[] memory prizes);

    function getPlayerInfo(
        address playerAddress
    )
        external
        view
        returns (
            uint128 totalInput, //鎬绘姇鍏ラ噾棰?
            uint128 totalOutput, //鎬昏緭鍑洪噾棰?
            uint64 totalPlayCount, // 绔炵寽鎶曞叆娆℃暟
            uint256 joinedGameCount // 鍙備笌绔炵寽鐨勫眬鏁?
        );
    function getPlayerJoinedGameIdsByBatch(
        address playerAddress,
        uint128 batchStartIndex, // 璧峰绱㈠紩
        uint128 batchSize // 鎵规澶у皬
    ) external view returns (uint32[] memory gameIds);

    function getSystemInfo()
        external
        view
        returns (
            uint128 totalInput,
            uint128 totalOutput,
            uint64 totalPlayCount,
            uint64 timeZoneBias,
            uint32 feeNumerator,
            uint32 maxGameId
        );
}

// File contracts/libraries/Math.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;

// a library for performing various math operations
library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always
            // >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }
}
