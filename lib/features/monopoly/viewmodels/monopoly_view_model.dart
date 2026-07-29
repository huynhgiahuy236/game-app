import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/monopoly_models.dart';
import '../services/monopoly_engine.dart';
import '../services/monopoly_repository.dart';

class MonopolyViewModel extends ChangeNotifier {
  MonopolyViewModel(this.repository) {
    resetGame();
  }

  final MonopolyRepository repository;
  final Random _random = Random();

  late List<MonopolyTile> board;
  late List<MonopolyPlayer> players;

  int currentPlayerIndex = 0;
  int die1 = 1;
  int die2 = 1;
  bool isRolling = false;
  bool turnCompleted = false;

  MonopolyTile? activeTileModal;
  MonopolyCard? activeCardModal;
  String gameLog = 'Bắt đầu ván Cờ Tỷ Phú!';
  MonopolyPlayer? winner;

  MonopolyPlayer get currentPlayer => players[currentPlayerIndex];
  int get diceTotal => die1 + die2;

  void resetGame({int playerCount = 2, bool vsAi = true}) {
    board = MonopolyEngine.createBoard();
    players = [
      MonopolyPlayer(id: 'p1', name: 'Bạn (P1)', color: PlayerColor.red, isAi: false),
      MonopolyPlayer(
        id: 'p2',
        name: vsAi ? 'Máy AI' : 'Người 2 (P2)',
        color: PlayerColor.blue,
        isAi: vsAi,
      ),
      if (playerCount >= 3)
        MonopolyPlayer(
          id: 'p3',
          name: vsAi ? 'Máy Bot 2' : 'Người 3 (P3)',
          color: PlayerColor.amber,
          isAi: vsAi,
        ),
      if (playerCount >= 4)
        MonopolyPlayer(
          id: 'p4',
          name: vsAi ? 'Máy Bot 3' : 'Người 4 (P4)',
          color: PlayerColor.purple,
          isAi: vsAi,
        ),
    ];

    currentPlayerIndex = 0;
    die1 = 1;
    die2 = 1;
    isRolling = false;
    turnCompleted = false;
    activeTileModal = null;
    activeCardModal = null;
    gameLog = 'Chào mừng tới ván Cờ Tỷ Phú!';
    winner = null;

    notifyListeners();
  }

