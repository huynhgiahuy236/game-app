import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/caro_models.dart';
import '../services/caro_repository.dart';
import '../viewmodels/caro_view_model.dart';

class CaroGameScreen extends StatefulWidget {
  const CaroGameScreen({super.key, required this.repository});
  final CaroRepository repository;

  @override
  State<CaroGameScreen> createState() => _CaroGameScreenState();
}

class _CaroGameScreenState extends State<CaroGameScreen> {
  late final CaroViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = CaroViewModel(widget.repository)..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    vm.removeListener(_refresh);
    vm.dispose();
    super.dispose();
  }

  Future<void> _newGame() async {
    if (vm.history.isNotEmpty && vm.winner == CaroSymbol.none && !vm.isDraw) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bắt đầu ván mới?'),
          content: const Text('Tiến trình ván Cờ Caro hiện tại sẽ bị xóa.'),
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
    vm.resetBoard();
  }

  void _showConfigSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CaroConfigSheet(vm: vm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            _CaroHeader(
              onBack: () => Navigator.pop(context),
              onConfig: _showConfigSheet,
            ),

            // ── Mode & Turn Info Bar ─────────────────────────────────
            _CaroTurnBar(vm: vm),

            const SizedBox(height: 12),

            // ── Board Container ──────────────────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dim = vm.boardSize.dimension;
                  final maxW = constraints.maxWidth - 24;
                  final maxH = constraints.maxHeight - 24;
                  final boardSizePx = (maxW < maxH ? maxW : maxH).clamp(240.0, 560.0);

                  return Center(
                    child: SizedBox(
                      width: boardSizePx,
                      height: boardSizePx,
                      child: Container(
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
                              crossAxisCount: dim,
                              mainAxisSpacing: dim > 8 ? 2 : 6,
                              crossAxisSpacing: dim > 8 ? 2 : 6,
                            ),
                            itemBuilder: (context, index) {
                              final isWinning =
                                  vm.winningLine?.contains(index) ?? false;
                              return _CaroTile(
                                symbol: vm.board[index],
                                isWinning: isWinning,
                                dimension: dim,
                                onTap: () => vm.playMove(index),
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

            const SizedBox(height: 16),

            // ── Control Bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: vm.history.isEmpty || vm.isAiThinking
                          ? null
                          : vm.undo,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Hoàn tác'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _newGame,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Ván mới'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _CaroHeader extends StatelessWidget {
  const _CaroHeader({required this.onBack, required this.onConfig});
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
                    'Cờ Caro / OX',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Tận hưởng chiến thuật đỉnh cao',
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
              tooltip: 'Cấu hình bàn cờ',
              onPressed: onConfig,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Turn & Mode Bar ──────────────────────────────────────────────────────────
class _CaroTurnBar extends StatelessWidget {
  const _CaroTurnBar({required this.vm});
  final CaroViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isXTurn = vm.turn == CaroSymbol.x;

    String statusText;
    if (vm.winner == CaroSymbol.x) {
      statusText = '🎉 Quân X Chiến Thắng!';
    } else if (vm.winner == CaroSymbol.o) {
      statusText = vm.mode == CaroMode.vsAi ? '🤖 Máy Thắng!' : '🎉 Quân O Chiến Thắng!';
    } else if (vm.isDraw) {
      statusText = '🤝 Ván Cờ Hòa!';
    } else if (vm.isAiThinking) {
      statusText = '🤖 Máy đang suy nghĩ...';
    } else {
      statusText = 'Lượt đi: ${isXTurn ? "Quân X" : (vm.mode == CaroMode.vsAi ? "Máy (O)" : "Quân O")}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            // Mode Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                vm.boardSize.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: vm.winner != CaroSymbol.none
                      ? const Color(0xFFEAB308)
                      : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ô Cờ Caro Single Tile ────────────────────────────────────────────────────
class _CaroTile extends StatelessWidget {
  const _CaroTile({
    required this.symbol,
    required this.isWinning,
    required this.dimension,
    required this.onTap,
  });
  final CaroSymbol symbol;
  final bool isWinning;
  final int dimension;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Color bg = colors.surfaceContainerLow;
    Color borderCol = colors.outlineVariant.withValues(alpha: 0.4);

    if (isWinning) {
      bg = const Color(0xFFFEF08A); // Gold win highlight
      borderCol = const Color(0xFFEAB308);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: symbol == CaroSymbol.none
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(dimension > 8 ? 4 : 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(dimension > 8 ? 4 : 8),
            border: Border.all(
              color: borderCol,
              width: isWinning ? 2.0 : 1.0,
            ),
          ),
          child: Center(
            child: _buildSymbolWidget(symbol, dimension, isWinning),
          ),
        ),
      ),
    );
  }

  Widget _buildSymbolWidget(CaroSymbol sym, int dim, bool isWinning) {
    if (sym == CaroSymbol.none) return const SizedBox.shrink();

    final fontSize = dim == 3 ? 38.0 : (dim == 8 ? 20.0 : 12.0);

    if (sym == CaroSymbol.x) {
      return Text(
        'X',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: isWinning ? const Color(0xFF0284C7) : const Color(0xFF0EA5E9), // Cyan X
          shadows: [
            BoxShadow(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ],
        ),
      );
    } else {
      return Text(
        'O',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: isWinning ? const Color(0xFFE11D48) : const Color(0xFFF43F5E), // Rose O
          shadows: [
            BoxShadow(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ],
        ),
      );
    }
  }
}

// ── Cấu hình Chế độ & Kích thước bàn cờ — M3 Redesign ──────────────────────────
class _CaroConfigSheet extends StatefulWidget {
  const _CaroConfigSheet({required this.vm});
  final CaroViewModel vm;

  @override
  State<_CaroConfigSheet> createState() => _CaroConfigSheetState();
}

class _CaroConfigSheetState extends State<_CaroConfigSheet> {
  late CaroBoardSize selectedSize;
  late CaroMode selectedMode;
  late CaroDifficulty selectedDiff;

  @override
  void initState() {
    super.initState();
    selectedSize = widget.vm.boardSize;
    selectedMode = widget.vm.mode;
    selectedDiff = widget.vm.difficulty;
  }

  void _apply() {
    widget.vm.configure(
      newSize: selectedSize,
      newMode: selectedMode,
      newDifficulty: selectedDiff,
    );
    Navigator.pop(context);
  }

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
          // Drag handle indicator
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

          // Title & Close Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune_rounded, color: colors.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tùy chỉnh Cờ Caro',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'Chọn kích thước bàn cờ & chế độ chơi',
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

          // 1. Kích thước Bàn Cờ
          const _ConfigSectionTitle(
            icon: Icons.grid_view_rounded,
            title: 'Kích thước Bàn cờ',
          ),
          const SizedBox(height: 10),
          Row(
            children: CaroBoardSize.values.map((size) {
              final active = selectedSize == size;
              final subtitle = size == CaroBoardSize.classic3x3
                  ? 'Nối 3 ô'
                  : (size == CaroBoardSize.medium8x8 ? 'Nối 4 ô' : 'Nối 5 ô');
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _SelectableCard(
                    title: '${size.dimension}×${size.dimension}',
                    subtitle: subtitle,
                    active: active,
                    onTap: () => setState(() => selectedSize = size),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // 2. Chế độ Đối thủ
          const _ConfigSectionTitle(
            icon: Icons.sports_esports_rounded,
            title: 'Chế độ Chơi',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SelectableCard(
                  icon: Icons.smart_toy_rounded,
                  title: 'Đấu với Máy',
                  subtitle: 'Chơi 1 mình',
                  active: selectedMode == CaroMode.vsAi,
                  onTap: () => setState(() => selectedMode = CaroMode.vsAi),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SelectableCard(
                  icon: Icons.people_alt_rounded,
                  title: '2 Người chơi',
                  subtitle: 'Đấu trên 1 máy',
                  active: selectedMode == CaroMode.pvp,
                  onTap: () => setState(() => selectedMode = CaroMode.pvp),
                ),
              ),
            ],
          ),

          // 3. Độ khó Máy (nếu chọn Vs AI)
          if (selectedMode == CaroMode.vsAi) ...[
            const SizedBox(height: 20),
            const _ConfigSectionTitle(
              icon: Icons.psychology_rounded,
              title: 'Độ khó Máy',
            ),
            const SizedBox(height: 10),
            Row(
              children: CaroDifficulty.values.map((diff) {
                final active = selectedDiff == diff;
                final icon = diff == CaroDifficulty.easy
                    ? Icons.sentiment_satisfied_alt_rounded
                    : (diff == CaroDifficulty.medium
                        ? Icons.bolt_rounded
                        : Icons.local_fire_department_rounded);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _SelectableCard(
                      icon: icon,
                      title: diff.label,
                      subtitle: '',
                      active: active,
                      onTap: () => setState(() => selectedDiff = diff),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 24),

          // CTA Action
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _apply,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text(
                'Áp dụng & Bắt đầu ván mới',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigSectionTitle extends StatelessWidget {
  const _ConfigSectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });
  final IconData? icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final bg = active ? colors.primaryContainer : colors.surfaceContainerHigh;
    final fg = active ? colors.onPrimaryContainer : colors.onSurface;
    final border = active
        ? Border.all(color: colors.primary, width: 2.0)
        : Border.all(color: colors.outlineVariant.withValues(alpha: 0.5));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 22,
                  color: active ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  color: fg,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? colors.onPrimaryContainer.withValues(alpha: 0.8)
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
