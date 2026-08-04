// ═══════════════════════════════════════════════════════════════════════════
//  Block Puzzle Models
// ═══════════════════════════════════════════════════════════════════════════

class BlockPiece {
  const BlockPiece({
    required this.id,
    required this.cells, // list of (row, col) offsets relative to origin
    required this.colorIndex,
  });

  final int id;
  final List<(int, int)> cells;
  final int colorIndex;

  BlockPiece copyWith({List<(int, int)>? cells, int? colorIndex}) {
    return BlockPiece(
      id: id,
      cells: cells ?? this.cells,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }
}

class BlockPieceDefinition {
  const BlockPieceDefinition({required this.cells});
  final List<(int, int)> cells;
}

// All possible piece shapes (Tetris-like + extras)
const kAllPieceDefinitions = <BlockPieceDefinition>[
  // 1x1
  BlockPieceDefinition(cells: [(0, 0)]),

  // 1x2 horizontal
  BlockPieceDefinition(cells: [(0, 0), (0, 1)]),
  // 2x1 vertical
  BlockPieceDefinition(cells: [(0, 0), (1, 0)]),

  // 1x3 horizontal
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (0, 2)]),
  // 3x1 vertical
  BlockPieceDefinition(cells: [(0, 0), (1, 0), (2, 0)]),

  // 1x4 horizontal
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (0, 2), (0, 3)]),
  // 4x1 vertical
  BlockPieceDefinition(cells: [(0, 0), (1, 0), (2, 0), (3, 0)]),

  // 1x5 horizontal
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)]),
  // 5x1 vertical
  BlockPieceDefinition(cells: [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)]),

  // 2x2 square
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (1, 0), (1, 1)]),

  // L-shape
  BlockPieceDefinition(cells: [(0, 0), (1, 0), (2, 0), (2, 1)]),
  // L-mirror
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (1, 0), (2, 0)]),
  // L-rot2
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (0, 2), (1, 0)]),
  // L-rot3
  BlockPieceDefinition(cells: [(0, 0), (1, 0), (1, 1), (1, 2)]),
  // J-shape
  BlockPieceDefinition(cells: [(0, 1), (1, 1), (2, 0), (2, 1)]),
  // J-mirror
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (0, 2), (1, 2)]),

  // T-shape horizontal
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (0, 2), (1, 1)]),
  // T-shape vertical
  BlockPieceDefinition(cells: [(0, 0), (1, 0), (1, 1), (2, 0)]),

  // S-shape
  BlockPieceDefinition(cells: [(0, 1), (0, 2), (1, 0), (1, 1)]),
  // S-vertical
  BlockPieceDefinition(cells: [(0, 0), (1, 0), (1, 1), (2, 1)]),

  // Z-shape
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (1, 1), (1, 2)]),
  // Z-vertical
  BlockPieceDefinition(cells: [(0, 1), (1, 0), (1, 1), (2, 0)]),

  // 3x3 corner
  BlockPieceDefinition(cells: [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)]),
  // 3x3 corner mirror
  BlockPieceDefinition(cells: [(0, 2), (1, 2), (2, 0), (2, 1), (2, 2)]),
  // 3x3 corner top
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (0, 2), (1, 0), (2, 0)]),
  // 3x3 corner top-right
  BlockPieceDefinition(cells: [(0, 0), (0, 1), (0, 2), (1, 2), (2, 2)]),
];

class BlockPuzzleGame {
  static const int boardSize = 10;

  BlockPuzzleGame({
    List<List<int>>? board,
    this.score = 0,
    this.bestScore = 0,
    this.combo = 0,
    this.totalClears = 0,
    List<BlockPiece?>? tray,
    this.isGameOver = false,
  })  : board = board ??
            List.generate(boardSize, (_) => List.filled(boardSize, 0)),
        tray = tray ?? [null, null, null];

  final List<List<int>> board;
  int score;
  int bestScore;
  int combo;
  int totalClears;
  List<BlockPiece?> tray;
  bool isGameOver;

  bool isCellFilled(int row, int col) {
    if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) {
      return false;
    }
    return board[row][col] != 0;
  }

  bool canPlace(BlockPiece piece, int boardRow, int boardCol) {
    for (final (dr, dc) in piece.cells) {
      final r = boardRow + dr;
      final c = boardCol + dc;
      if (r < 0 || r >= boardSize || c < 0 || c >= boardSize) return false;
      if (board[r][c] != 0) return false;
    }
    return true;
  }

  BlockPuzzleGame copyWith({
    List<List<int>>? board,
    int? score,
    int? bestScore,
    int? combo,
    int? totalClears,
    List<BlockPiece?>? tray,
    bool? isGameOver,
  }) {
    return BlockPuzzleGame(
      board: board ?? this.board.map((r) => List<int>.from(r)).toList(),
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      combo: combo ?? this.combo,
      totalClears: totalClears ?? this.totalClears,
      tray: tray ?? List<BlockPiece?>.from(this.tray),
      isGameOver: isGameOver ?? this.isGameOver,
    );
  }
}
