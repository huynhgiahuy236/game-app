import 'dart:math';
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
  late final MinesweeperViewModel vm;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;
  bool _showRedFlash = false;

  @override
  void initState() {
    super.initState();
    vm = MinesweeperViewModel(widget.repository)..addListener(_refresh);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeOutQuad,
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
    if (vm.status == MinesweeperStatus.lost && !_shakeController.isAnimating) {
      _triggerExplosionEffect();
    }
  }

  void _triggerExplosionEffect() {
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0.0);
    setState(() => _showRedFlash = true);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _showRedFlash = false);
    });
  }

  @override
  void dispose() {
    vm.removeListener(_refresh);
    vm.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _newGame() async {
    if (vm.status == MinesweeperStatus.playing) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bắt đầu ván mới?'),
          content: const Text('Tiến trình ván Dò Mìn hiện tại sẽ bị xóa.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ván mới'),
            ),
          ],
        ),
      ) ?? false;
      if (!confirmed) return;
    }
    vm.resetGame();
  }

  void _showConfigSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MinesweeperConfigSheet(vm: vm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── Header ───────────────────────────────────────────
                _MinesweeperHeader(
                  onBack: () => Navigator.pop(context),
                  onConfig: _showConfigSheet,
                ),

                // ── Timer & Flag Counter Bar ─────────────────────────
                _MinesweeperStatusBar(vm: vm),

                const SizedBox(height: 8),

                // ── Touch Mode Switcher (Mở ô vs Cắm cờ) ──────────────
                _MinesweeperModeToggle(vm: vm),

                const SizedBox(height: 12),

                // ── Board Container with Shake & Explosion Animation ─
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = vm.size.cols;
                      final rows = vm.size.rows;
                      final maxW = constraints.maxWidth - 24;
                      final maxH = constraints.maxHeight - 24;

                      final cellW = maxW / cols;
                      final cellH = maxH / rows;
                      final cellSize = min(cellW, cellH).clamp(24.0, 72.0);

                      final boardW = cellSize * cols;
                      final boardH = cellSize * rows;

                      return Center(
                        child: AnimatedBuilder(
                          animation: _shakeAnim,
                          builder: (context, child) {
                            final dx = sin(_shakeAnim.value * pi * 6) *
                                (12 * (1 - _shakeAnim.value));
                            return Transform.translate(
                              offset: Offset(dx, 0),
                              child: child,
                            );
                          },
                          child: Container(
                            width: boardW + 16,
                            height: boardH + 16,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.outlineVariant,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.shadow.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: vm.board.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 3,
                                  crossAxisSpacing: 3,
                                ),
                                itemBuilder: (context, index) {
                                  final cell = vm.board[index];
                                  return _MineTile(
                                    cell: cell,
                                    cellSize: cellSize,
                                    onTap: () => vm.handleCellTap(index),
                                    onLongPress: () {
                                      HapticFeedback.mediumImpact();
                                      vm.toggleFlag(index);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // ── Bottom Action ────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _newGame,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        'Ván mới',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Red explosion flash overlay
            if (_showRedFlash)
              Positioned.fill(
                child: Container(
                  color: const Color(0x66EF4444),
                ),
              ),

            // Victory Overlay
            if (vm.status == MinesweeperStatus.won)
              _MinesweeperVictoryOverlay(
                elapsed: vm.elapsedSeconds,
                onRestart: vm.resetGame,
                onExit: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _MinesweeperHeader extends StatelessWidget {
  const _MinesweeperHeader({required this.onBack, required this.onConfig});
  final VoidCallback onBack;
  final VoidCallback onConfig;

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
            IconButton(
              tooltip: 'Đổi kích thước',
              onPressed: onConfig,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Bar (Timer & Mines Counter) ───────────────────────────────────────
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),

            // Size Indicator Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                vm.size.label,
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

// ── Touch Mode Switcher (Chạm mở vs Cắm cờ) ─────────────────────────────────
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

// ── Single Mine Tile ────────────────────────────────────────────────────────
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

    Color bg;
    Border border;

    if (cell.exploded) {
      bg = const Color(0xFFEF4444); // Bright Red Explosion
      border = Border.all(color: const Color(0xFF991B1B), width: 1.5);
    } else if (cell.state == CellState.revealed) {
      bg = colors.surfaceContainer;
      border = Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.3), width: 0.5);
    } else {
      bg = colors.surfaceContainerHigh;
      border = Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.6), width: 1.0);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(cellSize > 36 ? 8 : 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(cellSize > 36 ? 8 : 4),
            border: border,
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

    if (cell.state == CellState.flagged) {
      return Text('🚩', style: TextStyle(fontSize: max(10, cellSize * 0.45)));
    }

    if (cell.state == CellState.revealed) {
      if (cell.isMine) {
        return Text('💣', style: TextStyle(fontSize: max(10, cellSize * 0.45)));
      }
      if (cell.adjacentMines > 0) {
        return Text(
          '${cell.adjacentMines}',
          style: TextStyle(
            fontSize: max(10, cellSize * 0.5),
            fontWeight: FontWeight.w900,
            color: _getMineNumberColor(cell.adjacentMines),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Color _getMineNumberColor(int number) {
    switch (number) {
      case 1:
        return const Color(0xFF0EA5E9); // Cyan
      case 2:
        return const Color(0xFF10B981); // Emerald Green
      case 3:
        return const Color(0xFFF43F5E); // Rose Red
      case 4:
        return const Color(0xFF8B5CF6); // Purple
      case 5:
        return const Color(0xFFF59E0B); // Amber
      case 6:
        return const Color(0xFF14B8A6); // Teal
      case 7:
        return const Color(0xFFD946EF); // Magenta
      default:
        return const Color(0xFF64748B); // Slate
    }
  }
}

// ── Victory Modal ────────────────────────────────────────────────────────────
class _MinesweeperVictoryOverlay extends StatelessWidget {
  const _MinesweeperVictoryOverlay({
    required this.elapsed,
    required this.onRestart,
    required this.onExit,
  });

  final int elapsed;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final minutes = (elapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed % 60).toString().padLeft(2, '0');

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text(
                    'Dò Mìn Hoàn Hảo!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bạn đã tìm thấy toàn bộ mìn an toàn trong $minutes:$seconds!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Chơi ván tiếp'),
                    ),
                  ),
                  const SizedBox(height: 8),
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
    );
  }
}

// ── Config Sheet (Đổi kích thước 16/32/64/100 ô) ────────────────────────────
class _MinesweeperConfigSheet extends StatelessWidget {
  const _MinesweeperConfigSheet({required this.vm});
  final MinesweeperViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.grid_view_rounded,
                    color: colors.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tùy chỉnh Dò Mìn',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'Chọn số lượng ô & cấp độ thử thách',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Column(
            children: MinesweeperSize.values.map((sz) {
              final active = vm.size == sz;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      vm.changeSize(sz);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: active
                            ? colors.primaryContainer
                            : colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: active
                            ? Border.all(color: colors.primary, width: 2.0)
                            : Border.all(
                                color: colors.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sz.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: active
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: active
                                        ? colors.onPrimaryContainer
                                        : colors.onSurface,
                                  ),
                                ),
                                Text(
                                  sz.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: active
                                        ? colors.onPrimaryContainer
                                            .withValues(alpha: 0.8)
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (active)
                            Icon(Icons.check_circle_rounded,
                                color: colors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
