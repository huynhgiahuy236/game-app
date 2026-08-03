import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/minesweeper_models.dart';
import '../services/minesweeper_repository.dart';
import '../viewmodels/minesweeper_view_model.dart';

class MinesweeperGameScreen extends StatefulWidget {
  const MinesweeperGameScreen({super.key, required this.repository});
  final MinesweeperRepository repository;

  @override
  State<MinesweeperGameScreen> createState() => _MinesweeperGameScreenState();
}

class _MinesweeperGameScreenState extends State<MinesweeperGameScreen>
    with SingleTickerProviderStateMixin {
  MinesweeperViewModel? viewModel;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;

  final TransformationController _transformationController = TransformationController();

  // Double-back exit protection
  bool _isDoubleBackWaiting = false;
  Timer? _doubleBackTimer;

  // Non-blocking toast state
  String? _toastMessage;
  Timer? _toastTimer;

  bool _hasCheckedSavedGame = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeOutQuad,
    );

    _loadViewModel();
  }

  Future<void> _loadViewModel() async {
    final loaded = await MinesweeperViewModel.create(widget.repository);
    loaded.addListener(_refresh);
    if (mounted) {
      setState(() => viewModel = loaded);
      _checkPendingSavedGame(loaded);
    }
  }

  void _checkPendingSavedGame(MinesweeperViewModel vm) {
    if (_hasCheckedSavedGame) return;
    _hasCheckedSavedGame = true;

    if (vm.pendingSavedGame != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _ResumeGameSheet(
            savedState: vm.pendingSavedGame!,
            onResume: () {
              Navigator.pop(ctx);
              vm.resumeSavedGame();
            },
            onNewGame: () {
              Navigator.pop(ctx);
              vm.clearSavedGame();
            },
          ),
        );
      });
    }
  }

  void _refresh() {
    if (!mounted) return;
    final vm = viewModel;
    if (vm != null && vm.status == MinesweeperStatus.lost && !_shakeController.isAnimating) {
      _triggerExplosionEffect();
    }
    setState(() {});
  }

  void _triggerExplosionEffect() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _doubleBackTimer?.cancel();
    _toastTimer?.cancel();
    viewModel?.removeListener(_refresh);
    viewModel?.dispose();
    _shakeController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  void _handleBackPress() {
    if (_isDoubleBackWaiting) {
      _doubleBackTimer?.cancel();
      Navigator.of(context).pop();
      return;
    }
    _isDoubleBackWaiting = true;
    _showToast('Nhấn lần nữa để thoát');
    _doubleBackTimer?.cancel();
    _doubleBackTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() => _isDoubleBackWaiting = false);
      }
    });
  }

  Future<void> _handleNewGameRequest() async {
    final vm = viewModel;
    if (vm == null) return;

    if (vm.firstClickDone && vm.status == MinesweeperStatus.playing) {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const _NewGameConfirmationSheet(),
      );
      if (confirmed != true) return;
    }

    _transformationController.value = Matrix4.identity();
    await vm.startNewGame();
  }

  Future<void> _showDifficultySheet() async {
    final vm = viewModel;
    if (vm == null) return;

    final selected = await showModalBottomSheet<MinesweeperDifficulty>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DifficultySelectionSheet(currentDifficulty: vm.difficulty),
    );

    if (selected != null && mounted) {
      if (selected == MinesweeperDifficulty.custom) {
        _showCustomConfigDialog();
      } else {
        if (vm.firstClickDone && vm.status == MinesweeperStatus.playing) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Đổi sang cấp độ ${selected.label}?'),
              content: const Text('Tiến trình ván Dò Mìn hiện tại sẽ bị xóa.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Đồng ý'),
                ),
              ],
            ),
          );
          if (confirm != true) return;
        }
        _transformationController.value = Matrix4.identity();
        await vm.startNewGame(newDiff: selected);
      }
    }
  }

  Future<void> _showCustomConfigDialog() async {
    final vm = viewModel;
    if (vm == null) return;

    final config = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => _CustomDifficultyDialog(
        initialRows: vm.customRows,
        initialCols: vm.customCols,
        initialMines: vm.customMines,
      ),
    );

    if (config != null && mounted) {
      _transformationController.value = Matrix4.identity();
      await vm.startNewGame(
        newDiff: MinesweeperDifficulty.custom,
        rows: config['rows'],
        cols: config['cols'],
        mines: config['mines'],
      );
    }
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    if (vm == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scale = _transformationController.value.getMaxScaleOnAxis();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C18) : const Color(0xFFF7F7FC),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Top Header ──────────────────────────────────────────
                  _MinesweeperHeader(
                    difficulty: vm.difficulty,
                    soundMuted: vm.soundMuted,
                    isPaused: vm.status == MinesweeperStatus.paused,
                    onBack: _handleBackPress,
                    onDifficultyTap: _showDifficultySheet,
                    onSoundToggle: vm.toggleSoundMuted,
                    onPauseToggle: vm.togglePause,
                  ),

                  // ── Status Bar (Timer & Flag Count) ─────────────────────
                  _MinesweeperStatusBar(vm: vm),

                  const SizedBox(height: 8),

                  // ── Touch Mode Switcher (Mở ô vs Cắm cờ) ────────────────
                  _MinesweeperModeToggle(vm: vm),

                  const SizedBox(height: 8),

                  // ── Board Container with Zoom/Pan & Explosion Shake ──────
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedBuilder(
                              animation: _shakeAnim,
                              builder: (context, child) {
                                final dx = sin(_shakeAnim.value * pi * 6) *
                                    (14 * (1 - _shakeAnim.value));
                                return Transform.translate(
                                  offset: Offset(dx, 0),
                                  child: child,
                                );
                              },
                              child: InteractiveViewer(
                                transformationController: _transformationController,
                                minScale: 1.0,
                                maxScale: 3.5,
                                boundaryMargin: const EdgeInsets.all(40),
                                onInteractionUpdate: (_) => setState(() {}),
                                child: Center(
                                  child: _MinesweeperBoardView(
                                    vm: vm,
                                    maxWidth: constraints.maxWidth - 24,
                                    maxHeight: constraints.maxHeight - 24,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Floating Reset Zoom Button when zoomed in
                        if (scale > 1.08)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: FloatingActionButton.small(
                              onPressed: _resetZoom,
                              tooltip: 'Về kích thước chuẩn',
                              backgroundColor: colors.surfaceContainerHigh,
                              foregroundColor: colors.onSurface,
                              child: const Icon(Icons.zoom_out_map_rounded, size: 18),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Bottom Action Button (Ván mới) ─────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _handleNewGameRequest,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text(
                          'Ván mới',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Non-blocking Toast Banner ────────────────────────────────
              if (_toastMessage != null)
                Positioned(
                  top: 60,
                  left: 20,
                  right: 20,
                  child: _ToastBanner(message: _toastMessage!),
                ),

              // ── Pause Overlay ───────────────────────────────────────────
              if (vm.status == MinesweeperStatus.paused)
                _MinesweeperPauseOverlay(
                  onResume: vm.togglePause,
                  onNewGame: _handleNewGameRequest,
                ),

              // ── Defeat Overlay ──────────────────────────────────────────
              if (vm.status == MinesweeperStatus.lost)
                _MinesweeperLossOverlay(
                  score: vm.elapsedSeconds,
                  difficultyLabel: vm.difficulty.label,
                  revealedCount: vm.board.where((c) => c.state == CellState.revealed && !c.isMine).length,
                  totalNonMines: vm.totalCells - vm.currentMines,
                  onRetry: () => vm.startNewGame(),
                  onNewGame: _showDifficultySheet,
                  onExit: _handleBackPress,
                ),

              // ── Victory Overlay ─────────────────────────────────────────
              if (vm.status == MinesweeperStatus.won)
                _MinesweeperVictoryOverlay(
                  elapsed: vm.elapsedSeconds,
                  bestTime: vm.stats.getBestTimeFor(vm.difficulty),
                  difficultyLabel: vm.difficulty.label,
                  onRestart: () => vm.startNewGame(),
                  onChangeDifficulty: _showDifficultySheet,
                  onExit: _handleBackPress,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  HEADER
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperHeader extends StatelessWidget {
  const _MinesweeperHeader({
    required this.difficulty,
    required this.soundMuted,
    required this.isPaused,
    required this.onBack,
    required this.onDifficultyTap,
    required this.onSoundToggle,
    required this.onPauseToggle,
  });

  final MinesweeperDifficulty difficulty;
  final bool soundMuted;
  final bool isPaused;
  final VoidCallback onBack;
  final VoidCallback onDifficultyTap;
  final VoidCallback onSoundToggle;
  final VoidCallback onPauseToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Quay lại sảnh',
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
                    'Dò Mìn',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Khám phá ô an toàn & tránh mìn nổ',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Difficulty Selector Badge
            InkWell(
              onTap: onDifficultyTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      difficulty.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down_rounded, size: 18, color: colors.onPrimaryContainer),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Sound Toggle
            IconButton(
              tooltip: soundMuted ? 'Bật âm thanh' : 'Tắt âm thanh',
              onPressed: onSoundToggle,
              icon: Icon(
                soundMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),

            // Pause Button
            IconButton(
              tooltip: isPaused ? 'Tiếp tục' : 'Tạm dừng',
              onPressed: onPauseToggle,
              icon: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 22,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  STATUS BAR (Timer & Remaining Mine Count)
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperStatusBar extends StatelessWidget {
  const _MinesweeperStatusBar({required this.vm});
  final MinesweeperViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final minutes = (vm.elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (vm.elapsedSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Mine Counter Badge
            Row(
              children: [
                const Text('🚩', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  '${vm.remainingFlags}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: vm.remainingFlags < 0 ? colors.error : colors.onSurface,
                  ),
                ),
              ],
            ),

            // Grid Size Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${vm.currentCols}×${vm.currentRows} · ${vm.currentMines} mìn',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),

            // Timer Badge
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  TOUCH MODE TOGGLE (Mở ô vs Cắm cờ)
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperModeToggle extends StatelessWidget {
  const _MinesweeperModeToggle({required this.vm});
  final MinesweeperViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(
            value: false,
            icon: Icon(Icons.touch_app_rounded, size: 18),
            label: Text('Mở ô'),
          ),
          ButtonSegment<bool>(
            value: true,
            icon: Icon(Icons.flag_rounded, size: 18),
            label: Text('Cắm cờ 🚩'),
          ),
        ],
        selected: {vm.flagMode},
        onSelectionChanged: (val) {
          HapticFeedback.selectionClick();
          vm.toggleFlagMode();
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primaryContainer
                : colors.surfaceContainerLow,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  BOARD VIEW (Render 16x16, 9x9, 16x30, Custom grid)
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperBoardView extends StatelessWidget {
  const _MinesweeperBoardView({
    required this.vm,
    required this.maxWidth,
    required this.maxHeight,
  });

  final MinesweeperViewModel vm;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cols = vm.currentCols;
    final rows = vm.currentRows;

    // Calculate optimal cell size based on grid dimensions
    final idealW = (maxWidth - (cols - 1) * 3) / cols;
    final idealH = (maxHeight - (rows - 1) * 3) / rows;

    double cellSize = min(idealW, idealH);
    if (vm.difficulty == MinesweeperDifficulty.easy) {
      cellSize = cellSize.clamp(32.0, 48.0);
    } else {
      cellSize = cellSize.clamp(28.0, 44.0);
    }

    final boardW = cellSize * cols + (cols - 1) * 3;
    final boardH = cellSize * rows + (rows - 1) * 3;

    return Container(
      width: boardW + 16,
      height: boardH + 16,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: boardW,
          height: boardH,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: vm.board.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemBuilder: (context, index) {
              final cell = vm.board[index];
              return Listener(
                onPointerDown: (event) {
                  // Desktop right click support
                  if (event.buttons == kSecondaryButton) {
                    vm.toggleFlag(index);
                  }
                },
                child: _MineTile(
                  cell: cell,
                  cellSize: cellSize,
                  onTap: () => vm.handleCellTap(index),
                  onLongPress: () {
                    HapticFeedback.lightImpact();
                    vm.toggleFlag(index);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  SINGLE MINE TILE (3D tactile hidden vs flat revealed)
// ───────────────────────────────────────────────────────────────────────────

class _MineTile extends StatelessWidget {
  const _MineTile({
    required this.cell,
    required this.cellSize,
    required this.onTap,
    required this.onLongPress,
  });

  final MineCell cell;
  final double cellSize;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Border border;
    List<BoxShadow>? shadows;

    if (cell.exploded) {
      bg = const Color(0xFFEF4444);
      border = Border.all(color: const Color(0xFF991B1B), width: 1.5);
    } else if (cell.isIncorrectFlag) {
      bg = const Color(0xFFFCA5A5);
      border = Border.all(color: const Color(0xFFDC2626), width: 1.5);
    } else if (cell.state == CellState.revealed) {
      bg = isDark ? const Color(0xFF1E293B) : Colors.white;
      border = Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        width: 0.5,
      );
    } else {
      // Hidden state: 3D tactile tile with 3px bottom shadow
      bg = isDark ? const Color(0xFF2A344D) : const Color(0xFFE2DFEE);
      final shadowColor = isDark ? const Color(0xFF1B2336) : const Color(0xFFB9B4CF);
      border = Border.all(color: shadowColor, width: 1.2);
      shadows = [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.8),
          blurRadius: 0,
          offset: const Offset(0, 3),
        ),
      ];
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(cellSize > 36 ? 8 : 6),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(cellSize > 36 ? 8 : 6),
            border: border,
            boxShadow: shadows,
          ),
          child: Center(
            child: _buildCellContent(colors),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(ColorScheme colors) {
    if (cell.exploded) {
      return const Text('💥', style: TextStyle(fontSize: 16));
    }

    if (cell.isIncorrectFlag) {
      return const Text('❌', style: TextStyle(fontSize: 14));
    }

    if (cell.state == CellState.flagged) {
      return Text('🚩', style: TextStyle(fontSize: max(10, cellSize * 0.48)));
    }

    if (cell.state == CellState.revealed) {
      if (cell.isMine) {
        return Text('💣', style: TextStyle(fontSize: max(10, cellSize * 0.48)));
      }
      if (cell.adjacentMines > 0) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${cell.adjacentMines}',
            style: TextStyle(
              fontSize: max(12, cellSize * 0.52),
              fontWeight: FontWeight.w900,
              color: _getMineNumberColor(cell.adjacentMines),
            ),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Color _getMineNumberColor(int number) {
    switch (number) {
      case 1:
        return const Color(0xFF0EA5E9); // Blue Cyan
      case 2:
        return const Color(0xFF16A34A); // Emerald Green
      case 3:
        return const Color(0xFFDC2626); // Bright Red
      case 4:
        return const Color(0xFF7C3AED); // Deep Purple
      case 5:
        return const Color(0xFF991B1B); // Dark Red
      case 6:
        return const Color(0xFF0D9488); // Teal
      case 7:
        return const Color(0xFF334155); // Dark Neutral
      case 8:
        return const Color(0xFF64748B); // Slate Gray
      default:
        return const Color(0xFF64748B);
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  PAUSE OVERLAY
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperPauseOverlay extends StatelessWidget {
  const _MinesweeperPauseOverlay({
    required this.onResume,
    required this.onNewGame,
  });

  final VoidCallback onResume;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Theme.of(context).dialogTheme.backgroundColor ?? colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pause_circle_rounded, size: 56, color: Color(0xFF7C3AED)),
                const SizedBox(height: 12),
                Text(
                  'Đã Tạm Dừng',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Đồng hồ đang dừng. Bấm tiếp tục để chơi tiếp.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onResume,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Tiếp tục chơi', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onNewGame,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Ván mới', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  DEFEAT OVERLAY
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperLossOverlay extends StatelessWidget {
  const _MinesweeperLossOverlay({
    required this.score,
    required this.difficultyLabel,
    required this.revealedCount,
    required this.totalNonMines,
    required this.onRetry,
    required this.onNewGame,
    required this.onExit,
  });

  final int score;
  final String difficultyLabel;
  final int revealedCount;
  final int totalNonMines;
  final VoidCallback onRetry;
  final VoidCallback onNewGame;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Theme.of(context).dialogTheme.backgroundColor ?? colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                const SizedBox(height: 12),
                Text(
                  'Mìn Đã Nổ!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cấp độ: $difficultyLabel\nĐã mở được: $revealedCount/$totalNonMines ô an toàn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onNewGame,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Chọn độ khó khác', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onExit,
                  child: const Text('Về danh sách trò chơi', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  VICTORY OVERLAY
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperVictoryOverlay extends StatelessWidget {
  const _MinesweeperVictoryOverlay({
    required this.elapsed,
    required this.bestTime,
    required this.difficultyLabel,
    required this.onRestart,
    required this.onChangeDifficulty,
    required this.onExit,
  });

  final int elapsed;
  final int bestTime;
  final String difficultyLabel;
  final VoidCallback onRestart;
  final VoidCallback onChangeDifficulty;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final minutes = (elapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed % 60).toString().padLeft(2, '0');

    final isNewRecord = bestTime == elapsed;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Theme.of(context).dialogTheme.backgroundColor ?? colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  'Dò Mìn Hoàn Hảo!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Bạn đã rà phá toàn bộ mìn an toàn cấp độ $difficultyLabel trong $minutes:$seconds!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (isNewRecord) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF08A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEAB308)),
                    ),
                    child: const Text(
                      '🏆 KỶ LỤC MỚI!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF713F12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRestart,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Chơi ván tiếp', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onChangeDifficulty,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Chọn độ khó khác', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onExit,
                  child: const Text('Về danh sách trò chơi', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  DIFFICULTY SELECTION BOTTOM SHEET
// ───────────────────────────────────────────────────────────────────────────

class _DifficultySelectionSheet extends StatelessWidget {
  const _DifficultySelectionSheet({required this.currentDifficulty});
  final MinesweeperDifficulty currentDifficulty;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).bottomSheetTheme.backgroundColor ?? colors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            'Chọn độ khó Dò Mìn',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          for (final diff in MinesweeperDifficulty.values) ...[
            _DifficultyOptionTile(
              difficulty: diff,
              isSelected: currentDifficulty == diff,
              onTap: () => Navigator.pop(context, diff),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DifficultyOptionTile extends StatelessWidget {
  const _DifficultyOptionTile({
    required this.difficulty,
    required this.isSelected,
    required this.onTap,
  });

  final MinesweeperDifficulty difficulty;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? colors.primaryContainer.withValues(alpha: 0.5) : colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? colors.primary : colors.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              _getBadgeLabel(difficulty),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: isSelected ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
        ),
        title: Text(
          difficulty.label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: colors.onSurface,
          ),
        ),
        subtitle: Text(
          difficulty.subtitle,
          style: TextStyle(
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: colors.primary)
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  String _getBadgeLabel(MinesweeperDifficulty diff) {
    switch (diff) {
      case MinesweeperDifficulty.easy:
        return '9×9';
      case MinesweeperDifficulty.medium:
        return '16×16';
      case MinesweeperDifficulty.hard:
        return '16×30';
      case MinesweeperDifficulty.custom:
        return '⚙️';
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  CUSTOM DIFFICULTY DIALOG
// ───────────────────────────────────────────────────────────────────────────

class _CustomDifficultyDialog extends StatefulWidget {
  const _CustomDifficultyDialog({
    required this.initialRows,
    required this.initialCols,
    required this.initialMines,
  });

  final int initialRows;
  final int initialCols;
  final int initialMines;

  @override
  State<_CustomDifficultyDialog> createState() => _CustomDifficultyDialogState();
}

class _CustomDifficultyDialogState extends State<_CustomDifficultyDialog> {
  late int rows;
  late int cols;
  late int mines;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    rows = widget.initialRows;
    cols = widget.initialCols;
    mines = widget.initialMines;
  }

  void _validate() {
    final maxMines = (rows * cols * 0.4).floor(); // Max 40% mines
    if (rows < 6 || rows > 30) {
      errorMessage = 'Số hàng phải từ 6 đến 30';
    } else if (cols < 6 || cols > 30) {
      errorMessage = 'Số cột phải từ 6 đến 30';
    } else if (mines < 1 || mines > maxMines) {
      errorMessage = 'Số mìn phải từ 1 đến $maxMines cho bàn ${rows}x$cols';
    } else {
      errorMessage = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxMines = (rows * cols * 0.4).floor();

    return AlertDialog(
      title: const Text('Bàn chơi Tùy chỉnh'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số hàng: $rows'),
            Slider(
              value: rows.toDouble(),
              min: 6,
              max: 30,
              divisions: 24,
              label: '$rows',
              onChanged: (v) {
                rows = v.toInt();
                if (mines > maxMines) mines = maxMines;
                _validate();
              },
            ),
            const SizedBox(height: 8),
            Text('Số cột: $cols'),
            Slider(
              value: cols.toDouble(),
              min: 6,
              max: 30,
              divisions: 24,
              label: '$cols',
              onChanged: (v) {
                cols = v.toInt();
                if (mines > maxMines) mines = maxMines;
                _validate();
              },
            ),
            const SizedBox(height: 8),
            Text('Số mìn: $mines (Tối đa $maxMines)'),
            Slider(
              value: mines.toDouble().clamp(1.0, maxMines.toDouble()),
              min: 1,
              max: maxMines.toDouble(),
              divisions: max(1, maxMines - 1),
              label: '$mines',
              onChanged: (v) {
                mines = v.toInt();
                _validate();
              },
            ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: colors.error, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: errorMessage == null
              ? () => Navigator.pop(context, {'rows': rows, 'cols': cols, 'mines': mines})
              : null,
          child: const Text('Tạo bàn'),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  RESUME SAVED GAME SHEET
// ───────────────────────────────────────────────────────────────────────────

class _ResumeGameSheet extends StatelessWidget {
  const _ResumeGameSheet({
    required this.savedState,
    required this.onResume,
    required this.onNewGame,
  });

  final MinesweeperSavedState savedState;
  final VoidCallback onResume;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final minutes = (savedState.elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (savedState.elapsedSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: Theme.of(context).bottomSheetTheme.backgroundColor ?? colors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.bookmark_rounded, size: 40, color: Color(0xFF7C3AED)),
          const SizedBox(height: 12),
          Text(
            'Tiếp tục ván chơi dở?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bàn ${savedState.cols}×${savedState.rows} · ${savedState.minesCount} mìn · Thời gian: $minutes:$seconds',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onResume,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Tiếp tục ván đang chơi', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onNewGame,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: colors.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Bắt đầu ván mới',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  NEW GAME CONFIRMATION SHEET
// ───────────────────────────────────────────────────────────────────────────

class _NewGameConfirmationSheet extends StatelessWidget {
  const _NewGameConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: Theme.of(context).bottomSheetTheme.backgroundColor ?? colors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.help_outline_rounded, size: 36, color: Color(0xFF7C3AED)),
          const SizedBox(height: 12),
          Text(
            'Bắt đầu ván mới?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tiến trình ván Dò Mìn hiện tại sẽ bị xóa.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, false),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Tiếp tục chơi', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: colors.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Bắt đầu ván mới',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  TOAST BANNER
// ───────────────────────────────────────────────────────────────────────────

class _ToastBanner extends StatelessWidget {
  const _ToastBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFA78BFA), size: 18),
                const SizedBox(width: 8),
                Text(
                  message,
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
    );
  }
}
