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
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF141B2D) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Bắt đầu ván mới?',
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800),
              ),
              content: Text(
                'Tiến trình ván Cờ Caro hiện tại sẽ bị xóa.',
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Hủy',
                      style: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B))),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9)),
                  child: const Text('Đồng ý'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }
    vm.resetBoard();
  }

  void _showConfigSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CaroConfigSheet(vm: vm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C18) : colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header ───────────────────────────────────────────
            _CaroHeader(
              onBack: () => Navigator.pop(context),
              onConfig: _showConfigSheet,
              boardSizeLabel: vm.boardSize.label,
              modeLabel: vm.mode == CaroMode.vsAi ? 'Đấu Máy 🤖' : '2 Người 👥',
            ),

            // ── Mode & Turn HUD Bar ─────────────────────────────────
            _CaroTurnBar(vm: vm),

            const SizedBox(height: 10),

            // ── Board Container ──────────────────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dim = vm.boardSize.dimension;
                  final maxW = constraints.maxWidth - 24;
                  final maxH = constraints.maxHeight - 24;
                  final boardSizePx =
                      (maxW < maxH ? maxW : maxH).clamp(240.0, 560.0);

                  final borderColor =
                      isDark ? const Color(0xFF334155) : colors.outlineVariant;

                  return Center(
                    child: SizedBox(
                      width: boardSizePx,
                      height: boardSizePx,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0B0F19)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: borderColor,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0xFF0EA5E9)
                                      .withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.08),
                              blurRadius: 20,
                              spreadRadius: -2,
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
                              mainAxisSpacing: dim > 8 ? 2 : 5,
                              crossAxisSpacing: dim > 8 ? 2 : 5,
                            ),
                            itemBuilder: (context, index) {
                              final isWinning =
                                  vm.winningLine?.contains(index) ?? false;
                              final row = index ~/ dim;
                              final col = index % dim;
                              final isEven = (row + col) % 2 == 0;

                              return _CaroTile(
                                symbol: vm.board[index],
                                isWinning: isWinning,
                                dimension: dim,
                                isEven: isEven,
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

            const SizedBox(height: 10),

            // ── Control Action Buttons ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: vm.history.isEmpty || vm.isAiThinking
                          ? null
                          : vm.undo,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF475569)
                              : colors.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(Icons.undo_rounded,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : colors.onSurfaceVariant),
                      label: Text('Hoàn tác',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : colors.onSurface)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0EA5E9)
                                .withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _newGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded,
                            color: Colors.white),
                        label: const Text('Ván mới',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ),
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

// ───────────────────────────────────────────────────────────────────────────
//  HEADER (Overflow-proof)
// ───────────────────────────────────────────────────────────────────────────

class _CaroHeader extends StatelessWidget {
  const _CaroHeader({
    required this.onBack,
    required this.onConfig,
    required this.boardSizeLabel,
    required this.modeLabel,
  });

  final VoidCallback onBack;
  final VoidCallback onConfig;
  final String boardSizeLabel;
  final String modeLabel;

