enum MinesweeperSize {
  size16(4, 4, 3, '16 ô (4×4)', '3 mìn · Tập chơi'),
  size32(4, 8, 6, '32 ô (4×8)', '6 mìn · Vừa vặn'),
  size64(8, 8, 12, '64 ô (8×8)', '12 mìn · Thách thức'),
  size100(10, 10, 20, '100 ô (10×10)', '20 mìn · Cao thủ');

  const MinesweeperSize(
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
  });

  final int index;
  final int row;
  final int col;
  bool isMine;
  int adjacentMines;
  CellState state;
  bool exploded;
}

enum MinesweeperStatus {
  idle,
  playing,
  won,
  lost,
}

class MinesweeperStats {
  MinesweeperStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.bestTimeSeconds = 0,
  });

  int gamesPlayed;
  int gamesWon;
  int bestTimeSeconds;

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'bestTimeSeconds': bestTimeSeconds,
      };

  factory MinesweeperStats.fromJson(Map<String, dynamic> json) =>
      MinesweeperStats(
        gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
        gamesWon: (json['gamesWon'] as num?)?.toInt() ?? 0,
        bestTimeSeconds: (json['bestTimeSeconds'] as num?)?.toInt() ?? 0,
      );
}
