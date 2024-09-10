// SPDX-License-Identifier: MIT

/**
    uint128 gameValue; // 340282366920938463463374607431768211456
    uint96 timestamp; // 79228162514264337593543950336
    uint64 playCount; // 18446744073709551616
    uint48 teamId; // 281474976710656
    uint48 dayId;
    uint32 gameType; // 4294967296
    uint32 gameId;
    uint8 winOption; // 256
    uint8 GameState;
 */
enum GameState {
    beforePlaying, //0
    playing, //1
    waitingWinOption, //2
    gameEnded, //3
    canceled //4
}
// unused
enum PlayerState {
    unClaimed,
    claimed,
    refunded
}

struct System {
    uint128 totalInput;
    uint128 totalOutput;
    // TODO: 澶勭悊缁嗚妭杩欎釜fee鐩稿叧鐨?
    uint96 systemFee;
    uint64 totalPlayCount;
    uint64 timeZoneBias;
    uint32 feeNumerator;
    uint32 maxGameId;
    mapping(uint256 => DayInfo) dayIdToDayInfo;
}
// mapping(uint256 => DayInfo) dayIdToDayInfo;
struct DayInfo {
    uint32[] dayGameIds;
}
// Game[] public games;
struct Game {
    // 鈶?
    uint128 totalGameValue;
    // - For MCO
    uint48 teamIdX;
    uint48 teamIdY;
    uint32 gameType;
    // 鈶?
    uint96 gameStartTimestamp;
    uint96 gameEndTimestamp;
    uint48 dayId;
    uint8 winOption;
    GameState state;
    // 鈶?
    mapping(uint8 => uint128) optionIdToGameValue;
}

struct GameInfo {
    uint128 totalGameValue; // 鎬讳笅娉ㄩ噾棰? 鍦╡nded涔嬪墠鏄湭涓婄◣鐨勶紝ended鐘舵€佷笅鏄敹杩囩◣鐨?
    uint128[] valueOfOptionIds; // 鍦∕CO涓槸涓€涓暱搴︿负涓夌殑鏁扮粍锛屽搴斾笁涓笅娉ㄩ€夐」
    uint256[] odds; // 璧旂巼 浠?10000 涓哄皬鏁板垎杈ㄧ巼
    uint48 teamIdX; // Left team
    uint48 teamIdY; // Right team
    uint32 gameType; //TBD:
    uint96 realGameStartTimestamp;
    uint96 gameStartTimestamp;
    uint96 gameEndTimestamp;
    uint48 dayId;
    uint8 winOption; // 0:None,1:X,2:Y,3:DRAW
    GameState state; // 0:寮€濮嬪墠,1:绔炵寽涓?2:寮€濂栧墠,3:寮€濂栧悗,4:鍙栨秷鍚?
}

struct Player {
    uint128 totalInput;
    uint128 totalOutput;
    uint192 notUse;
    uint64 totalPlayCount;
    uint32[] joinedGameIds;
    mapping(uint32 => bool) gameIdToRecordInList;
    mapping(uint32 => bool) gameIdToClaimedMark;
    mapping(uint32 => mapping(uint8 => uint128)) gameIdToOptionIdToGameValue;
}

// struct PlayerStateInGame {
//     uint128[] valueOfOptions;
//     uint128 prize;
// }