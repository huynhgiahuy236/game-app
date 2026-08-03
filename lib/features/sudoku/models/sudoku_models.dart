import 'dart:convert';

enum Difficulty { easy, medium, hard, expert }

enum GameStatus { playing, paused, completed, failed }

extension DifficultyText on Difficulty {
  String get label => const ['Dễ', 'Trung bình', 'Khó', 'Chuyên gia'][index];
  String get description => const [
    'Thư giãn với nhiều số ban đầu',
    'Lối chơi cân bằng',
    'Ít gợi ý, cần suy luận nâng cao',
    'Thử thách dành cho cao thủ',
  ][index];
  String get challengeStars => const ['★☆☆☆', '★★☆☆', '★★★☆', '★★★★'][index];
}

class SudokuPuzzle {
  const SudokuPuzzle(this.id, this.difficulty, this.clues, this.solution);
  final String id;
  final Difficulty difficulty;
  final List<int> clues;
  final List<int> solution;
}

class SudokuAction {
  SudokuAction(
    this.index,
    this.beforeValue,
    this.beforeNotes,
    this.cleanedNotes,
  );
  final int index;
  final int beforeValue;
  final Set<int> beforeNotes;
  final Map<int, Set<int>> cleanedNotes;
}

class SudokuGame {
  SudokuGame({
    required this.gameId,
    required this.puzzleId,
    required this.difficulty,
    required this.clues,
    required this.values,
    required this.solution,
    required this.createdAt,
    this.elapsedSeconds = 0,
    this.mistakes = 0,
    this.mistakeLimit = 3,
    this.hintsUsed = 0,
    this.status = GameStatus.playing,
    this.selectedCell,
    Map<int, Set<int>>? notes,
  }) : notes = notes ?? {};

  final String gameId;
  final String puzzleId;
  final Difficulty difficulty;
  final List<int> clues;
  final List<int> values;
  final List<int> solution;
  final Map<int, Set<int>> notes;
  final DateTime createdAt;
  int elapsedSeconds;
  int mistakes;
  int mistakeLimit;
  int hintsUsed;
  GameStatus status;
  int? selectedCell;
  final List<SudokuAction> history = [];

  bool get complete =>
      values.every((value) => value != 0) &&
      List.generate(81, (i) => values[i] == solution[i]).every((v) => v);

  bool get hasProgress {
    for (var i = 0; i < 81; i++) {
      if (clues[i] == 0 && values[i] != 0) return true;
      if (notes[i]?.isNotEmpty ?? false) return true;
    }
    return mistakes > 0 || elapsedSeconds > 10;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'gameId': gameId,
    'puzzleId': puzzleId,
    'difficulty': difficulty.name,
    'clues': clues,
    'values': values,
    'solution': solution,
    'notes': notes.map((k, v) => MapEntry('$k', v.toList())),
    'elapsedSeconds': elapsedSeconds,
    'mistakes': mistakes,
    'mistakeLimit': mistakeLimit,
    'hintsUsed': hintsUsed,
    'status': status.name,
    'selectedCell': selectedCell,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdatedAt': DateTime.now().toIso8601String(),
    'history': history.map((a) => {
      'index': a.index,
      'beforeValue': a.beforeValue,
      'beforeNotes': a.beforeNotes.toList(),
      'cleanedNotes': a.cleanedNotes.map((k, v) => MapEntry('$k', v.toList())),
    }).toList(),
  };

  String encode() => jsonEncode(toJson());

  static SudokuGame? decode(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['schemaVersion'] != 1) return null;
      final clues = (j['clues'] as List).cast<int>();
      final values = (j['values'] as List).cast<int>();
      final solution = (j['solution'] as List).cast<int>();
      if (clues.length != 81 || values.length != 81 || solution.length != 81) {
        return null;
      }
      final game = SudokuGame(
        gameId: j['gameId'] as String,
        puzzleId: j['puzzleId'] as String,
        difficulty: Difficulty.values.byName(j['difficulty'] as String),
        clues: clues,
        values: values,
        solution: solution,
        notes: (j['notes'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(int.parse(k), Set<int>.from(v as List)),
        ),
        elapsedSeconds: j['elapsedSeconds'] as int,
        mistakes: j['mistakes'] as int,
        mistakeLimit: j['mistakeLimit'] as int,
        hintsUsed: j['hintsUsed'] as int,
        status: GameStatus.values.byName(j['status'] as String),
        selectedCell: j['selectedCell'] as int?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
      if (j['history'] != null) {
        for (final item in j['history'] as List) {
          final m = item as Map<String, dynamic>;
          game.history.add(SudokuAction(
            m['index'] as int,
            m['beforeValue'] as int,
            Set<int>.from(m['beforeNotes'] as List),
            (m['cleanedNotes'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(int.parse(k), Set<int>.from(v as List)),
            ),
          ));
        }
      }
      return game;
    } catch (_) {
      return null;
    }
  }
}

class SudokuStats {
  int started = 0;
  int completed = 0;
  int streak = 0;
  int bestStreak = 0;
  final Map<String, int> bestTimes = {};
  // Số ván đã bắt đầu / hoàn thành theo từng độ khó (dùng cho biểu đồ).
  final Map<String, int> startedByDifficulty = {};
  final Map<String, int> completedByDifficulty = {};

  Map<String, dynamic> toJson() => {
    'started': started,
    'completed': completed,
    'streak': streak,
    'bestStreak': bestStreak,
    'bestTimes': bestTimes,
    'startedByDifficulty': startedByDifficulty,
    'completedByDifficulty': completedByDifficulty,
  };
  static SudokuStats fromJson(String? raw) {
    final stats = SudokuStats();
    if (raw == null) return stats;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      stats.started = j['started'] as int;
      stats.completed = j['completed'] as int;
      stats.streak = j['streak'] as int;
      stats.bestStreak = j['bestStreak'] as int;
      stats.bestTimes.addAll(
        (j['bestTimes'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      );
      stats.startedByDifficulty.addAll(
        ((j['startedByDifficulty'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, v as int)),
      );
      stats.completedByDifficulty.addAll(
        ((j['completedByDifficulty'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, v as int)),
      );
    } catch (_) {}
    return stats;
  }
}
