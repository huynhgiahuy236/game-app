import 'dart:math';
import 'package:flutter/material.dart';
import '../models/monopoly_models.dart';
import '../services/monopoly_repository.dart';
import '../viewmodels/monopoly_view_model.dart';

class MonopolyGameScreen extends StatefulWidget {
  const MonopolyGameScreen({super.key, required this.repository});
  final MonopolyRepository repository;

  @override
  State<MonopolyGameScreen> createState() => _MonopolyGameScreenState();
}

class _MonopolyGameScreenState extends State<MonopolyGameScreen> {
  late final MonopolyViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = MonopolyViewModel(widget.repository)..addListener(_refresh);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bắt đầu ván mới?'),
        content: const Text('Bàn Cờ Tỷ Phú hiện tại sẽ được thay thế.'),
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
    if (confirmed) vm.resetGame();
  }

  void _showConfigSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MonopolyConfigSheet(vm: vm),
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
                _MonopolyHeader(
                  onBack: () => Navigator.pop(context),
                  onConfig: _showConfigSheet,
                ),

                // ── Players Cash Dashboard ───────────────────────────
                _MonopolyPlayersDashboard(vm: vm),

                const SizedBox(height: 8),

                // ── Monopoly Square Loop Board ────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = min(constraints.maxWidth, constraints.maxHeight);
                        return Center(
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: Container(
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
                              child: Stack(
                                children: [
                                  // 28 Board Tiles along edges
                                  ..._buildBoardTiles(size),

                                  // Center Dashboard (Dice Roll + Log)
                                  Positioned(
                                    left: size * 0.21,
                                    top: size * 0.21,
                                    width: size * 0.58,
                                    height: size * 0.58,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: colors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: colors.outlineVariant),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: _MonopolyCenterControl(vm: vm),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Action Buttons Bar ───────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _newGame,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Chơi ván mới'),
                        ),
                      ),
                      if (vm.turnCompleted && !vm.currentPlayer.isAi) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: vm.endTurn,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Kết thúc lượt'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Active Property Purchase Modal
            if (vm.activeTileModal != null)
              _BuyPropertyModal(
                tile: vm.activeTileModal!,
                player: vm.currentPlayer,
                onBuy: () => vm.buyProperty(vm.currentPlayer, vm.activeTileModal!),
                onSkip: vm.closeModals,
              ),

            // Active Chance Card Modal
            if (vm.activeCardModal != null)
              _ChanceCardModal(
                card: vm.activeCardModal!,
                onDismiss: vm.closeModals,
              ),

            // Winner Celebration Overlay
            if (vm.winner != null)
              _MonopolyVictoryOverlay(
                winner: vm.winner!,
                onRestart: vm.resetGame,
                onExit: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the 28 board tiles positioned around the 4 edges of the square board
  List<Widget> _buildBoardTiles(double boardSizePx) {
    final list = <Widget>[];
    final tileSize = boardSizePx * 0.21;

    for (var i = 0; i < vm.board.length; i++) {
      final tile = vm.board[i];
      final playersOnTile = vm.players.where((p) => p.position == i && !p.bankrupt).toList();

      double left = 0;
      double top = 0;

      if (i <= 7) {
        // Bottom side (Right to Left: 0 to 7)
        left = boardSizePx - tileSize - (i * (boardSizePx - tileSize) / 7);
        top = boardSizePx - tileSize;
      } else if (i <= 14) {
        // Left side (Bottom to Top: 7 to 14)
        left = 0;
        top = boardSizePx - tileSize - ((i - 7) * (boardSizePx - tileSize) / 7);
      } else if (i <= 21) {
        // Top side (Left to Right: 14 to 21)
        left = ((i - 14) * (boardSizePx - tileSize) / 7);
        top = 0;
      } else {
        // Right side (Top to Bottom: 21 to 27)
        left = boardSizePx - tileSize;
        top = ((i - 21) * (boardSizePx - tileSize) / 7);
      }

      list.add(
        Positioned(
          left: left,
          top: top,
          width: tileSize,
          height: tileSize,
          child: _MonopolyTileItem(
            tile: tile,
            playersOnTile: playersOnTile,
          ),
        ),
      );
    }

    return list;
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _MonopolyHeader extends StatelessWidget {
  const _MonopolyHeader({required this.onBack, required this.onConfig});
  final VoidCallback onBack;
  final VoidCallback onConfig;

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
                    'Cờ Tỷ Phú',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Mua nhà đất & trở thành Tỷ phú',
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
              tooltip: 'Số người chơi',
              onPressed: onConfig,
              icon: const Icon(Icons.group_add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Players Cash Dashboard ───────────────────────────────────────────────────
class _MonopolyPlayersDashboard extends StatelessWidget {
  const _MonopolyPlayersDashboard({required this.vm});
  final MonopolyViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: vm.players.map((p) {
          final isTurn = vm.currentPlayer.id == p.id;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isTurn ? colors.primaryContainer : colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: isTurn
                      ? Border.all(color: p.color.color, width: 2.0)
                      : Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(p.color.icon, size: 14, color: p.color.color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isTurn ? colors.onPrimaryContainer : colors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.bankrupt ? '💥 Bán Sản' : '\$${p.cash}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: p.bankrupt ? colors.error : p.color.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Center Control (Dice Roll & Log) ─────────────────────────────────────────
class _MonopolyCenterControl extends StatelessWidget {
  const _MonopolyCenterControl({required this.vm});
  final MonopolyViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canRoll = !vm.isRolling && !vm.turnCompleted && !vm.currentPlayer.isAi && vm.winner == null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Live Game Log Feed
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            vm.gameLog,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Animated 2D/3D Dice Display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DiceWidget(value: vm.die1, isRolling: vm.isRolling),
            const SizedBox(width: 8),
            _DiceWidget(value: vm.die2, isRolling: vm.isRolling),
          ],
        ),

        const SizedBox(height: 12),

        // Roll Dice Button
        FilledButton.icon(
          onPressed: canRoll ? vm.rollDice : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(130, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.casino_rounded, size: 20),
          label: Text(
            vm.isRolling ? 'Đang gieo...' : 'Đổ Xúc Xắc',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// ── Dice Widget ─────────────────────────────────────────────────────────────
class _DiceWidget extends StatelessWidget {
  const _DiceWidget({required this.value, required this.isRolling});
  final int value;
  final bool isRolling;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedRotation(
      turns: isRolling ? 0.5 : 0.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Board Tile Item Widget ───────────────────────────────────────────────────
class _MonopolyTileItem extends StatelessWidget {
  const _MonopolyTileItem({
    required this.tile,
    required this.playersOnTile,
  });

  final MonopolyTile tile;
  final List<MonopolyPlayer> playersOnTile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Color Band for Property
          if (tile.groupColor != null)
            Container(
              height: 6,
              color: tile.groupColor,
            ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tile.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  if (tile.price > 0)
                    Text(
                      '\$${tile.price}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                  // Players Tokens on this tile
                  if (playersOnTile.isNotEmpty)
                    Wrap(
                      spacing: 2,
                      children: playersOnTile.map((p) {
                        return Icon(
                          p.color.icon,
                          size: 11,
                          color: p.color.color,
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Buy Property Modal ───────────────────────────────────────────────────────
class _BuyPropertyModal extends StatelessWidget {
  const _BuyPropertyModal({
    required this.tile,
    required this.player,
    required this.onBuy,
    required this.onSkip,
  });

  final MonopolyTile tile;
  final MonopolyPlayer player;
  final VoidCallback onBuy;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canAfford = player.cash >= tile.price;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tile.groupColor != null)
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: tile.groupColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Mua Nhà Đất',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tile.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatBadge(label: 'Giá mua', value: '\$${tile.price}'),
                      _StatBadge(label: 'Tiền thuê ban đầu', value: '\$${tile.baseRent}'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onSkip,
                          child: const Text('Bỏ qua'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: canAfford ? onBuy : null,
                          child: Text(canAfford ? 'Mua Đất' : 'Không đủ tiền'),
                        ),
                      ),
                    ],
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

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// ── Chance / Community Card Modal ───────────────────────────────────────────
class _ChanceCardModal extends StatelessWidget {
  const _ChanceCardModal({required this.card, required this.onDismiss});
  final MonopolyCard card;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    card.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onDismiss,
                    child: const Text('Nhận Thưởng'),
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

// ── Monopoly Victory Overlay ─────────────────────────────────────────────────
class _MonopolyVictoryOverlay extends StatelessWidget {
  const _MonopolyVictoryOverlay({
    required this.winner,
    required this.onRestart,
    required this.onExit,
  });

  final MonopolyPlayer winner;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.75),
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
                  const Text('👑', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text(
                    'TỶ PHÚ DUY NHẤT!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chúc mừng ${winner.name} đã đánh bại tất cả đối thủ và làm chủ bàn cờ!',
                    textAlign: TextAlign.center,
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

// ── Monopoly Player Count Config Sheet ───────────────────────────────────────
class _MonopolyConfigSheet extends StatelessWidget {
  const _MonopolyConfigSheet({required this.vm});
  final MonopolyViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số người chơi Cờ Tỷ Phú',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('2 Người (1vs1 với Máy AI)'),
            leading: const Icon(Icons.smart_toy_rounded),
            onTap: () {
              vm.resetGame(playerCount: 2, vsAi: true);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('3 Người (1 Bạn + 2 Máy AI)'),
            leading: const Icon(Icons.group_rounded),
            onTap: () {
              vm.resetGame(playerCount: 3, vsAi: true);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('4 Người (1 Bạn + 3 Máy AI)'),
            leading: const Icon(Icons.groups_rounded),
            onTap: () {
              vm.resetGame(playerCount: 4, vsAi: true);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('2 Người chơi (Chơi 2 người trên 1 máy)'),
            leading: const Icon(Icons.people_alt_rounded),
            onTap: () {
              vm.resetGame(playerCount: 2, vsAi: false);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
