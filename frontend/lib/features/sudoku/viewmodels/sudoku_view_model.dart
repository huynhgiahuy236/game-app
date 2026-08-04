import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/sudoku_models.dart';
import '../services/sudoku_engine.dart';
import '../services/sudoku_repository.dart';

class SudokuViewModel extends ChangeNotifier {
  SudokuViewModel(this.repository, this.game);
  final SudokuRepository repository;
  final SudokuGame game;
  Timer? _timer;
  bool noteMode = false;
  bool autoCleanNotes = true;
  int? feedbackCell;
  int? lastWrongNumber;
  bool isHintCell = false;
  Timer? _feedbackTimer;

  void Function(String message)? onToastMessage;

  void startTimer() {
    _timer?.cancel();
    if (game.status != GameStatus.playing) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      game.elapsedSeconds++;
      if (game.elapsedSeconds % 5 == 0) repository.saveGame(game);
      notifyListeners();
    });
  }

  void select(int index) {
    game.selectedCell = index;
    notifyListeners();
  }

  void toggleNotes() {
    noteMode = !noteMode;
    onToastMessage?.call(noteMode ? 'Ghi chú đã bật' : 'Ghi chú đã tắt');
    notifyListeners();
  }

  void enter(int number) {
    final index = game.selectedCell;
    if (index == null ||
        game.clues[index] != 0 ||
        game.status != GameStatus.playing) {
      return;
    }
    if (noteMode) {
      final before = Set<int>.from(game.notes[index] ?? {});
      game.history.add(SudokuAction(index, game.values[index], before, {}));
      final notes = game.notes.putIfAbsent(index, () => {});
      notes.contains(number) ? notes.remove(number) : notes.add(number);
    } else {
      if (game.solution[index] != number) {
        game.mistakes++;
        game.history.add(
          SudokuAction(
            index,
            game.values[index],
            Set<int>.from(game.notes[index] ?? {}),
            {},
          ),
        );
        game.values[index] = number;
        game.notes.remove(index);
        feedbackCell = index;
        isHintCell = false;
        if (game.mistakes >= game.mistakeLimit) game.status = GameStatus.failed;
        _save();
        notifyListeners();

        _feedbackTimer?.cancel();
        _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
          if (feedbackCell == index) {
            feedbackCell = null;
            notifyListeners();
          }
        });
        return;
      }

      // Correct input!
      feedbackCell = index;
      lastWrongNumber = null;
      isHintCell = false;
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 600), () {
        if (feedbackCell == index) {
          feedbackCell = null;
          notifyListeners();
        }
      });

      final cleaned = <int, Set<int>>{};
      if (autoCleanNotes) {
        for (final peer in SudokuEngine.peers(index)) {
          if (game.notes[peer]?.contains(number) ?? false) {
            cleaned[peer] = Set<int>.from(game.notes[peer]!);
            game.notes[peer]!.remove(number);
          }
        }
      }
      game.history.add(
        SudokuAction(
          index,
          game.values[index],
          Set<int>.from(game.notes[index] ?? {}),
          cleaned,
        ),
      );
      game.values[index] = number;
      game.notes.remove(index);
      _checkComplete();
    }
    _save();
    notifyListeners();
  }

  void erase() {
    final i = game.selectedCell;
    if (i == null || game.clues[i] != 0) {
      if (i != null && game.clues[i] != 0) {
        onToastMessage?.call('Ô số ban đầu không thể xóa');
      }
      return;
    }
    if (game.values[i] == 0 && (game.notes[i]?.isEmpty ?? true)) {
      return;
    }
    game.history.add(
      SudokuAction(i, game.values[i], Set<int>.from(game.notes[i] ?? {}), {}),
    );
    game.values[i] = 0;
    game.notes.remove(i);
    _save();
    notifyListeners();
  }

  void undo() {
    if (game.history.isEmpty) {
      onToastMessage?.call('Không thể hoàn tác');
      return;
    }
    if (game.status != GameStatus.playing) return;
    final a = game.history.removeLast();
    game.values[a.index] = a.beforeValue;
    if (a.beforeNotes.isEmpty) {
      game.notes.remove(a.index);
    } else {
      game.notes[a.index] = Set<int>.from(a.beforeNotes);
    }
    for (final entry in a.cleanedNotes.entries) {
      game.notes[entry.key] = Set<int>.from(entry.value);
    }
    _save();
    notifyListeners();
  }

  void hint() {
    if (game.hintsUsed >= 3) {
      onToastMessage?.call('Không còn lượt gợi ý');
      return;
    }
    if (game.status != GameStatus.playing) return;
    var i = game.selectedCell;
    if (i == null || game.values[i] != 0 || game.clues[i] != 0) {
      i = game.values.indexWhere((v) => v == 0);
    }
    if (i < 0) return;
    game.values[i] = game.solution[i];
    game.notes.remove(i);
    game.hintsUsed++;
    game.selectedCell = i;
    feedbackCell = i;
    lastWrongNumber = null;
    isHintCell = true;

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1000), () {
      if (feedbackCell == i) {
        feedbackCell = null;
        isHintCell = false;
        notifyListeners();
      }
    });

    _checkComplete();
    _save();
    notifyListeners();
  }

  void pause() {
    if (game.status != GameStatus.playing) return;
    game.status = GameStatus.paused;
    _timer?.cancel();
    _save();
    notifyListeners();
  }

  void resume() {
    if (game.status != GameStatus.paused) return;
    game.status = GameStatus.playing;
    startTimer();
    _save();
    notifyListeners();
  }

  void retry() {
    for (var i = 0; i < 81; i++) {
      game.values[i] = game.clues[i];
    }
    game.notes.clear();
    game.history.clear();
    game.mistakes = 0;
    game.hintsUsed = 0;
    game.elapsedSeconds = 0;
    game.status = GameStatus.playing;
    startTimer();
    _save();
    notifyListeners();
  }

  void _checkComplete() {
    if (!game.complete) return;
    game.status = GameStatus.completed;
    _timer?.cancel();
    repository.clearGame();
  }

  void _save() => repository.saveGame(game);
  @override
  void dispose() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }
}
