enum CaroBoardSize {
  classic3x3(3, 3, '3×3 (Nối 3 ô)'),
  medium8x8(8, 4, '8×8 (Nối 4 ô)'),
  large15x15(15, 5, '15×15 (Nối 5 ô)');

  const CaroBoardSize(this.dimension, this.winCount, this.label);
  final int dimension;
  final int winCount;
  final String label;

  int get totalCells => dimension * dimension;
}

enum CaroMode {
  vsAi('Đấu với Máy'),
  pvp('2 Người chơi');

  const CaroMode(this.label);
  final String label;
}

enum CaroSymbol {
  none(''),
  x('X'),
  o('O');

  const CaroSymbol(this.symbol);
  final String symbol;

  CaroSymbol get opposite => switch (this) {
        x => o,
        o => x,
        none => none,
      };
}

enum CaroDifficulty {
  easy('Dễ'),
  medium('Vừa'),
  hard('Khó');

  const CaroDifficulty(this.label);
  final String label;
}

class CaroMove {
  const CaroMove(this.index, this.symbol);
  final int index;
  final CaroSymbol symbol;
}

class CaroStats {
  CaroStats({
    this.xWins = 0,
    this.oWins = 0,
    this.draws = 0,
    this.aiWins = 0,
    this.playerWinsVsAi = 0,
    this.totalGames = 0,
  });

  int xWins;
  int oWins;
  int draws;
  int aiWins;
  int playerWinsVsAi;
  int totalGames;

  Map<String, dynamic> toJson() => {
        'xWins': xWins,
        'oWins': oWins,
        'draws': draws,
        'aiWins': aiWins,
        'playerWinsVsAi': playerWinsVsAi,
        'totalGames': totalGames,
      };

  factory CaroStats.fromJson(Map<String, dynamic> json) => CaroStats(
        xWins: (json['xWins'] as num?)?.toInt() ?? 0,
        oWins: (json['oWins'] as num?)?.toInt() ?? 0,
        draws: (json['draws'] as num?)?.toInt() ?? 0,
        aiWins: (json['aiWins'] as num?)?.toInt() ?? 0,
        playerWinsVsAi: (json['playerWinsVsAi'] as num?)?.toInt() ?? 0,
        totalGames: (json['totalGames'] as num?)?.toInt() ?? 0,
      );
}
