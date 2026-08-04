import 'dart:convert';

enum MoveDirection { up, down, left, right }

class Game2048Model {
  Game2048Model({
    required this.board,
    this.size = 4,
    this.score = 0,
    this.bestScore = 0,
    this.moves = 0,
    this.won = false,
    this.gameOver = false,
    this.keepPlaying = false,
  });

  List<int> board;
  int size;
  int score;
  int bestScore;
  int moves;
  bool won;
  bool gameOver;
  bool keepPlaying;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'size': size,
    'board': board,
    'score': score,
    'bestScore': bestScore,
    'moves': moves,
    'won': won,
    'gameOver': gameOver,
    'keepPlaying': keepPlaying,
  };

  String encode() => jsonEncode(toJson());

  static Game2048Model? decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final board = (json['board'] as List).cast<int>();
      final size = (json['size'] as int?) ?? 4;
      final schema = json['schemaVersion'] as int?;
      if ((schema != 1 && schema != 2) ||
          (size != 4 && size != 5 && size != 6) ||
          board.length != size * size ||
          board.any((v) => v < 0 || (v != 0 && (v & (v - 1)) != 0))) {
        return null;
      }
      return Game2048Model(
        board: board,
        size: size,
        score: json['score'] as int,
        bestScore: json['bestScore'] as int,
        moves: json['moves'] as int,
        won: json['won'] as bool,
        gameOver: json['gameOver'] as bool,
        keepPlaying: json['keepPlaying'] as bool,
      );
    } catch (_) {
      return null;
    }
  }
}

class Game2048Snapshot {
  const Game2048Snapshot(this.board, this.score, this.moves);
  final List<int> board;
  final int score;
  final int moves;
}
