import 'dart:convert';

enum MinesweeperDifficulty {
  easy(9, 9, 10, 'Dễ', '9×9 · 10 mìn · Thử thách chuẩn'),
  medium(16, 16, 40, 'Trung bình', '16×16 · 40 mìn · Thách thức'),
  hard(16, 30, 99, 'Khó', '16×30 · 99 mìn · Cao thủ'),
  custom(10, 10, 15, 'Tùy chỉnh', 'Tự chọn kích thước & số mìn');

  const MinesweeperDifficulty(
    this.rows,
    this.cols,
    this.minesCount,
    this.label,
    this.subtitle,
  );

  final int rows;
  final int cols;
  final int minesCount;
  final String label;
  final String subtitle;

  int get totalCells => rows * cols;

  /// Generate dynamic configuration for custom mode
  static MinesweeperDifficulty customConfig(int rows, int cols, int mines) {
    return MinesweeperDifficulty.custom;
  }
}

enum CellState {
  hidden,
  revealed,
  flagged,
}

class MineCell {
  MineCell({
    required this.index,
    required this.row,
    required this.col,
    this.isMine = false,
    this.adjacentMines = 0,
    this.state = CellState.hidden,
    this.exploded = false,
    this.isIncorrectFlag = false,
  });

  final int index;
  final int row;
  final int col;
  bool isMine;
  int adjacentMines;
  CellState state;
  bool exploded;
  bool isIncorrectFlag;

  Map<String, dynamic> toJson() => {
        'index': index,
        'row': row,
        'col': col,
        'isMine': isMine,
        'adjacentMines': adjacentMines,
        'state': state.index,
        'exploded': exploded,
        'isIncorrectFlag': isIncorrectFlag,
      };

  factory MineCell.fromJson(Map<String, dynamic> json) => MineCell(
        index: json['index'] as int,
        row: json['row'] as int,
        col: json['col'] as int,
        isMine: json['isMine'] as bool? ?? false,
        adjacentMines: json['adjacentMines'] as int? ?? 0,
        state: CellState.values[json['state'] as int? ?? 0],
        exploded: json['exploded'] as bool? ?? false,
        isIncorrectFlag: json['isIncorrectFlag'] as bool? ?? false,
      );
}

enum MinesweeperStatus {
  idle,
  playing,
  paused,
  won,
  lost,
}

class MinesweeperSavedState {
  MinesweeperSavedState({
    required this.difficulty,
    required this.rows,
    required this.cols,
    required this.minesCount,
    required this.board,
    required this.status,
    required this.elapsedSeconds,
    required this.firstClickDone,
    required this.flagMode,
    this.explodedMineIndex,
  });

  final MinesweeperDifficulty difficulty;
  final int rows;
  final int cols;
  final int minesCount;
  final List<MineCell> board;
  final MinesweeperStatus status;
  final int elapsedSeconds;
  final bool firstClickDone;
  final bool flagMode;
  final int? explodedMineIndex;

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty.index,
        'rows': rows,
        'cols': cols,
        'minesCount': minesCount,
        'board': board.map((c) => c.toJson()).toList(),
        'status': status.index,
        'elapsedSeconds': elapsedSeconds,
        'firstClickDone': firstClickDone,
        'flagMode': flagMode,
        'explodedMineIndex': explodedMineIndex,
      };

  factory MinesweeperSavedState.fromJson(Map<String, dynamic> json) {
    final boardList = (json['board'] as List)
        .map((c) => MineCell.fromJson(c as Map<String, dynamic>))
        .toList();

    return MinesweeperSavedState(
      difficulty: MinesweeperDifficulty.values[json['difficulty'] as int? ?? 0],
      rows: json['rows'] as int? ?? 9,
      cols: json['cols'] as int? ?? 9,
      minesCount: json['minesCount'] as int? ?? 10,
      board: boardList,
      status: MinesweeperStatus.values[json['status'] as int? ?? 0],
      elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
      firstClickDone: json['firstClickDone'] as bool? ?? false,
      flagMode: json['flagMode'] as bool? ?? false,
      explodedMineIndex: json['explodedMineIndex'] as int?,
    );
  }

  String encode() => jsonEncode(toJson());

  static MinesweeperSavedState? decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MinesweeperSavedState.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}

class MinesweeperStats {
  MinesweeperStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.bestTimeEasy = 0,
    this.bestTimeMedium = 0,
    this.bestTimeHard = 0,
    this.bestTimeCustom = 0,
  });

  int gamesPlayed;
  int gamesWon;
  int bestTimeEasy;
  int bestTimeMedium;
  int bestTimeHard;
  int bestTimeCustom;

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'bestTimeEasy': bestTimeEasy,
        'bestTimeMedium': bestTimeMedium,
        'bestTimeHard': bestTimeHard,
        'bestTimeCustom': bestTimeCustom,
      };

  factory MinesweeperStats.fromJson(Map<String, dynamic> json) =>
      MinesweeperStats(
        gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
        gamesWon: (json['gamesWon'] as num?)?.toInt() ?? 0,
        bestTimeEasy: (json['bestTimeEasy'] as num?)?.toInt() ?? (json['bestTimeSeconds'] as num?)?.toInt() ?? 0,
        bestTimeMedium: (json['bestTimeMedium'] as num?)?.toInt() ?? 0,
        bestTimeHard: (json['bestTimeHard'] as num?)?.toInt() ?? 0,
        bestTimeCustom: (json['bestTimeCustom'] as num?)?.toInt() ?? 0,
      );

  int getBestTimeFor(MinesweeperDifficulty difficulty) {
    switch (difficulty) {
      case MinesweeperDifficulty.easy:
        return bestTimeEasy;
      case MinesweeperDifficulty.medium:
        return bestTimeMedium;
      case MinesweeperDifficulty.hard:
        return bestTimeHard;
      case MinesweeperDifficulty.custom:
        return bestTimeCustom;
    }
  }

  void updateBestTime(MinesweeperDifficulty difficulty, int timeSeconds) {
    final current = getBestTimeFor(difficulty);
    if (current == 0 || timeSeconds < current) {
      switch (difficulty) {
        case MinesweeperDifficulty.easy:
          bestTimeEasy = timeSeconds;
          break;
        case MinesweeperDifficulty.medium:
          bestTimeMedium = timeSeconds;
          break;
        case MinesweeperDifficulty.hard:
          bestTimeHard = timeSeconds;
          break;
        case MinesweeperDifficulty.custom:
          bestTimeCustom = timeSeconds;
          break;
      }
    }
  }
}