  void rollDice() async {
    if (isRolling || turnCompleted || winner != null || currentPlayer.bankrupt) return;

    isRolling = true;
    notifyListeners();

    // Roll animation delay
    for (var i = 0; i < 6; i++) {
      die1 = _random.nextInt(6) + 1;
      die2 = _random.nextInt(6) + 1;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 60));
    }

    isRolling = false;
    final moveSteps = diceTotal;
    gameLog = '${currentPlayer.name} gieo được $die1 + $die2 = $moveSteps điểm!';

    // Move player step by step
    await _movePlayerSteps(currentPlayer, moveSteps);
  }

  Future<void> _movePlayerSteps(MonopolyPlayer player, int steps) async {
    for (var s = 0; s < steps; s++) {
      player.position = (player.position + 1) % board.length;
      if (player.position == 0) {
        player.cash += 200; // Salary for passing START
        gameLog = '${player.name} đi qua BẮT ĐẦU và nhận \$200!';
      }
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 140));
    }

    // Resolve landing tile
    await _resolveLandingTile(player, board[player.position]);
  }

  Future<void> _resolveLandingTile(MonopolyPlayer player, MonopolyTile tile) async {
    switch (tile.type) {
      case TileType.start:
      case TileType.freeParking:
      case TileType.jail:
        break;

      case TileType.goToJail:
        player.position = 9; // Jail index
        player.inJail = true;
        gameLog = '${player.name} bị bắt BỊ VÀO TÙ!';
        break;

      case TileType.tax:
        player.cash -= tile.price;
        gameLog = '${player.name} đóng ${tile.name} \$${tile.price}.';
        _checkBankruptcy(player);
        break;

      case TileType.chance:
        final card = MonopolyEngine.drawChance();
        activeCardModal = card;
        _applyCard(player, card);
        break;

      case TileType.communityChest:
        final card = MonopolyEngine.drawCommunity();
        activeCardModal = card;
        _applyCard(player, card);
        break;

      case TileType.property:
      case TileType.station:
      case TileType.utility:
        if (tile.ownerId == null) {
          // Unowned property
          if (player.isAi) {
            if (MonopolyEngine.aiShouldBuy(player, tile)) {
              buyProperty(player, tile);
            }
          } else {
            activeTileModal = tile;
          }
        } else if (tile.ownerId != player.id) {
          // Pay rent to owner!
          final owner = players.firstWhere((p) => p.id == tile.ownerId);
          final rent = tile.currentRent;
          player.cash -= rent;
          owner.cash += rent;
          gameLog = '${player.name} trả tiền thuê \$$rent cho ${owner.name}!';
          _checkBankruptcy(player);
        }
        break;
    }

    turnCompleted = true;
    notifyListeners();

    // Auto next turn if AI
    if (player.isAi && winner == null) {
      await Future.delayed(const Duration(milliseconds: 1000));
      endTurn();
    }
  }

  void buyProperty(MonopolyPlayer player, MonopolyTile tile) {
    if (player.cash >= tile.price) {
      player.cash -= tile.price;
      tile.ownerId = player.id;
      gameLog = '${player.name} đã mua thành công ${tile.name} (\$${tile.price})!';
    }
    activeTileModal = null;
    notifyListeners();
  }

  void buildHouse(MonopolyPlayer player, MonopolyTile tile) {
    if (tile.ownerId == player.id && tile.houses < 5 && player.cash >= 100) {
      player.cash -= 100;
      tile.houses++;
      gameLog = '${player.name} xây thêm ${tile.houses == 5 ? "Khách Sạn" : "Nhà"} tại ${tile.name}!';
    }
    notifyListeners();
  }

  void _applyCard(MonopolyPlayer player, MonopolyCard card) {
    player.cash += card.cashChange;
    gameLog = '${player.name} rút thẻ ${card.title}: ${card.description}';
    if (card.movePosition != null) {
      player.position = card.movePosition!;
    }
    _checkBankruptcy(player);
  }

  void closeModals() {
    activeTileModal = null;
    activeCardModal = null;
    notifyListeners();
  }

  void endTurn() {
    activeTileModal = null;
    activeCardModal = null;
    turnCompleted = false;

    // Advance to next non-bankrupt player
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    } while (currentPlayer.bankrupt && players.any((p) => !p.bankrupt));

    _checkOverallWinner();
    notifyListeners();

    // Auto roll if AI turn
    if (currentPlayer.isAi && winner == null) {
      Future.delayed(const Duration(milliseconds: 600), () => rollDice());
    }
  }

  void _checkBankruptcy(MonopolyPlayer player) {
    if (player.cash < 0) {
      player.bankrupt = true;
      player.cash = 0;
      // Release properties owned by player
      for (final t in board) {
        if (t.ownerId == player.id) {
          t.ownerId = null;
          t.houses = 0;
        }
      }
      gameLog = '💥 ${player.name} ĐÃ BỊ PHÁ SẢN!';
      _checkOverallWinner();
    }
  }

  void _checkOverallWinner() {
    final activePlayers = players.where((p) => !p.bankrupt).toList();
    if (activePlayers.length == 1) {
      winner = activePlayers.first;
      gameLog = '👑 ${winner!.name} ĐÃ TRỞ THÀNH TỶ PHÚ DUY NHẤT!';
      _saveStatsOnWin(winner!);
    }
  }

  Future<void> _saveStatsOnWin(MonopolyPlayer winnerPlayer) async {
    final stats = await repository.loadStats();
    stats.gamesPlayed++;
    if (!winnerPlayer.isAi) {
      stats.gamesWon++;
      if (winnerPlayer.cash > stats.maxCashEarned) {
        stats.maxCashEarned = winnerPlayer.cash;
      }
    }
    await repository.saveStats(stats);
  }
}
