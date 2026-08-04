import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/monopoly_models.dart';
import '../services/monopoly_engine.dart';
import '../services/monopoly_repository.dart';

enum EventStageType {
  none,
  diceRoll,
  passingStart,
  buyProperty,
  rentPayment,
  chanceCard,
  jail,
  construction,
  bankruptcy,
  victory,
}

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
  bool isMoving = false;
  bool turnCompleted = false;

  AnimationIntensity animationIntensity = AnimationIntensity.cinematic;
  EventStageType currentStage = EventStageType.none;

  MonopolyTile? activeTileModal;
  MonopolyCard? activeCardModal;
  String gameLog = 'Bắt đầu ván Cờ Tỷ Phú!';
  MonopolyPlayer? winner;

  // Floating money animation notifications
  final List<FloatingMoneyEvent> floatingMoneyEvents = [];

  // Callback to inform UI camera to focus on tile index
  void Function(int tileIndex)? onCameraFocusRequest;

  MonopolyPlayer get currentPlayer => players[currentPlayerIndex];
  int get diceTotal => die1 + die2;
  bool get isDoubles => die1 == die2;

  void setAnimationIntensity(AnimationIntensity intensity) {
    animationIntensity = intensity;
    notifyListeners();
  }

  void requestCameraFocus(int tileIndex) {
    onCameraFocusRequest?.call(tileIndex);
  }

  void resetGame({int playerCount = 2, bool vsAi = true}) {
    board = MonopolyEngine.createBoard();
    players = [
      MonopolyPlayer(id: 'p1', name: 'Bạn (P1)', color: PlayerColor.red, isAi: false),
      MonopolyPlayer(
        id: 'p2',
        name: vsAi ? 'Máy AI 1' : 'Người 2 (P2)',
        color: PlayerColor.blue,
        isAi: vsAi,
      ),
      if (playerCount >= 3)
        MonopolyPlayer(
          id: 'p3',
          name: vsAi ? 'Máy AI 2' : 'Người 3 (P3)',
          color: PlayerColor.amber,
          isAi: vsAi,
        ),
      if (playerCount >= 4)
        MonopolyPlayer(
          id: 'p4',
          name: vsAi ? 'Máy AI 3' : 'Người 4 (P4)',
          color: PlayerColor.purple,
          isAi: vsAi,
        ),
    ];

    currentPlayerIndex = 0;
    die1 = 1;
    die2 = 1;
    isRolling = false;
    isMoving = false;
    turnCompleted = false;
    currentStage = EventStageType.none;
    activeTileModal = null;
    activeCardModal = null;
    floatingMoneyEvents.clear();
    gameLog = 'Chào mừng tới ván Cờ Tỷ Phú!';
    winner = null;

    notifyListeners();
  }

  void addFloatingMoney(String playerId, int amount, bool isIncome) {
    final event = FloatingMoneyEvent(
      id: '${DateTime.now().millisecondsSinceEpoch}_$amount',
      playerId: playerId,
      amount: amount,
      isIncome: isIncome,
    );
    floatingMoneyEvents.add(event);
    notifyListeners();

    // Auto remove floating chip after animation duration
    Timer(const Duration(milliseconds: 1400), () {
      floatingMoneyEvents.removeWhere((e) => e.id == event.id);
      notifyListeners();
    });
  }

  Future<void> rollDice() async {
    if (isRolling || isMoving || turnCompleted || winner != null || currentPlayer.bankrupt) {
      return;
    }

    // Handle Jail condition
    if (currentPlayer.inJail) {
      await _handleJailTurn();
      return;
    }

    isRolling = true;
    currentStage = EventStageType.diceRoll;
    notifyListeners();

    // Determine values deterministically before animation
    final targetDie1 = _random.nextInt(6) + 1;
    final targetDie2 = _random.nextInt(6) + 1;

    // Dice tumble sequence duration based on intensity
    final tumbleSteps = animationIntensity == AnimationIntensity.reduced ? 1 : 6;
    final delayMs = animationIntensity == AnimationIntensity.reduced ? 40 : 80;

    for (var i = 0; i < tumbleSteps; i++) {
      die1 = _random.nextInt(6) + 1;
      die2 = _random.nextInt(6) + 1;
      notifyListeners();
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    // Settle strictly on real engine values
    die1 = targetDie1;
    die2 = targetDie2;
    isRolling = false;
    notifyListeners();

    final moveSteps = diceTotal;
    gameLog = '${currentPlayer.name} gieo được $die1 + $die2 = $moveSteps điểm!';

    if (animationIntensity != AnimationIntensity.reduced) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Begin movement
    await _movePlayerSteps(currentPlayer, moveSteps);
  }

  Future<void> _handleJailTurn() async {
    isRolling = true;
    currentStage = EventStageType.jail;
    notifyListeners();

    die1 = _random.nextInt(6) + 1;
    die2 = _random.nextInt(6) + 1;
    isRolling = false;

    if (isDoubles) {
      currentPlayer.inJail = false;
      currentPlayer.jailTurns = 0;
      gameLog = '${currentPlayer.name} gieo ĐÔI ($die1 + $die2) nên ĐƯỢC THOÁT TÙ!';
      notifyListeners();
      await _movePlayerSteps(currentPlayer, diceTotal);
    } else {
      currentPlayer.jailTurns++;
      if (currentPlayer.jailTurns >= 3 && currentPlayer.cash >= 50) {
        currentPlayer.cash -= 50;
        currentPlayer.inJail = false;
        currentPlayer.jailTurns = 0;
        addFloatingMoney(currentPlayer.id, 50, false);
        gameLog = '${currentPlayer.name} nộp \$50 tiền phạt để THOÁT TÙ!';
        notifyListeners();
        await _movePlayerSteps(currentPlayer, diceTotal);
      } else {
        gameLog = '${currentPlayer.name} chưa gieo được Đôi, tiếp tục ở lại Nhà Tù (${currentPlayer.jailTurns}/3 lượt).';
        turnCompleted = true;
        currentStage = EventStageType.none;
        notifyListeners();

        if (currentPlayer.isAi && winner == null) {
          await Future.delayed(const Duration(milliseconds: 1000));
          endTurn();
        }
      }
    }
  }

  Future<void> payJailFineToExit() async {
    if (currentPlayer.inJail && currentPlayer.cash >= 50) {
      currentPlayer.cash -= 50;
      currentPlayer.inJail = false;
      currentPlayer.jailTurns = 0;
      addFloatingMoney(currentPlayer.id, 50, false);
      gameLog = '${currentPlayer.name} nộp \$50 để ra tù ngay lập tức!';
      notifyListeners();
    }
  }

  Future<void> _movePlayerSteps(MonopolyPlayer player, int steps) async {
    isMoving = true;
    notifyListeners();

    final stepDelayMs = switch (animationIntensity) {
      AnimationIntensity.cinematic => 160,
      AnimationIntensity.standard => 100,
      AnimationIntensity.reduced => 40,
    };

    for (var s = 0; s < steps; s++) {
      player.position = (player.position + 1) % board.length;
      requestCameraFocus(player.position);

      if (player.position == 0) {
        // Passing START bonus
        player.cash += 200;
        addFloatingMoney(player.id, 200, true);
        currentStage = EventStageType.passingStart;
        gameLog = '🎉 ${player.name} qua ô BẮT ĐẦU và nhận \$200!';
        notifyListeners();
        if (animationIntensity == AnimationIntensity.cinematic) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } else {
        notifyListeners();
      }

      await Future.delayed(Duration(milliseconds: stepDelayMs));
    }

    isMoving = false;
    await _resolveLandingTile(player, board[player.position]);
  }

  Future<void> _resolveLandingTile(MonopolyPlayer player, MonopolyTile tile) async {
    requestCameraFocus(tile.index);

    switch (tile.type) {
      case TileType.start:
      case TileType.freeParking:
      case TileType.jail:
        currentStage = EventStageType.none;
        break;

      case TileType.goToJail:
        currentStage = EventStageType.jail;
        player.position = 9; // Jail index
        player.inJail = true;
        player.jailTurns = 0;
        requestCameraFocus(9);
        gameLog = '🚔 ${player.name} BỊ BẮT VÀO TÙ!';
        break;

      case TileType.tax:
        player.cash -= tile.price;
        addFloatingMoney(player.id, tile.price, false);
        gameLog = '💸 ${player.name} nộp ${tile.name} \$${tile.price}.';
        _checkBankruptcy(player);
        break;

      case TileType.chance:
        currentStage = EventStageType.chanceCard;
        final card = MonopolyEngine.drawChance();
        activeCardModal = card;
        _applyCard(player, card);
        break;

      case TileType.communityChest:
        currentStage = EventStageType.chanceCard;
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
            currentStage = EventStageType.buyProperty;
            activeTileModal = tile;
          }
        } else if (tile.ownerId != player.id) {
          // Rent payment
          currentStage = EventStageType.rentPayment;
          final owner = players.firstWhere((p) => p.id == tile.ownerId);
          final rent = tile.currentRent;
          player.cash -= rent;
          owner.cash += rent;

          addFloatingMoney(player.id, rent, false);
          addFloatingMoney(owner.id, rent, true);

          gameLog = '🏦 ${player.name} trả \$$rent tiền thuê cho ${owner.name} (${tile.name})!';
          _checkBankruptcy(player);
        } else if (tile.ownerId == player.id && tile.type == TileType.property) {
          // Auto AI build if possible
          if (player.isAi && MonopolyEngine.aiShouldBuild(player, tile)) {
            buildHouse(player, tile);
          }
        }
        break;
    }

    turnCompleted = true;
    notifyListeners();

    // Auto AI turn continuation
    if (player.isAi && winner == null) {
      final delayMs = animationIntensity == AnimationIntensity.reduced ? 300 : 900;
      await Future.delayed(Duration(milliseconds: delayMs));
      endTurn();
    }
  }

  void buyProperty(MonopolyPlayer player, MonopolyTile tile) {
    if (player.cash >= tile.price) {
      player.cash -= tile.price;
      tile.ownerId = player.id;
      addFloatingMoney(player.id, tile.price, false);
      gameLog = '🏠 ${player.name} đã sở hữu ${tile.name} (\$${tile.price})!';
    }
    activeTileModal = null;
    currentStage = EventStageType.none;
    notifyListeners();
  }

  void buildHouse(MonopolyPlayer player, MonopolyTile tile) {
    final cost = tile.houseCost;
    if (tile.ownerId == player.id && tile.houses < 5 && player.cash >= cost) {
      player.cash -= cost;
      tile.houses++;
      addFloatingMoney(player.id, cost, false);
      currentStage = EventStageType.construction;
      gameLog = '🏗️ ${player.name} nâng cấp ${tile.houses == 5 ? "Khách Sạn 🏨" : "Nhà 🏠"} tại ${tile.name}!';
    }
    notifyListeners();
  }

  void _applyCard(MonopolyPlayer player, MonopolyCard card) {
    if (card.cashChange > 0) {
      player.cash += card.cashChange;
      addFloatingMoney(player.id, card.cashChange, true);
    } else if (card.cashChange < 0) {
      final cost = card.cashChange.abs();
      player.cash -= cost;
      addFloatingMoney(player.id, cost, false);
    }

    gameLog = '🎁 ${player.name} rút thẻ ${card.title}: ${card.description}';
    if (card.movePosition != null) {
      player.position = card.movePosition!;
      requestCameraFocus(player.position);
    }
    _checkBankruptcy(player);
  }

  void closeModals() {
    activeTileModal = null;
    activeCardModal = null;
    currentStage = EventStageType.none;
    notifyListeners();
  }

  void endTurn() {
    activeTileModal = null;
    activeCardModal = null;
    currentStage = EventStageType.none;
    turnCompleted = false;

    // Advance to next non-bankrupt player
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    } while (currentPlayer.bankrupt && players.any((p) => !p.bankrupt));

    requestCameraFocus(currentPlayer.position);
    _checkOverallWinner();
    notifyListeners();

    // Auto roll if AI turn
    if (currentPlayer.isAi && winner == null) {
      final delayMs = animationIntensity == AnimationIntensity.reduced ? 200 : 600;
      Future.delayed(Duration(milliseconds: delayMs), () => rollDice());
    }
  }

  void _checkBankruptcy(MonopolyPlayer player) {
    if (player.cash < 0) {
      player.bankrupt = true;
      player.cash = 0;
      currentStage = EventStageType.bankruptcy;
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
      currentStage = EventStageType.victory;
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
