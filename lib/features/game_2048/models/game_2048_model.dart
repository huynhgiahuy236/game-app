import 'dart:convert';

enum MoveDirection { up, down, left, right }

class Game2048Model {
  Game2048Model({
    required this.board,
    this.score = 0,
    this.bestScore = 0,
    this.moves = 0,
    this.won = false,
    this.gameOver = false,
    this.keepPlaying = false,
  });

  final List<int> board;
  int score;
  int bestScore;
  int moves;
  bool won;
  bool gameOver;
  bool keepPlaying;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
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
      if (json['schemaVersion'] != 1 ||
          board.length != 16 ||
          board.any((v) => v < 0 || (v != 0 && (v & (v - 1)) != 0))) {
        return null;
      }
      return Game2048Model(
        board: board,
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
