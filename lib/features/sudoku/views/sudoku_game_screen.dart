import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sudoku_models.dart';
import '../services/sudoku_engine.dart';
import '../services/sudoku_repository.dart';
import '../viewmodels/sudoku_view_model.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = SudokuViewModel(widget.repository, widget.initialGame)
      ..startTimer();
    controller.addListener(_changed);
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
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Future<bool> _confirmExit() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rời ván chơi?'),
          content: const Text(
            'Tiến trình đã được lưu tự động. Bạn có thể tiếp tục bất cứ lúc nào.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ở lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rời đi'),
            ),
          ],
        ),
      ) ??
      false;

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
    final game = controller.game;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _confirmExit() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
                      game: game,
                      onBack: () async {
                        if (await _confirmExit() && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      onPause: controller.pause,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 820;
                          final board = SudokuBoard(controller: controller);
                          final controls = SudokuControls(controller: controller);
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
                if (game.status == GameStatus.paused)
                  SudokuPauseOverlay(
                    onResume: controller.resume,
                    onExit: () async {
                      if (await _confirmExit() && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                if (game.status == GameStatus.failed)
                  SudokuResultOverlay(
                    title: 'Tạm dừng một nhịp',
                    message: 'Bạn đã chạm giới hạn ${game.mistakeLimit} lỗi.',
                    icon: Icons.refresh_rounded,
                    primary: 'Thử lại',
                    onPrimary: controller.retry,
                    onExit: () => Navigator.pop(context),
                  ),
                if (game.status == GameStatus.completed)
                  SudokuResultOverlay(
                    title: 'Tuyệt vời!',
                    message:
                        'Hoàn thành ${game.difficulty.label} trong ${formatTime(game.elapsedSeconds)} • ${game.mistakes} lỗi • ${game.hintsUsed} gợi ý.',
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
    required this.game,
    required this.onBack,
    required this.onPause,
  });
  final SudokuGame game;
  final VoidCallback onBack;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Quay lại',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SUDOKU',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.4,
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    game.difficulty.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                formatTime(game.elapsedSeconds),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Tạm dừng',
              onPressed: onPause,
              icon: const Icon(Icons.pause_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Bảng Sudoku — border chuẩn, viền đậm 3×3 chính xác
// ───────────────────────────────────────────────────────────────────────────

class SudokuBoard extends StatelessWidget {
  const SudokuBoard({super.key, required this.controller});
  final SudokuViewModel controller;

  @override
  Widget build(BuildContext context) {
    final g = controller.game;
    final selected = g.selectedCell;
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outline, width: 2),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 81,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 9,
                ),
                itemBuilder: (context, i) {
                  final row = i ~/ 9,
                      col = i % 9,
                      value = g.values[i],
                      fixed = g.clues[i] != 0;
                  final isSelected = i == selected;
                  final same = selected != null &&
                      value != 0 &&
                      value == g.values[selected];
                  final related = selected != null &&
                      !isSelected &&
                      (row == selected ~/ 9 ||
                          col == selected % 9 ||
                          (row ~/ 3 == selected ~/ 9 ~/ 3 &&
                              col ~/ 3 == selected % 9 ~/ 3));

                  // Border đậm cho hàng/cột cuối của mỗi block 3×3
                  final isBlockRight = col % 3 == 2 && col != 8;
                  final isBlockBottom = row % 3 == 2 && row != 8;

                  Color bg;
                  if (isSelected) {
                    bg = colors.primaryContainer;
                  } else if (same) {
                    bg = colors.tertiaryContainer;
                  } else if (related) {
                    bg = colors.surfaceContainer;
                  } else {
                    bg = colors.surfaceContainerLow;
                  }

                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label:
                        'Hàng ${row + 1}, cột ${col + 1}, ${fixed ? "ô cố định" : "ô có thể sửa"}, ${value == 0 ? "trống" : "giá trị $value"}',
                    child: InkWell(
                      onTap: () => controller.select(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: bg,
                          border: Border(
                            top: BorderSide(
                              color: row == 0
                                  ? Colors.transparent
                                  : colors.outlineVariant,
                              width: row == 0 ? 0 : 0.5,
                            ),
                            left: BorderSide(
                              color: col == 0
                                  ? Colors.transparent
                                  : colors.outlineVariant,
                              width: col == 0 ? 0 : 0.5,
                            ),
                            right: BorderSide(
                              color: isBlockRight
                                  ? colors.outline
                                  : Colors.transparent,
                              width: isBlockRight ? 1.5 : 0,
                            ),
                            bottom: BorderSide(
                              color: isBlockBottom
                                  ? colors.outline
                                  : Colors.transparent,
                              width: isBlockBottom ? 1.5 : 0,
                            ),
                          ),
                        ),
                        child: Center(
                          child: value != 0
                              ? Text(
                                  '$value',
                                  style: TextStyle(
                                    fontSize: 22,
                                    height: 1,
                                    fontWeight: fixed
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: fixed
                                        ? colors.onSurface
                                        : colors.primary,
                                  ),
                                )
                              : _Notes(
                                  notes: g.notes[i] ?? {},
                                  active: isSelected,
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

class _Notes extends StatelessWidget {
  const _Notes({required this.notes, this.active = false});
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
                      ? colors.onPrimaryContainer
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
//  Controls — nút bấm đồng nhất, không gradient lè lọe
// ───────────────────────────────────────────────────────────────────────────

class SudokuControls extends StatelessWidget {
  const SudokuControls({super.key, required this.controller});
  final SudokuViewModel controller;

  @override
  Widget build(BuildContext context) {
    final g = controller.game;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        // ── Stats strip ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: _StatsItem(
                  icon: Icons.error_outline_rounded,
                  label: 'Lỗi',
                  value: '${g.mistakes}/${g.mistakeLimit}',
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: colors.outlineVariant,
              ),
              Expanded(
                child: _StatsItem(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Gợi ý',
                  value: '${3 - g.hintsUsed}/3',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Number pad (3×3) — nút đồng nhất, một tone ─────────────────
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemBuilder: (context, index) {
              final number = index + 1;
              return _SudokuNumberKey(
                number: number,
                onTap: () => controller.enter(number),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ── Action toolbar (4 actions đều 1 kiểu) ─────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SudokuAction(
              icon: Icons.edit_note_rounded,
              label: 'Ghi chú',
              active: controller.noteMode,
              onTap: controller.toggleNotes,
            ),
            _SudokuAction(
              icon: Icons.backspace_outlined,
              label: 'Xóa',
              onTap: controller.erase,
            ),
            _SudokuAction(
              icon: Icons.undo_rounded,
              label: 'Hoàn tác',
              onTap: g.history.isEmpty ? null : controller.undo,
            ),
            _SudokuAction(
              icon: Icons.lightbulb_outline_rounded,
              label: 'Gợi ý',
              onTap: g.hintsUsed >= 3 ? null : controller.hint,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsItem extends StatelessWidget {
  const _StatsItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ── Phím số — một style đồng nhất, có feedback nhấn ────────────────────────
class _SudokuNumberKey extends StatefulWidget {
  const _SudokuNumberKey({required this.number, required this.onTap});
  final int number;
  final VoidCallback onTap;

  @override
  State<_SudokuNumberKey> createState() => _SudokuNumberKeyState();
}

class _SudokuNumberKeyState extends State<_SudokuNumberKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Số ${widget.number}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) async {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.primary.withValues(alpha: _pressed ? 0.6 : 0.0),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '${widget.number}',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: colors.onPrimaryContainer,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action button — đồng nhất 1 kiểu, active/disabled rõ ràng ──────────────
class _SudokuAction extends StatelessWidget {
  const _SudokuAction({
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
    final colors = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    final fg = disabled
        ? colors.onSurfaceVariant.withValues(alpha: 0.4)
        : active
            ? colors.onPrimaryContainer
            : colors.primary;
    final bg = disabled
        ? colors.surfaceContainer
        : active
            ? colors.primaryContainer
            : colors.surfaceContainerHigh;
    return Semantics(
      button: true,
      enabled: !disabled,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: disabled
                      ? colors.onSurfaceVariant.withValues(alpha: 0.4)
                      : colors.onSurface,
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