  @override
  Widget build(BuildContext context) {
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
                        colors: [Color(0xFF0EA5E9), Color(0xFFF43F5E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('❌', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Cờ Caro / OX',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : colors.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '$modeLabel · $boardSizeLabel',
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
            const SizedBox(width: 6),
            InkWell(
              onTap: onConfig,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : colors.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded,
                        size: 15,
                        color: isDark
                            ? const Color(0xFF38BDF8)
                            : colors.onPrimaryContainer),
                    const SizedBox(width: 4),
                    Text(
                      'Cài đặt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFF8FAFC)
                            : colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  TURN & STATUS HUD BAR
// ───────────────────────────────────────────────────────────────────────────

class _CaroTurnBar extends StatelessWidget {
  const _CaroTurnBar({required this.vm});
  final CaroViewModel vm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final isXTurn = vm.turn == CaroSymbol.x;

    String statusText;
    if (vm.winner == CaroSymbol.x) {
      statusText = '🎉 Quân X Chiến Thắng!';
    } else if (vm.winner == CaroSymbol.o) {
      statusText =
          vm.mode == CaroMode.vsAi ? '🤖 Máy Thắng!' : '🎉 Quân O Chiến Thắng!';
    } else if (vm.isDraw) {
      statusText = '🤝 Ván Cờ Hòa!';
    } else if (vm.isAiThinking) {
      statusText = '🤖 Máy đang suy nghĩ...';
    } else {
      statusText =
          'Lượt đi: ${isXTurn ? "Quân X" : (vm.mode == CaroMode.vsAi ? "Máy (O)" : "Quân O")}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : colors.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Mode Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
              ),
              child: Text(
                vm.boardSize.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: vm.winner != CaroSymbol.none
                      ? const Color(0xFFF59E0B)
                      : (isDark ? Colors.white : colors.onSurface),
                ),
              ),
            ),
            if (vm.winner == CaroSymbol.none && !vm.isDraw)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isXTurn
                      ? const Color(0xFF0EA5E9).withValues(alpha: 0.2)
                      : const Color(0xFFF43F5E).withValues(alpha: 0.2),
                  border: Border.all(
                    color: isXTurn
                        ? const Color(0xFF0EA5E9)
                        : const Color(0xFFF43F5E),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    isXTurn ? 'X' : 'O',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isXTurn
                          ? const Color(0xFF0EA5E9)
                          : const Color(0xFFF43F5E),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  CARO SINGLE TILE (Eye-Friendly Tactile Tile)
// ───────────────────────────────────────────────────────────────────────────

class _CaroTile extends StatelessWidget {
  const _CaroTile({
    required this.symbol,
    required this.isWinning,
    required this.dimension,
    required this.isEven,
    required this.onTap,
  });

  final CaroSymbol symbol;
  final bool isWinning;
  final int dimension;
  final bool isEven;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Border border;
    List<BoxShadow>? shadows;

    if (isWinning) {
      bg = isDark ? const Color(0xFF854D0E) : const Color(0xFFFEF08A);
      border = Border.all(color: const Color(0xFFEAB308), width: 2.0);
      shadows = [
        const BoxShadow(color: Color(0xFFEAB308), blurRadius: 8),
      ];
    } else if (symbol != CaroSymbol.none) {
      // Played Tile
      bg = isDark ? const Color(0xFF1E293B) : Colors.white;
      border = Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        width: 1.0,
      );
    } else {
      // Unplayed Tile: Eye-friendly Muted Checkerboard Inset
      if (isDark) {
        bg = isEven ? const Color(0xFF0F172A) : const Color(0xFF090E17);
        border = Border.all(color: const Color(0xFF1E293B), width: 0.5);
      } else {
        bg = isEven ? const Color(0xFFF0F4F8) : const Color(0xFFE4E9F0);
        border = Border.all(color: const Color(0xFFD9E2EC), width: 0.5);
      }
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
            border: border,
            boxShadow: shadows,
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

    final fontSize = dim == 3 ? 38.0 : (dim == 8 ? 20.0 : 11.0);

    if (sym == CaroSymbol.x) {
      return Text(
        'X',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: isWinning
              ? const Color(0xFF0284C7)
              : const Color(0xFF0EA5E9), // Cyan Blue X
        ),
      );
    } else {
      return Text(
        'O',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: isWinning
              ? const Color(0xFFE11D48)
              : const Color(0xFFF43F5E), // Coral Rose O
        ),
      );
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  CONFIG SHEET
// ───────────────────────────────────────────────────────────────────────────

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
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
                color: isDark ? const Color(0xFF475569) : colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cấu hình Cờ Caro ⚙️',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Size Selection
          Text(
            'Kích thước bàn cờ:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF94A3B8) : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: CaroBoardSize.values.map((s) {
              final isSel = selectedSize == s;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildSelectableChip(
                    label: s.label,
                    isSelected: isSel,
                    onTap: () => setState(() => selectedSize = s),
                    isDark: isDark,
                    colors: colors,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Mode Selection
          Text(
            'Chế độ chơi:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF94A3B8) : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSelectableChip(
                  label: 'Đấu với Máy 🤖',
                  isSelected: selectedMode == CaroMode.vsAi,
                  onTap: () => setState(() => selectedMode = CaroMode.vsAi),
                  isDark: isDark,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSelectableChip(
                  label: '2 Người chơi 👥',
                  isSelected: selectedMode == CaroMode.pvp,
                  onTap: () => setState(() => selectedMode = CaroMode.pvp),
                  isDark: isDark,
                  colors: colors,
                ),
              ),
            ],
          ),

          if (selectedMode == CaroMode.vsAi) ...[
            const SizedBox(height: 14),
            Text(
              'Độ khó của Máy:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color:
                    isDark ? const Color(0xFF94A3B8) : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: CaroDifficulty.values.map((d) {
                final isSel = selectedDiff == d;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _buildSelectableChip(
                      label: d.label,
                      isSelected: isSel,
                      onTap: () => setState(() => selectedDiff = d),
                      isDark: isDark,
                      colors: colors,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                ),
              ),
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Áp dụng & Bắt đầu',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required ColorScheme colors,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0EA5E9)
                : (isDark
                    ? const Color(0xFF1E293B)
                    : colors.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF38BDF8)
                  : (isDark ? const Color(0xFF334155) : colors.outlineVariant),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFE2E8F0) : colors.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
