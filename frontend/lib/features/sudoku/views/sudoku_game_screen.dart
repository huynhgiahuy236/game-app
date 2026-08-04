import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sudoku_models.dart';
import '../services/sudoku_engine.dart';
import '../services/sudoku_repository.dart';
import '../viewmodels/sudoku_view_model.dart';
import 'hub_screen.dart';

class SudokuGameScreen extends StatefulWidget {
  const SudokuGameScreen({
    super.key,
    required this.repository,
    required this.initialGame,
  });
  final SudokuRepository repository;
  final SudokuGame initialGame;

  static Future<void> startNew(
    BuildContext context,
    SudokuRepository repo,
    Difficulty difficulty,
  ) async {
    final puzzle = PuzzleBank.forDifficulty(difficulty);
    final game = SudokuGame(
      gameId: DateTime.now().microsecondsSinceEpoch.toString(),
      puzzleId: puzzle.id,
      difficulty: difficulty,
      clues: List.from(puzzle.clues),
      values: List.from(puzzle.clues),
      solution: List.from(puzzle.solution),
      createdAt: DateTime.now(),
    );
    final stats = await repo.loadStats();
    stats.started++;
    stats.startedByDifficulty[difficulty.name] =
        (stats.startedByDifficulty[difficulty.name] ?? 0) + 1;
    await repo.saveStats(stats);
    await repo.saveGame(game);
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SudokuGameScreen(repository: repo, initialGame: game),
        ),
      );
    }
  }

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen>
    with WidgetsBindingObserver {
  late final SudokuViewModel controller;
  final FocusNode focusNode = FocusNode();
  bool completionRecorded = false;

  bool _isDoubleBackWaiting = false;
  Timer? _doubleBackTimer;
  String? _toastMessage;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = SudokuViewModel(widget.repository, widget.initialGame)
      ..startTimer();
    controller.onToastMessage = _showToast;
    controller.addListener(_changed);
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    if (mounted) {
      setState(() {
        _toastMessage = message;
      });
    }
    _toastTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  void _changed() {
    if (mounted) setState(() {});
    if (controller.game.status == GameStatus.completed && !completionRecorded) {
      completionRecorded = true;
      _recordCompletion();
    }
  }

  Future<void> _recordCompletion() async {
    final s = await widget.repository.loadStats();
    s.completed++;
    s.streak++;
    if (s.streak > s.bestStreak) s.bestStreak = s.streak;
    final key = controller.game.difficulty.name;
    s.completedByDifficulty[key] = (s.completedByDifficulty[key] ?? 0) + 1;
    if (s.bestTimes[key] == null ||
        controller.game.elapsedSeconds < s.bestTimes[key]!) {
      s.bestTimes[key] = controller.game.elapsedSeconds;
    }
    await widget.repository.saveStats(s);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) controller.pause();
  }

  @override
  void dispose() {
    _doubleBackTimer?.cancel();
    _toastTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleBackPress() async {
    if (controller.game.status == GameStatus.paused) {
      controller.resume();
      return;
    }
    if (_isDoubleBackWaiting) {
      _doubleBackTimer?.cancel();
      _isDoubleBackWaiting = false;
      await widget.repository.saveGame(controller.game);
      if (mounted) Navigator.pop(context);
    } else {
      await widget.repository.saveGame(controller.game);
      _showToast('Nhấn lần nữa để thoát');
      _isDoubleBackWaiting = true;
      _doubleBackTimer?.cancel();
      _doubleBackTimer = Timer(const Duration(milliseconds: 2000), () {
        _isDoubleBackWaiting = false;
      });
    }
  }

  Future<void> _handleNewGameRequest() async {
    if (!controller.game.hasProgress) {
      await _openDifficultySheetAndStartNew();
    } else {
      final choice = await showModalBottomSheet<_NewGameConfirmChoice>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => const _NewGameConfirmationSheet(),
      );
      if (choice == _NewGameConfirmChoice.startNew && mounted) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          await _openDifficultySheetAndStartNew();
        }
      }
    }
  }

  Future<void> _openDifficultySheetAndStartNew() async {
    final lastDifficulty = await widget.repository.loadLastDifficulty();
    final stats = await widget.repository.loadStats();
    if (!mounted) return;
    final difficulty = await showModalBottomSheet<Difficulty>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SudokuDifficultySheet(
        initialDifficulty: lastDifficulty,
        stats: stats,
      ),
    );
    if (difficulty != null && mounted) {
      await widget.repository.saveLastDifficulty(difficulty);
      final puzzle = PuzzleBank.forDifficulty(difficulty);
      final newGame = SudokuGame(
        gameId: DateTime.now().microsecondsSinceEpoch.toString(),
        puzzleId: puzzle.id,
        difficulty: difficulty,
        clues: List.from(puzzle.clues),
        values: List.from(puzzle.clues),
        solution: List.from(puzzle.solution),
        createdAt: DateTime.now(),
      );
      stats.started++;
      stats.startedByDifficulty[difficulty.name] =
          (stats.startedByDifficulty[difficulty.name] ?? 0) + 1;
      await widget.repository.saveStats(stats);
      await widget.repository.saveGame(newGame);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SudokuGameScreen(
              repository: widget.repository,
              initialGame: newGame,
            ),
          ),
        );
      }
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyN) {
      controller.toggleNotes();
    } else if (key == LogicalKeyboardKey.keyH) {
      controller.hint();
    } else if (key == LogicalKeyboardKey.keyP ||
        key == LogicalKeyboardKey.space) {
      controller.game.status == GameStatus.paused
          ? controller.resume()
          : controller.pause();
    } else if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      controller.erase();
    } else if (key == LogicalKeyboardKey.keyZ &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      controller.undo();
    } else if (key.keyLabel.length == 1) {
      final number = int.tryParse(key.keyLabel);
      if (number != null && number > 0) {
        controller.enter(number);
      } else {
        return KeyEventResult.ignored;
      }
    } else if ([
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ].contains(key)) {
      final i = controller.game.selectedCell ?? 0;
      final delta = key == LogicalKeyboardKey.arrowUp
          ? -9
          : key == LogicalKeyboardKey.arrowDown
          ? 9
          : key == LogicalKeyboardKey.arrowLeft
          ? -1
          : 1;
      controller.select((i + delta).clamp(0, 80));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C18) : colors.surface,
        body: SafeArea(
          child: Focus(
            autofocus: true,
            focusNode: focusNode,
            onKeyEvent: _key,
            child: Stack(
              children: [
                Column(
                  children: [
                    SudokuTopBar(
                      controller: controller,
                      onBack: _handleBackPress,
                      onPause: controller.pause,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 820;
                          final board = SudokuBoard(controller: controller);
                          final controls = SudokuControls(
                            controller: controller,
                            onNewGame: _handleNewGameRequest,
                          );
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 980),
                                child: wide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 3, child: board),
                                          const SizedBox(width: 28),
                                          Expanded(flex: 2, child: controls),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          board,
                                          const SizedBox(height: 20),
                                          controls,
                                        ],
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                _SudokuToastBanner(message: _toastMessage),
                if (controller.game.status == GameStatus.paused)
                  SudokuPauseOverlay(
                    onResume: controller.resume,
                    onExit: () async {
                      await widget.repository.saveGame(controller.game);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                if (controller.game.status == GameStatus.failed)
                  SudokuResultOverlay(
                    title: 'Tạm dừng một nhịp',
                    message:
                        'Bạn đã chạm giới hạn ${controller.game.mistakeLimit} lỗi.',
                    icon: Icons.refresh_rounded,
                    primary: 'Thử lại',
                    onPrimary: controller.retry,
                    onExit: () => Navigator.pop(context),
                  ),
                if (controller.game.status == GameStatus.completed)
                  SudokuResultOverlay(
                    title: 'Tuyệt vời!',
                    message:
                        'Hoàn thành ${controller.game.difficulty.label} trong ${formatTime(controller.game.elapsedSeconds)} • ${controller.game.mistakes} lỗi • ${controller.game.hintsUsed} gợi ý.',
                    icon: Icons.auto_awesome_rounded,
                    primary: 'Chơi lại',
                    onPrimary: controller.retry,
                    onExit: () => Navigator.pop(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String formatTime(int seconds) {
  final h = seconds ~/ 3600, m = seconds ~/ 60 % 60, s = seconds % 60;
  return h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ───────────────────────────────────────────────────────────────────────────
//  Top bar
// ───────────────────────────────────────────────────────────────────────────

class SudokuTopBar extends StatelessWidget {
  const SudokuTopBar({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onPause,
  });
  final SudokuViewModel controller;
  final VoidCallback onBack;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : colors.outlineVariant,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: isDark ? Colors.white : colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('🔢', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sudoku ${game.difficulty.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : colors.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Thử thách trí tuệ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : colors.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _TimerChip(seconds: game.elapsedSeconds),
            const SizedBox(width: 6),
            _MistakeChip(
              mistakes: game.mistakes,
              limit: game.mistakeLimit,
              isErrorActive: (controller.feedbackCell != null &&
                  game.values[controller.feedbackCell!] != 0 &&
                  game.values[controller.feedbackCell!] !=
                      game.solution[controller.feedbackCell!]),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onPause,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : colors.outlineVariant,
                  ),
                ),
                child: Icon(
                  Icons.pause_rounded,
                  size: 18,
                  color: isDark ? Colors.white : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? const Color(0xFF2A344D) : const Color(0xFFD8DCE7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Thời gian',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
              letterSpacing: 0.4,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatTime(seconds),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakeChip extends StatelessWidget {
  const _MistakeChip({
    required this.mistakes,
    required this.limit,
    this.isErrorActive = false,
  });
  final int mistakes;
  final int limit;
  final bool isErrorActive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isErrorActive
        ? (isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2))
        : (isDark ? const Color(0xFF141B2D) : Colors.white);
    final fg = isErrorActive ? const Color(0xFFDC2626) : colors.onSurface;
    final border = isErrorActive
        ? Border.all(color: const Color(0xFFEF4444), width: 1.5)
        : Border.all(
            color: isDark ? const Color(0xFF2A344D) : const Color(0xFFD8DCE7));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Lỗi',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isErrorActive
                  ? const Color(0xFFDC2626)
                  : colors.onSurfaceVariant,
              letterSpacing: 0.4,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$mistakes/$limit',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Shake Widget — hiệu ứng rung nhẹ khi điền sai
// ───────────────────────────────────────────────────────────────────────────
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({
    super.key,
    required this.child,
    required this.shake,
    this.deltaX = 8.0,
    this.duration = const Duration(milliseconds: 350),
  });

  final Widget child;
  final bool shake;
  final double deltaX;
  final Duration duration;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _offsetAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: -1.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -1.0, end: 1.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: -0.5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.5, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.shake) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value * widget.deltaX, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Bảng Sudoku — chuẩn màu sắc semantic, ưu tiên hiển thị & rung khi sai
// ───────────────────────────────────────────────────────────────────────────

class SudokuBoard extends StatelessWidget {
  const SudokuBoard({super.key, required this.controller});
  final SudokuViewModel controller;

  @override
  Widget build(BuildContext context) {
    final g = controller.game;
    final selected = g.selectedCell;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141B2D) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF3B4866) : const Color(0xFFB9C1D5),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? colors.primary.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 81,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 9,
                ),
                itemBuilder: (context, i) {
                  final r = i ~/ 9;
                  final c = i % 9;
                  final value = g.values[i];
                  final fixed = g.clues[i] != 0;
                  final isSelected = i == selected;
                  final sel = selected;

                  final isErrorCell = (!fixed && value != 0 && value != g.solution[i]);
                  final isShakeActive = (controller.feedbackCell == i && isErrorCell);
                  final isHintPulse = (controller.feedbackCell == i && controller.isHintCell);
                  final isCorrectPulse = (controller.feedbackCell == i && !controller.isHintCell && !isErrorCell);

                  final same = sel != null &&
                      value != 0 &&
                      value == g.values[sel];
                  final related = sel != null &&
                      !isSelected &&
                      (r == sel ~/ 9 ||
                          c == sel % 9 ||
                          (r ~/ 3 == sel ~/ 9 ~/ 3 &&
                              c ~/ 3 == sel % 9 ~/ 3));

                  // Priority color mapping
                  Color bg;
                  BorderSide cellBorder = BorderSide.none;
                  Color textColor;

                  if (isErrorCell) {
                    bg = isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2);
                    cellBorder = const BorderSide(color: Color(0xFFDC2626), width: 2.0);
                    textColor = const Color(0xFFDC2626);
                  } else if (isHintPulse) {
                    bg = isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1);
                    cellBorder = BorderSide(color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F8A72), width: 1.5);
                    textColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F8A72);
                  } else if (isCorrectPulse) {
                    bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
                    cellBorder = const BorderSide(color: Color(0xFF15803D), width: 1.5);
                    textColor = const Color(0xFF15803D);
                  } else if (isSelected) {
                    bg = isDark ? const Color(0xFF2E1B4E) : const Color(0xFFEDE9FE);
                    cellBorder = BorderSide(color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9), width: 2.0);
                    textColor = fixed
                        ? (isDark ? const Color(0xFFF3F4F8) : const Color(0xFF181620))
                        : (isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9));
                  } else if (same) {
                    bg = isDark ? const Color(0xFF2A2045) : const Color(0xFFDDD6FE);
                    cellBorder = BorderSide(color: isDark ? const Color(0xFF7C3AED) : const Color(0xFFC4B5FD), width: 1.0);
                    textColor = fixed
                        ? (isDark ? const Color(0xFFF3F4F8) : const Color(0xFF181620))
                        : (isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9));
                  } else if (related) {
                    bg = isDark ? const Color(0xFF191D33) : const Color(0xFFF5F3FF);
                    textColor = fixed
                        ? (isDark ? const Color(0xFFF3F4F8) : const Color(0xFF181620))
                        : (isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9));
                  } else {
                    bg = isDark ? const Color(0xFF141B2D) : Colors.white;
                    textColor = fixed
                        ? (isDark ? const Color(0xFFF3F4F8) : const Color(0xFF181620))
                        : (isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9));
                  }

                  // ── Standard Grid Lines (Major 3x3 vs Minor 1x1) ──
                  final BorderSide topSide = r == 0
                      ? BorderSide.none
                      : r % 3 == 0
                          ? BorderSide(color: isDark ? const Color(0xFF64748B) : const Color(0xFF7180A0), width: 1.8)
                          : BorderSide(color: isDark ? const Color(0xFF2A344D) : const Color(0xFFE1E4EC), width: 0.8);

                  final BorderSide leftSide = c == 0
                      ? BorderSide.none
                      : c % 3 == 0
                          ? BorderSide(color: isDark ? const Color(0xFF64748B) : const Color(0xFF7180A0), width: 1.8)
                          : BorderSide(color: isDark ? const Color(0xFF2A344D) : const Color(0xFFE1E4EC), width: 0.8);

                  final displayValue = value;

                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label:
                        'Hàng ${r + 1}, cột ${c + 1}, ${fixed ? "ô cố định" : "ô có thể sửa"}, ${displayValue == 0 ? "trống" : "giá trị $displayValue"}',
                    child: InkWell(
                      onTap: () => controller.select(i),
                      child: ShakeWidget(
                        shake: isShakeActive,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: bg,
                            border: Border(
                              top: topSide,
                              left: leftSide,
                              right: cellBorder != BorderSide.none ? cellBorder : BorderSide.none,
                              bottom: cellBorder != BorderSide.none ? cellBorder : BorderSide.none,
                            ),
                          ),
                          child: Center(
                            child: displayValue != 0
                                ? Text(
                                    '$displayValue',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: (fixed || isErrorCell)
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      color: textColor,
                                    ),
                                  )
                                : _SudokuCellNotes(
                                    notes: g.notes[i] ?? {},
                                    active: isSelected,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SudokuCellNotes extends StatelessWidget {
  const _SudokuCellNotes({required this.notes, this.active = false});
  final Set<int> notes;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        children: [
          for (var n = 1; n <= 9; n++)
            Center(
              child: Text(
                notes.contains(n) ? '$n' : '',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? colors.onPrimary
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Controls — Nút chức năng gắn nhãn & Phím số thông minh
// ───────────────────────────────────────────────────────────────────────────

class SudokuControls extends StatelessWidget {
  const SudokuControls({
    super.key,
    required this.controller,
    required this.onNewGame,
  });
  final SudokuViewModel controller;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final g = controller.game;
    final colors = Theme.of(context).colorScheme;

    final selIndex = g.selectedCell;
    final selValue = selIndex != null ? g.values[selIndex] : 0;
    final canErase = selIndex != null &&
        g.clues[selIndex] == 0 &&
        (g.values[selIndex] != 0 || (g.notes[selIndex]?.isNotEmpty ?? false));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Thanh công cụ có Nhãn (Icon + Text Label) ─────────────────
        Row(
          children: [
            Expanded(
              child: _SudokuToolCard(
                icon: Icons.undo_rounded,
                label: 'Hoàn tác',
                onTap: g.history.isEmpty ? null : controller.undo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SudokuToolCard(
                icon: Icons.backspace_outlined,
                label: 'Xóa',
                onTap: canErase ? controller.erase : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SudokuToolCard(
                icon: Icons.edit_note_rounded,
                label: controller.noteMode ? 'Ghi chú ON' : 'Ghi chú',
                active: controller.noteMode,
                onTap: controller.toggleNotes,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SudokuToolCard(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Gợi ý (${3 - g.hintsUsed})',
                onTap: g.hintsUsed >= 3 ? null : controller.hint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Bàn phím số 1–9 thông minh ─────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
          ),
          itemBuilder: (context, index) {
            final number = index + 1;
            final count = g.values.where((v) => v == number).length;
            final isCompleted = count >= 9;
            final isMatched = selValue == number;

            return _SudokuNumberKey(
              number: number,
              completed: isCompleted,
              matched: isMatched,
              onTap: isCompleted ? null : () => controller.enter(number),
            );
          },
        ),
        const SizedBox(height: 12),

        // ── Nút "Trò chơi Mới" có xác nhận ─────────────────────────────
        OutlinedButton.icon(
          onPressed: onNewGame,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            side: BorderSide(color: colors.primary, width: 1.5),
            foregroundColor: colors.primary,
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF141B2D) : Colors.white,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Trò chơi Mới'),
        ),
      ],
    );
  }
}

// ── Phím số Sudoku 1–9 ────────────────────────────────────────────────────────
class _SudokuNumberKey extends StatelessWidget {
  const _SudokuNumberKey({
    required this.number,
    required this.completed,
    required this.matched,
    required this.onTap,
  });
  final int number;
  final bool completed;
  final bool matched;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = completed
        ? (isDark ? const Color(0xFF0D1326) : const Color(0xFFF3F4F8))
        : matched
            ? (isDark ? const Color(0xFF3B1F6E) : const Color(0xFFEDE9FE))
            : (isDark ? const Color(0xFF141B2D) : Colors.white);

    final fg = completed
        ? (isDark ? const Color(0xFF4B5478) : const Color(0xFF9CA3AF))
        : matched
            ? (isDark ? const Color(0xFFEDE9FE) : const Color(0xFF6D28D9))
            : (isDark ? const Color(0xFFE8E6FF) : const Color(0xFF181620));

    final border = matched
        ? Border.all(color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9), width: 1.5)
        : completed
            ? Border.all(color: isDark ? const Color(0xFF1F2638) : const Color(0xFFE5E7EB))
            : Border.all(color: isDark ? const Color(0xFF2A344D) : const Color(0xFFD8DCE7));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: border,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: matched ? FontWeight.w900 : FontWeight.w800,
                  color: fg,
                  decoration: TextDecoration.none,
                ),
              ),
              if (completed) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: fg,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tool Card (Icon + Text Label) ──────────────────────────────────────────────
class _SudokuToolCard extends StatelessWidget {
  const _SudokuToolCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onTap == null;

    final bg = disabled
        ? (isDark ? const Color(0xFF0D1326) : const Color(0xFFF3F4F8))
        : active
            ? (isDark ? const Color(0xFF3B1F6E) : const Color(0xFFEDE9FE))
            : (isDark ? const Color(0xFF141B2D) : Colors.white);

    final fg = disabled
        ? (isDark ? const Color(0xFF4B5478) : const Color(0xFF9CA3AF))
        : active
            ? (isDark ? const Color(0xFFEDE9FE) : const Color(0xFF6D28D9))
            : (isDark ? const Color(0xFFE8E6FF) : const Color(0xFF181620));

    final border = active
        ? Border.all(color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9), width: 1.5)
        : disabled
            ? Border.all(color: isDark ? const Color(0xFF1F2638) : const Color(0xFFE5E7EB))
            : Border.all(color: isDark ? const Color(0xFF2A344D) : const Color(0xFFD8DCE7));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Overlays
// ───────────────────────────────────────────────────────────────────────────

class SudokuPauseOverlay extends StatelessWidget {
  const SudokuPauseOverlay({
    super.key,
    required this.onResume,
    required this.onExit,
  });
  final VoidCallback onResume;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: colors.surface.withValues(alpha: 0.92),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pause_circle_filled_rounded,
                size: 72,
                color: colors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Đang tạm dừng',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Bảng đã được che và đồng hồ đã dừng.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Tiếp tục'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onExit, child: const Text('Lưu và rời đi')),
            ],
          ),
        ),
      ),
    );
  }
}

class SudokuResultOverlay extends StatelessWidget {
  const SudokuResultOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.primary,
    required this.onPrimary,
    required this.onExit,
  });
  final String title;
  final String message;
  final IconData icon;
  final String primary;
  final VoidCallback onPrimary;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 64, color: colors.primary),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onPrimary,
                        child: Text(primary),
                      ),
                    ),
                    TextButton(
                      onPressed: onExit,
                      child: const Text('Về sảnh trò chơi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Non-intrusive Toast Banner Overlay ──────────────────────────────────────
class _SudokuToastBanner extends StatelessWidget {
  const _SudokuToastBanner({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 110,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: message == null
              ? const SizedBox.shrink()
              : Center(
                  key: ValueKey(message),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Color(0xFFA78BFA),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── New Game Confirmation Sheet ─────────────────────────────────────────────
enum _NewGameConfirmChoice { continuePlaying, startNew }

class _NewGameConfirmationSheet extends StatelessWidget {
  const _NewGameConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bắt đầu ván mới?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ván Sudoku hiện tại đang có tiến trình dở dang. Tạo ván mới sẽ thay thế tiến trình này.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _NewGameConfirmChoice.continuePlaying),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Tiếp tục chơi', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, _NewGameConfirmChoice.startNew),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: colors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Chọn ván mới', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}