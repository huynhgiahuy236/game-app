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
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
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
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    game.difficulty.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            // Lỗi chip ─ gọn ở header cạnh nút pause.
            _MistakeChip(mistakes: game.mistakes, limit: game.mistakeLimit),
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

class _MistakeChip extends StatelessWidget {
  const _MistakeChip({required this.mistakes, required this.limit});
  final int mistakes;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Lỗi',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$mistakes/$limit',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colors.onSurface,
            ),
          ),
        ],
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
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              // Lưới 3×3 block, mỗi block chứa 9 ô nhỏ + border riêng.
              child: GridView.count(
                crossAxisCount: 3,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var br = 0; br < 3; br++)
                    for (var bc = 0; bc < 3; bc++)
                      _SudokuBlock(
                        controller: controller,
                        blockRow: br,
                        blockCol: bc,
                        selected: selected,
                        colors: colors,
                      ),
                ],
              ),
              // NOTE: Border đậm 3×3 nằm ở Border.all(container) + clipRRect ở
              // trên; các đường mảnh 0.5 px bên trong được vẽ từ _SudokuBlock.
            ),
          ),
        ),
      ),
    );
  }
}

/// Một block 3×3 ─ có border đậm riêng bao ngoài, 9 ô nhỏ bên trong.
class _SudokuBlock extends StatelessWidget {
  const _SudokuBlock({
    required this.controller,
    required this.blockRow,
    required this.blockCol,
    required this.selected,
    required this.colors,
  });
  final SudokuViewModel controller;
  final int blockRow;
  final int blockCol;
  final int? selected;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final g = controller.game;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline, width: 1),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        itemBuilder: (context, idx) {
          final r = blockRow * 3 + idx ~/ 3;
          final c = blockCol * 3 + idx % 3;
          final i = r * 9 + c;
          final value = g.values[i];
          final fixed = g.clues[i] != 0;
          final isSelected = i == selected;
          final sel = selected;
          final same = sel != null &&
              value != 0 &&
              value == g.values[sel];
          final related = sel != null &&
              !isSelected &&
              (r == sel ~/ 9 ||
                  c == sel % 9 ||
                  (r ~/ 3 == sel ~/ 9 ~/ 3 &&
                      c ~/ 3 == sel % 9 ~/ 3));

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
                'Hàng ${r + 1}, cột ${c + 1}, ${fixed ? "ô cố định" : "ô có thể sửa"}, ${value == 0 ? "trống" : "giá trị $value"}',
            child: InkWell(
              onTap: () => controller.select(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: bg,
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
                      : _SudokuCellNotes(
                          notes: g.notes[i] ?? {},
                          active: isSelected,
                        ),
                ),
              ),
              // ignore: dead_code
            ),
          );
        },
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Action toolbar (4 nút tròn, đều 1 kiểu) ──────────────────
        Row(
          children: [
            Expanded(
              child: _SudokuAction(
                icon: Icons.undo_rounded,
                tooltip: 'Hoàn tác',
                onTap: g.history.isEmpty ? null : controller.undo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SudokuAction(
                icon: Icons.backspace_outlined,
                tooltip: 'Xóa',
                onTap: controller.erase,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SudokuAction(
                icon: Icons.edit_note_rounded,
                tooltip: 'Ghi chú',
                active: controller.noteMode,
                onTap: controller.toggleNotes,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SudokuAction(
                icon: Icons.lightbulb_outline_rounded,
                tooltip: 'Gợi ý',
                onTap: g.hintsUsed >= 3 ? null : controller.hint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Number pad (3×3) — phím số đồng nhất, đậm nét ─────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final number = index + 1;
            return _SudokuNumberKey(
              number: number,
              onTap: () => controller.enter(number),
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Nút "Trò chơi Mới" ────────────────────────────────────────
        FilledButton(
          onPressed: controller.retry,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('Trò chơi Mới'),
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
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String tooltip;
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
    final size = 56.0;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: !disabled,
        selected: active,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: colors.outlineVariant),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: fg, size: 24),
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