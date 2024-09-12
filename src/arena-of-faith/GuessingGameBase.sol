// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts-5.0.2/access/AccessControl.sol";
import {IGuessingGame} from "./IGuessingGame.sol";
import {ConstantsLib} from "./Constants.sol";
import {GameState, PlayerState, System, DayInfo, Game, GameInfo, Player} from "./Structs.sol";
import {Math} from "./Math.sol";


contract GuessingGameBase is IGuessingGame, AccessControl {
    // ======================================== VARIABLES ========================================

    System public sysInfo;

    mapping(uint32 => Game) public Games;
    mapping(address => Player) internal Players;

    mapping(uint32 => uint96) internal _gameIdToRealGameStartTimestamp;
    // ======================================== CONSTANT ========================================
    bytes32 public constant MANAGER_ROLE = bytes32("MANAGER_ROLE");

    // ======================================== FUNCTIONS ========================================
    constructor(uint64 timeZoneBias, uint32 feeNumerator) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        sysInfo.timeZoneBias = timeZoneBias;
        sysInfo.feeNumerator = feeNumerator;
    }
    // ---------------------------------------- TOOLS ----------------------------------------
    function getDayId(uint96 timestamp) public view returns (uint48 dayId) {
        dayId = uint48((timestamp + sysInfo.timeZoneBias) / 1 days);
    }

    function _getGameStateByTimestamp(
        uint32 _gameId
    ) internal view returns (GameState state) {
        Game storage _game = Games[_gameId];
        uint96 _now = uint96(block.timestamp);
        state = _game.state;

        if (_game.state == GameState.playing && _now > _game.gameEndTimestamp) {
            state = GameState.waitingWinOption;
        } else if (_game.state == GameState.beforePlaying) {
            if (_now > _game.gameEndTimestamp) {
                state = GameState.waitingWinOption;
            } else if (_now > _game.gameStartTimestamp) {
                state = GameState.playing;
            }
        }
    }
    function _checkAndGetGameState(
        uint32 _gameId
    ) internal returns (GameState state) {
        Game storage _game = Games[_gameId];
        state = _getGameStateByTimestamp(_gameId);
        if (state != _game.state) {
            _game.state = state;
        }
    }

    function _tokenOutput(address _playerAddress, uint128 _amount) internal {
        Player storage _player = Players[_playerAddress];
        sysInfo.totalOutput += _amount;
        _player.totalOutput += _amount;
        payable(_playerAddress).transfer(_amount);
    }
    // ---------------------------------------- FOR ADMIN ----------------------------------------
    function grantManagerRole(
        address user
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MANAGER_ROLE, user);
    }
    function setFeeNumerator(
        uint32 newFeeNumerator
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        sysInfo.feeNumerator = newFeeNumerator;
    }
    function setTimeZoneBias(
        uint64 newTimeZoneBias
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        sysInfo.timeZoneBias = newTimeZoneBias;
    }
    function getSystemFee() external view returns (uint96 fee) {
        fee = sysInfo.systemFee;
    }
    function fetchSystemFee(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint128 _sysfee = sysInfo.systemFee;
        sysInfo.systemFee = 0;
        payable(to).transfer(_sysfee);
    }
    // ---------------------------------------- FOR MANAGE GAME ----------------------------------------
    // refs [state : {able funcs}] = [0:{A2,B2},1:{B2},2:{B1,B2,C}]

    function A1_createGame(
        uint48 xId,
        uint48 yId,
        uint32 gameType,
        uint96 realGameStartTimestamp,
        uint96 gameStartTimestamp,
        uint96 gameEndTimestamp
    ) public onlyRole(MANAGER_ROLE) {
        require(
            gameEndTimestamp > gameStartTimestamp,
            "GG: End time not greater than start time"
        );
        uint48 _dayId = getDayId(realGameStartTimestamp);
        //Gen next gameId, prevent the zero id
        sysInfo.maxGameId += 1;
        uint32 _gameId = sysInfo.maxGameId;

        Game storage _newGame = Games[_gameId];

        _newGame.teamIdX = xId;
        _newGame.teamIdY = yId;
        _newGame.gameType = gameType;
        _newGame.gameStartTimestamp = gameStartTimestamp;
        _newGame.gameEndTimestamp = gameEndTimestamp;
        _newGame.dayId = _dayId;

        _gameIdToRealGameStartTimestamp[_gameId] = realGameStartTimestamp;

        sysInfo.dayIdToDayInfo[_dayId].dayGameIds.push(_gameId);

        emit GameCreated(
            _gameId,
            xId,
            yId,
            gameType,
            gameStartTimestamp,
            gameEndTimestamp
        );
    }

    // -- Batch Add
    function A1_batchCreate(
        uint48[] calldata xId,
        uint48[] calldata yId,
        uint32[] calldata gameType,
        uint96[] calldata realGameStartTimestamp,
        uint96[] calldata gameStartTimestamp,
        uint96[] calldata gameEndTimestamp
    ) external onlyRole(MANAGER_ROLE) {
        require(
            xId.length == yId.length &&
                yId.length == gameType.length &&
                gameType.length == realGameStartTimestamp.length &&
                realGameStartTimestamp.length == gameStartTimestamp.length &&
                gameStartTimestamp.length == gameEndTimestamp.length,
            "GG: Unequal length"
        );
        for (uint256 i = 0; i < gameType.length; i++) {
            A1_createGame(
                xId[i],
                yId[i],
                gameType[i],
                realGameStartTimestamp[i],
                gameStartTimestamp[i],
                gameEndTimestamp[i]
            );
        }
    }

    function A2_updateGameTimestamps(
        uint32 gameId,
        uint96 realGameStartTimestamp,
        uint96 newGameStartTimestamp,
        uint96 newGameEndTimestamp
    ) external onlyRole(MANAGER_ROLE) {
        Game storage _game = Games[gameId];
        // check auto [0]鈫? , [require state]
        require(
            _checkAndGetGameState(gameId) == GameState.beforePlaying,
            "GG: Not in beforePlaying state"
        );
        require(
            newGameEndTimestamp > newGameStartTimestamp,
            "GG: End time not greater than start time"
        );
        uint48 _newDayId = getDayId(realGameStartTimestamp);

        require(_newDayId == _game.dayId, "GG: Out of the day");

        _gameIdToRealGameStartTimestamp[gameId] = realGameStartTimestamp;
        _game.gameStartTimestamp = newGameStartTimestamp;
        _game.gameEndTimestamp = newGameEndTimestamp;

        emit GameUpdate(
            gameId,
            realGameStartTimestamp,
            newGameStartTimestamp,
            newGameEndTimestamp
        );
    }

    function B1_setWinOption(
        uint32 gameId,
        uint8 winOption
    ) external onlyRole(MANAGER_ROLE) {
        Game storage _game = Games[gameId];

        require(
            _game.optionIdToGameValue[winOption] > 0,
            "GG: Win option no bets."
        );

        require(
            _checkAndGetGameState(gameId) == GameState.waitingWinOption,
            "GG: Not in waitingWinOption state"
        );
        _game.winOption = winOption;

        emit WinOptionSet(gameId, winOption);
    }

    function B2_cancelGame(uint32 gameId) external onlyRole(MANAGER_ROLE) {
        Game storage _game = Games[gameId];
        // to gameEnded not by auto, so [0,1,2] is [require state]
        require(
            _game.state < GameState.gameEnded,
            "GG: Already ended or canceled"
        );
        _game.state = GameState.canceled;

        emit GameCanceled(gameId);
    }

    function _calSysFee(
        uint128 loserGameValue
    ) internal view returns (uint96 fee) {
        fee = uint96(
            Math.mulDiv(
                loserGameValue,
                sysInfo.feeNumerator,
                ConstantsLib.RESOLUTION
            )
        );
    }
    function C_enablePrizeWithdraw(
        uint32 gameId
    ) external onlyRole(MANAGER_ROLE) {
        Game storage _game = Games[gameId];

        require(
            _game.state == GameState.waitingWinOption, // && _game.winOption != 0,
            "GG: Need set and wait"
        );
        _game.state = GameState.gameEnded;

        if (sysInfo.feeNumerator != 0) {
            uint128 winOptionValue = _game.optionIdToGameValue[_game.winOption];
            uint96 fee = _calSysFee(_game.totalGameValue - winOptionValue);
            sysInfo.systemFee += fee;
            _game.totalGameValue -= fee;
        }

        emit GameEnded(gameId, _game.winOption);
    }
    // ---------------------------------------- FOR USER ----------------------------------------
    function _playGame(
        uint32 gameId,
        uint8 optionId,
        uint128 guessingAmount
    ) internal {
        Game storage _game = Games[gameId];
        address _playerAddress = msg.sender;
        Player storage _player = Players[_playerAddress];
        require(
            _checkAndGetGameState(gameId) == GameState.playing,
            "GG: Not in playing state"
        );

        // add system
        sysInfo.totalInput += guessingAmount;
        sysInfo.totalPlayCount += 1;
        // add game
        _game.totalGameValue += guessingAmount;
        _game.optionIdToGameValue[optionId] += guessingAmount;
        // add player
        _player.totalInput += guessingAmount;
        _player.totalPlayCount += 1;
        _player.gameIdToOptionIdToGameValue[gameId][optionId] += guessingAmount;

        if (!_player.gameIdToRecordInList[gameId]) {
            _player.gameIdToRecordInList[gameId] = true;
            _player.joinedGameIds.push(gameId);
        }

        emit PlayGame(gameId, optionId, guessingAmount);
    }
    function playGames(
        uint32[] calldata gameIds,
        uint8[] calldata optionIds,
        uint128[] calldata guessingAmounts
    ) external payable {
        require(
            gameIds.length == optionIds.length &&
                optionIds.length == guessingAmounts.length,
            "GG: Unequal length"
        );
        uint256 _txInput = msg.value;
        uint256 _totalGuessingAmounts = 0;
        for (uint256 i = 0; i < gameIds.length; i++) {
            _playGame(gameIds[i], optionIds[i], guessingAmounts[i]);
            _totalGuessingAmounts += guessingAmounts[i];
        }
        require(_totalGuessingAmounts == _txInput, "GG: Unequal Amount");
    }

    function _calculatePrize(
        uint32 _gameId,
        uint8 _asWinOptionId,
        address _playerAddress
    ) internal view returns (uint128 _prize) {
        Game storage _game = Games[_gameId];
        Player storage _player = Players[_playerAddress];

        uint256 _playerWinOptionValue = uint256(
            _player.gameIdToOptionIdToGameValue[_gameId][_asWinOptionId]
        );
        uint256 _totalGameValue = uint256(_game.totalGameValue);
        uint256 _optionTotalValue = uint256(
            _game.optionIdToGameValue[_asWinOptionId]
        );
        _prize = uint128(
            Math.mulDiv(
                _playerWinOptionValue,
                _totalGameValue,
                _optionTotalValue
            )
        );
    }
    // claimMyPlayPrizes based on
    function _claimPlayerPrize(
        address _playerAddress,
        uint32 _gameId
    ) internal {
        Game storage _game = Games[_gameId];
        Player storage _player = Players[_playerAddress];
        require(_game.state == GameState.gameEnded, "GG: Not in ended state");
        require(!_player.gameIdToClaimedMark[_gameId], "GG: Already claimed");
        uint128 _prize = _calculatePrize(
            _gameId,
            _game.winOption,
            _playerAddress
        );
        _player.gameIdToClaimedMark[_gameId] = true;
        _tokenOutput(_playerAddress, _prize);

        emit PlayerClaimPrize(_playerAddress, _gameId, _prize);
    }
    function claimPlayerPrizes(
        address playerAddress,
        uint32[] calldata gameIds
    ) external {
        for (uint256 i = 0; i < gameIds.length; i++) {
            _claimPlayerPrize(playerAddress, gameIds[i]);
        }
    }
    function claimMyPrizes(uint32[] calldata gameIds) external {
        for (uint256 i = 0; i < gameIds.length; i++) {
            _claimPlayerPrize(msg.sender, gameIds[i]);
        }
    }
    function _refundsForCanceledGame(
        address _playerAddress,
        uint32 _gameId,
        uint8[] memory optionIds
    ) internal {
        Game storage _game = Games[_gameId];
        Player storage _player = Players[_playerAddress];

        require(_game.state == GameState.canceled, "GG: Not in canceled state");

        uint128 _refundsAmount = 0;

        for (uint256 i = 0; i < optionIds.length; i++) {
            _refundsAmount += _player.gameIdToOptionIdToGameValue[_gameId][
                optionIds[i]
            ];
            _player.gameIdToOptionIdToGameValue[_gameId][optionIds[i]] = 0;
        }
        _tokenOutput(_playerAddress, _refundsAmount);

        emit RefundsForCanceledGame(
            _playerAddress,
            _gameId,
            optionIds,
            _refundsAmount
        );
    }
    function refundsForCanceledGames(
        address playerAddress,
        uint32[] calldata gameIds,
        uint8[][] calldata optionIdss
    ) external {
        require(gameIds.length == optionIdss.length, "GG: Unequal length");
        for (uint256 i = 0; i < gameIds.length; i++) {
            _refundsForCanceledGame(playerAddress, gameIds[i], optionIdss[i]);
        }
    }
    function refundsMyFundsForCanceledGame_MCO(
        uint32[] calldata gameIds
    ) external {
        address _playerAddress = msg.sender;
        uint8[] memory _options = new uint8[](3);
        _options[0] = 1;
        _options[1] = 2;
        _options[2] = 3;
        for (uint256 i = 0; i < gameIds.length; i++) {
            _refundsForCanceledGame(_playerAddress, gameIds[i], _options);
        }
    }
    // ---------------------------------------- FOR ANYONE GET INFO ----------------------------------------
    function getGameIdsByDatesBatch(
        uint48 batchStartDayId,
        uint16 batchSize
    ) external view returns (uint32[][] memory batchGameIds) {
        batchGameIds = new uint32[][](batchSize);
        for (uint16 i = 0; i < batchSize; i++) {
            uint48 currentDayId = batchStartDayId + i;
            batchGameIds[i] = sysInfo.dayIdToDayInfo[currentDayId].dayGameIds;
        }
    }
    function _getGameInfoById(
        uint32 _gameId,
        uint8[] memory optionIds
    ) internal view returns (GameInfo memory gameInfo) {
        Game storage _game = Games[_gameId];
        uint128[] memory valueOfOptionIds = new uint128[](optionIds.length);
        uint256[] memory odds = new uint256[](optionIds.length);
        uint128 _taxedTotalGameValue;
        for (uint256 i = 0; i < optionIds.length; i++) {
            valueOfOptionIds[i] = _game.optionIdToGameValue[optionIds[i]];
            // only cal lose side tax
            _taxedTotalGameValue = sysInfo.feeNumerator == 0
                ? _game.totalGameValue
                : _game.totalGameValue -
                    _calSysFee(_game.totalGameValue - valueOfOptionIds[i]);

            valueOfOptionIds[i] == 0 ? odds[i] = 0 : odds[i] = Math.mulDiv(
                ConstantsLib.RESOLUTION,
                _taxedTotalGameValue,
                valueOfOptionIds[i]
            );
        }
        // GameInfo memory gameInfo;
        gameInfo.totalGameValue = _game.totalGameValue;
        gameInfo.valueOfOptionIds = valueOfOptionIds;
        gameInfo.odds = odds;
        gameInfo.teamIdX = _game.teamIdX;
        gameInfo.teamIdY = _game.teamIdY;
        gameInfo.gameType = _game.gameType;
        gameInfo.realGameStartTimestamp = _gameIdToRealGameStartTimestamp[
            _gameId
        ];
        gameInfo.gameStartTimestamp = _game.gameStartTimestamp;
        gameInfo.gameEndTimestamp = _game.gameEndTimestamp;
        gameInfo.dayId = _game.dayId;
        gameInfo.winOption = _game.winOption;
        gameInfo.state = _getGameStateByTimestamp(_gameId);
    }

    function getGameInfoByIds(
        uint32[] calldata gameIds,
        uint8[][] calldata optionIdss
    ) external view returns (GameInfo[] memory gameInfos) {
        GameInfo[] memory cache = new GameInfo[](gameIds.length);
        for (uint256 i = 0; i < gameIds.length; i++) {
            cache[i] = _getGameInfoById(gameIds[i], optionIdss[i]);
        }
        gameInfos = cache;
    }
    function getGameInfoByIds_MCO(
        uint32[] calldata gameIds
    ) external view returns (GameInfo[] memory gameInfos) {
        GameInfo[] memory cache = new GameInfo[](gameIds.length);
        uint8[] memory _options = new uint8[](3);
        _options[0] = 1;
        _options[1] = 2;
        _options[2] = 3;
        for (uint256 i = 0; i < gameIds.length; i++) {
            cache[i] = _getGameInfoById(gameIds[i], _options);
        }
        gameInfos = cache;
    }

    // getPlayerStateOfGameId_MCO based on
    function _getPlayerStateOfGameId(
        uint32 _gameId,
        uint8[] memory optionIds,
        address _playerAddress
    ) internal view returns (uint128[] memory valueOfOptionIds, uint128 prize) {
        Player storage _player = Players[_playerAddress];
        Game storage _game = Games[_gameId];
        prize = 0;

        if (
            _game.state == GameState.gameEnded &&
            !_player.gameIdToClaimedMark[_gameId]
        ) {
            prize = _calculatePrize(_gameId, _game.winOption, _playerAddress);
        }
        uint128[] memory cache = new uint128[](optionIds.length);
        for (uint256 i = 0; i < optionIds.length; i++) {
            cache[i] = _player.gameIdToOptionIdToGameValue[_gameId][
                optionIds[i]
            ];
        }
        valueOfOptionIds = cache;
    }
    // getPlayerStateOfGameId_MCO based on
    function getPlayerStateOfGameIds(
        uint32[] calldata gameIds,
        uint8[][] calldata optionIdss,
        address playerAddress
    )
        external
        view
        returns (uint128[][] memory valueOfOptionIdss, uint128[] memory prizes)
    {
        uint128[][] memory cache = new uint128[][](optionIdss.length);
        prizes = new uint128[](gameIds.length);
        for (uint256 i = 0; i < gameIds.length; i++) {
            cache[i] = new uint128[](optionIdss[i].length);
            (cache[i], prizes[i]) = _getPlayerStateOfGameId(
                gameIds[i],
                optionIdss[i],
                playerAddress
            );
        }
        valueOfOptionIdss = cache;
    }
    function getPlayerStateOfGameIds_MCO(
        uint32[] calldata gameIds,
        address playerAddress
    )
        external
        view
        returns (uint128[][] memory valueOfOptionIdss, uint128[] memory prizes)
    {
        uint128[][] memory cache = new uint128[][](gameIds.length);
        prizes = new uint128[](gameIds.length);
        uint8[] memory _options = new uint8[](3);
        _options[0] = 1;
        _options[1] = 2;
        _options[2] = 3;
        for (uint256 i = 0; i < gameIds.length; i++) {
            cache[i] = new uint128[](3);
            (cache[i], prizes[i]) = _getPlayerStateOfGameId(
                gameIds[i],
                _options,
                playerAddress
            );
        }
        valueOfOptionIdss = cache;
    }

    function getPlayerInfo(
        address playerAddress
    )
        external
        view
        returns (
            uint128 totalInput,
            uint128 totalOutput,
            uint64 totalPlayCount,
            uint256 joinedGameCount
        )
    {
        Player storage _player = Players[playerAddress];
        return (
            _player.totalInput,
            _player.totalOutput,
            _player.totalPlayCount,
            _player.joinedGameIds.length
        );
    }
    function getPlayerJoinedGameIdsByBatch(
        address playerAddress,
        uint128 batchStartIndex,
        uint128 batchSize
    ) external view returns (uint32[] memory gameIds) {
        Player storage _player = Players[playerAddress];
        uint32[] memory cache = new uint32[](batchSize);
        uint256 counter = 0;
        uint256 endIndex = batchStartIndex + batchSize;
        for (
            uint256 i = batchStartIndex;
            i < _player.joinedGameIds.length && i < endIndex;
            i++
        ) {
            cache[counter] = _player.joinedGameIds[i];
            counter++;
        }
        gameIds = cache;
    }

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
        )
    {
        return (
            sysInfo.totalInput,
            sysInfo.totalOutput,
            sysInfo.totalPlayCount,
            sysInfo.timeZoneBias,
            sysInfo.feeNumerator,
            sysInfo.maxGameId
        );
    }
}
