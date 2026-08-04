import 'dart:async';
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

class _MonopolyGameScreenState extends State<MonopolyGameScreen>
    with TickerProviderStateMixin {
  late final MonopolyViewModel vm;
  final TransformationController _transformationController =
      TransformationController();

  // Double-back exit protection
  bool _isDoubleBackWaiting = false;
  Timer? _doubleBackTimer;

  // Non-blocking toast banner
  String? _toastMessage;
  Timer? _toastTimer;

  // Confetti / Particle animation
  late AnimationController _particleController;
  final List<_Particle> _particles = [];

  double _currentBoardSize = 400.0;

  @override
  void initState() {
    super.initState();
    vm = MonopolyViewModel(widget.repository)..addListener(_refresh);
    vm.onCameraFocusRequest = _focusOnTile;

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    // Initial camera focus on start tile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusOnTile(0, animate: false);
    });
  }

  void _refresh() {
    if (vm.winner != null && !_particleController.isAnimating) {
      _spawnVictoryParticles();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _doubleBackTimer?.cancel();
    _toastTimer?.cancel();
    _particleController.dispose();
    _transformationController.dispose();
    vm.removeListener(_refresh);
    vm.dispose();
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
    if (vm.activeTileModal != null || vm.activeCardModal != null) {
      vm.closeModals();
      return;
    }

    if (_isDoubleBackWaiting) {
      _doubleBackTimer?.cancel();
      Navigator.of(context).pop();
      return;
    }

    _isDoubleBackWaiting = true;
    _showToast('Nhấn lần nữa để rời ván chơi');
    _doubleBackTimer?.cancel();
    _doubleBackTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _isDoubleBackWaiting = false);
    });
  }

  void _spawnVictoryParticles() {
    _particles.clear();
    final random = Random();
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFD946EF),
    ];
    for (var i = 0; i < 60; i++) {
      _particles.add(
        _Particle(
          x: random.nextDouble(),
          y: random.nextDouble() * 0.4,
          vx: (random.nextDouble() - 0.5) * 0.3,
          vy: random.nextDouble() * 0.5 + 0.3,
          color: colors[random.nextInt(colors.length)],
          radius: random.nextDouble() * 4 + 3,
        ),
      );
    }
    _particleController.forward(from: 0.0);
  }

  void _focusOnTile(int tileIndex, {bool animate = true}) {
    if (!mounted) return;

    if (!animate) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    final pos = _getTileCenterOffset(tileIndex, _currentBoardSize);
    const scale = 1.25;
    final centerDx = _currentBoardSize / 2;
    final centerDy = _currentBoardSize / 2;

    final dx = (centerDx - pos.dx) * scale;
    final dy = (centerDy - pos.dy) * scale;

    final targetMatrix = Matrix4.identity()
      ..setTranslationRaw(dx, dy, 0.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);

    if (vm.animationIntensity != AnimationIntensity.reduced) {
      final animation = Matrix4Tween(
        begin: _transformationController.value,
        end: targetMatrix,
      ).animate(
        CurvedAnimation(
          parent: AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 350),
          )..forward(),
          curve: Curves.easeOutCubic,
        ),
      );
      animation.addListener(() {
        _transformationController.value = animation.value;
      });
    } else {
      _transformationController.value = targetMatrix;
    }
  }

  void _resetCameraFit() {
    final animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(
      CurvedAnimation(
        parent: AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
        )..forward(),
        curve: Curves.easeOutCubic,
      ),
    );
    animation.addListener(() {
      _transformationController.value = animation.value;
    });
  }

  Offset _getTileCenterOffset(int index, double boardSize) {
    final tileSize = boardSize * 0.18;
    if (index <= 7) {
      final left = boardSize - tileSize - (index * (boardSize - tileSize) / 7);
      return Offset(left + tileSize / 2, boardSize - tileSize / 2);
    } else if (index <= 14) {
      final top = boardSize - tileSize - ((index - 7) * (boardSize - tileSize) / 7);
      return Offset(tileSize / 2, top + tileSize / 2);
    } else if (index <= 21) {
      final left = ((index - 14) * (boardSize - tileSize) / 7);
      return Offset(left + tileSize / 2, tileSize / 2);
    } else {
      final top = ((index - 21) * (boardSize - tileSize) / 7);
      return Offset(boardSize - tileSize / 2, top + tileSize / 2);
    }
  }

  Future<void> _newGame() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _NewGameConfirmationSheet(),
    );
    if (confirmed == true && mounted) {
      vm.resetGame();
      _focusOnTile(0);
    }
  }

  void _showConfigSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MonopolyConfigSheet(vm: vm),
    );
  }

  void _showPlayerAssetSheet(MonopolyPlayer player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlayerAssetSheet(player: player, vm: vm),
    );
  }

  void _showPropertyDetailSheet(MonopolyTile tile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PropertyDetailSheet(tile: tile, vm: vm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C18) : colors.surface,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Top Header ─────────────────────────────────────
                  _MonopolyHeader(
                    onBack: _handleBackPress,
                    onConfig: _showConfigSheet,
                    currentIntensity: vm.animationIntensity,
                    onIntensityChanged: vm.setAnimationIntensity,
                  ),

                  // ── Players Dashboard ──────────────────────────────
                  _MonopolyPlayersDashboard(
                    vm: vm,
                    onPlayerTap: _showPlayerAssetSheet,
                  ),

                  const SizedBox(height: 6),

                  // ── Pannable / Zoomable Board ───────────────────────
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final boardSize =
                            min(c.maxWidth - 12, c.maxHeight - 12)
                                .clamp(300.0, 760.0);
                        _currentBoardSize = boardSize;

                        return Stack(
                          children: [
                            InteractiveViewer(
                              alignment: Alignment.center,
                              transformationController: _transformationController,
                              minScale: 1.0,
                              maxScale: 2.8,
                              boundaryMargin: const EdgeInsets.all(40.0),
                              child: Center(
                                child: SizedBox(
                                  width: boardSize,
                                  height: boardSize,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : colors.outlineVariant,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDark
                                              ? const Color(0xFF7C3AED)
                                                  .withValues(alpha: 0.15)
                                              : Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 24,
                                          spreadRadius: -2,
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // 28 Board Tiles along edges
                                        ..._buildBoardTiles(boardSize),

                                        // Center Stage Area
                                        Positioned(
                                          left: boardSize * 0.18,
                                          top: boardSize * 0.18,
                                          width: boardSize * 0.64,
                                          height: boardSize * 0.64,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1E293B)
                                                  : colors.surfaceContainerLow,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF334155)
                                                    : colors.outlineVariant,
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.12),
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(6),
                                            child: ClipRect(
                                              child: _MonopolyCenterStage(
                                                vm: vm,
                                                onRollTap: vm.rollDice,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                        // Camera Control Overlay (Fit & Focus)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FloatingActionButton.small(
                                heroTag: 'focus_cam',
                                onPressed: () =>
                                    _focusOnTile(vm.currentPlayer.position),
                                backgroundColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : colors.surfaceContainerHigh,
                                child: Icon(Icons.my_location_rounded,
                                    size: 18,
                                    color: isDark ? Colors.white : colors.onSurface),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                heroTag: 'fit_cam',
                                onPressed: _resetCameraFit,
                                backgroundColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : colors.surfaceContainerHigh,
                                child: Icon(Icons.zoom_out_map_rounded,
                                    size: 18,
                                    color: isDark ? Colors.white : colors.onSurface),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

                  const SizedBox(height: 6),

                  // ── Bottom Action Bar ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _newGame,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              side: BorderSide(
                                color: isDark
                                    ? const Color(0xFF475569)
                                    : colors.outlineVariant,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Ván mới',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        if (vm.turnCompleted && !vm.currentPlayer.isAi) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                                ),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: vm.endTurn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  minimumSize: const Size(0, 46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white),
                                label: const Text('Kết thúc lượt',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // ── Non-blocking Toast Banner ────────────────────────
              if (_toastMessage != null)
                Positioned(
                  top: 64,
                  left: 20,
                  right: 20,
                  child: _ToastBanner(message: _toastMessage!),
                ),

              // ── Floating Money Animations ────────────────────────
              for (final fEvent in vm.floatingMoneyEvents)
                Positioned(
                  top: 120,
                  left: MediaQuery.of(context).size.width * 0.35,
                  child: _FloatingMoneyChip(event: fEvent),
                ),

              // ── Active Modals ─────────────────────────────────────
              if (vm.activeTileModal != null)
                _BuyPropertyModal(
                  tile: vm.activeTileModal!,
                  player: vm.currentPlayer,
                  onBuy: () =>
                      vm.buyProperty(vm.currentPlayer, vm.activeTileModal!),
                  onSkip: vm.closeModals,
                ),

              if (vm.activeCardModal != null)
                _ChanceCardModal(
                  card: vm.activeCardModal!,
                  onDismiss: vm.closeModals,
                ),

              // ── Victory Celebration Overlay ───────────────────────
              if (vm.winner != null)
                _MonopolyVictoryOverlay(
                  winner: vm.winner!,
                  onRestart: vm.resetGame,
                  onExit: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the 28 board tiles positioned around the 4 edges of the square board
  List<Widget> _buildBoardTiles(double boardSizePx) {
    final list = <Widget>[];
    final tileSize = boardSizePx * 0.18;

    for (var i = 0; i < vm.board.length; i++) {
      final tile = vm.board[i];
      final playersOnTile =
          vm.players.where((p) => p.position == i && !p.bankrupt).toList();

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
            onTap: () => _showPropertyDetailSheet(tile),
          ),
        ),
      );
    }

    return list;
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  HEADER
// ───────────────────────────────────────────────────────────────────────────

class _MonopolyHeader extends StatelessWidget {
  const _MonopolyHeader({
    required this.onBack,
    required this.onConfig,
    required this.currentIntensity,
    required this.onIntensityChanged,
  });

  final VoidCallback onBack;
  final VoidCallback onConfig;
  final AnimationIntensity currentIntensity;
  final ValueChanged<AnimationIntensity> onIntensityChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🏰', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Cờ Tỷ Phú',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : colors.onSurface,
                    ),
                  ),
                  Text(
                    'Trở thành Tỷ Phú độc tôn',
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
            PopupMenuButton<AnimationIntensity>(
              initialValue: currentIntensity,
              tooltip: 'Tốc độ hiệu ứng',
              onSelected: onIntensityChanged,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              itemBuilder: (context) => [
                for (final intensity in AnimationIntensity.values)
                  PopupMenuItem(
                    value: intensity,
                    child: Row(
                      children: [
                        Text(intensity.label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : colors.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentIntensity.label.split(' ').first,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFF8FAFC)
                            : colors.onPrimaryContainer,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Số người chơi',
              onPressed: onConfig,
              icon: const Icon(Icons.group_add_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  PLAYERS DASHBOARD BAR
// ───────────────────────────────────────────────────────────────────────────

class _MonopolyPlayersDashboard extends StatelessWidget {
  const _MonopolyPlayersDashboard({
    required this.vm,
    required this.onPlayerTap,
  });

  final MonopolyViewModel vm;
  final ValueChanged<MonopolyPlayer> onPlayerTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: vm.players.map((p) {
          final isTurn = vm.currentPlayer.id == p.id;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => onPlayerTap(p),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isTurn
                        ? (isDark
                            ? p.color.color.withValues(alpha: 0.2)
                            : p.color.color.withValues(alpha: 0.12))
                        : (isDark
                            ? const Color(0xFF1E293B)
                            : colors.surfaceContainerLow),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isTurn
                          ? p.color.color
                          : (isDark
                              ? const Color(0xFF334155)
                              : colors.outlineVariant),
                      width: isTurn ? 2.0 : 1.0,
                    ),
                    boxShadow: isTurn
                        ? [
                            BoxShadow(
                              color: p.color.color.withValues(alpha: 0.3),
                              blurRadius: 8,
                            )
                          ]
                        : null,
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
                                color: isDark ? Colors.white : colors.onSurface,
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
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: p.bankrupt
                              ? const Color(0xFFEF4444)
                              : p.color.color,
                        ),
                      ),
                      if (p.inJail)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '🔒 Nhà Tù',
                            style: TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  CENTER STAGE AREA
// ───────────────────────────────────────────────────────────────────────────

class _MonopolyCenterStage extends StatelessWidget {
  const _MonopolyCenterStage({
    required this.vm,
    required this.onRollTap,
  });

  final MonopolyViewModel vm;
  final VoidCallback onRollTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final canRoll = !vm.isRolling &&
        !vm.isMoving &&
        !vm.turnCompleted &&
        !vm.currentPlayer.isAi &&
        vm.winner == null;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        // Current Turn Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: vm.currentPlayer.color.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: vm.currentPlayer.color.color, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(vm.currentPlayer.color.icon,
                  size: 14, color: vm.currentPlayer.color.color),
              const SizedBox(width: 6),
              Text(
                'Lượt: ${vm.currentPlayer.name}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Live Log Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          constraints: const BoxConstraints(minHeight: 38),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A)
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              vm.gameLog,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFE2E8F0) : colors.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3D Tumbling Dice Display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ThreeDimensionalDiceWidget(value: vm.die1, isRolling: vm.isRolling),
            const SizedBox(width: 14),
            _ThreeDimensionalDiceWidget(value: vm.die2, isRolling: vm.isRolling),
          ],
        ),

        const SizedBox(height: 12),

        // Roll Dice Button or Jail Exit Option
        if (vm.currentPlayer.inJail && !vm.turnCompleted && !vm.currentPlayer.isAi)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: vm.currentPlayer.cash >= 50 ? vm.payJailFineToExit : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.attach_money_rounded, size: 16),
                label: const Text('Nộp \$50 Ra Tù',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: canRoll ? onRollTap : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.casino_rounded, size: 16),
                label: const Text('Thử Gieo Đôi',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: canRoll
                  ? const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF0284C7)],
                    )
                  : null,
            ),
            child: ElevatedButton.icon(
              onPressed: canRoll ? onRollTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canRoll ? Colors.transparent : null,
                shadowColor: Colors.transparent,
                minimumSize: const Size(140, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.casino_rounded,
                  size: 20, color: Colors.white),
              label: Text(
                vm.isRolling
                    ? 'Đang gieo...'
                    : (vm.isMoving ? 'Đang đi...' : 'Đổ Xúc Xắc'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ),
          ),
      ],
    ),
  );
}
}

// ───────────────────────────────────────────────────────────────────────────
//  3D TUMBLING DICE WIDGET
// ───────────────────────────────────────────────────────────────────────────

class _ThreeDimensionalDiceWidget extends StatelessWidget {
  const _ThreeDimensionalDiceWidget({required this.value, required this.isRolling});
  final int value;
  final bool isRolling;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedRotation(
      turns: isRolling ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 140),
      child: AnimatedScale(
        scale: isRolling ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: _buildDicePips(value),
          ),
        ),
      ),
    );
  }

  Widget _buildDicePips(int num) {
    final dotColor = num == 1 ? const Color(0xFFEF4444) : const Color(0xFF0F172A);
    const dotSize = 7.0;

    Widget dot() => Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        );

    switch (num) {
      case 1:
        return Center(
            child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                    color: Color(0xFFEF4444), shape: BoxShape.circle)));
      case 2:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(alignment: Alignment.topRight, child: dot()),
              Align(alignment: Alignment.bottomLeft, child: dot()),
            ],
          ),
        );
      case 3:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(alignment: Alignment.topRight, child: dot()),
              Center(child: dot()),
              Align(alignment: Alignment.bottomLeft, child: dot()),
            ],
          ),
        );
      case 4:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [dot(), dot()]),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [dot(), dot()]),
            ],
          ),
        );
      case 5:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [dot(), dot()]),
              Center(child: dot()),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [dot(), dot()]),
            ],
          ),
        );
      case 6:
      default:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [dot(), dot(), dot()]),
              Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [dot(), dot(), dot()]),
            ],
          ),
        );
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  BOARD TILE ITEM WIDGET
// ───────────────────────────────────────────────────────────────────────────

class _MonopolyTileItem extends StatelessWidget {
  const _MonopolyTileItem({
    required this.tile,
    required this.playersOnTile,
    required this.onTap,
  });

  final MonopolyTile tile;
  final List<MonopolyPlayer> playersOnTile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border.all(
            color: isDark
                ? const Color(0xFF334155)
                : colors.outlineVariant.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            // Color Band for Property
            if (tile.groupColor != null)
              Container(
                height: 14,
                color: tile.groupColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // House / Hotel Markers
                    if (tile.houses > 0)
                      Text(
                        tile.houses == 5 ? '🏨' : '🟢' * tile.houses,
                        style: const TextStyle(fontSize: 8),
                      ),
                  ],
                ),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tile.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : colors.onSurface,
                        ),
                      ),
                      if (tile.price > 0)
                        Text(
                          '\$${tile.price}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? const Color(0xFFFBBF24)
                                : colors.onSurfaceVariant,
                          ),
                        ),

                      // Owner Indicator Badge
                      if (tile.ownerId != null)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ĐÃ SỞ HỮU',
                            style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                        ),

                      // Player Tokens on this tile
                      if (playersOnTile.isNotEmpty)
                        Wrap(
                          spacing: 2,
                          children: playersOnTile.map((p) {
                            return Icon(
                              p.color.icon,
                              size: 14,
                              color: p.color.color,
                            );
                          }).toList(),
                        ),
                    ],
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
//  BUY PROPERTY MODAL
// ───────────────────────────────────────────────────────────────────────────

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final canAfford = player.cash >= tile.price;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF7C3AED)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tile.groupColor != null)
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: tile.groupColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'CƠ HỘI MUA BẤT ĐỘNG SẢN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : colors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tile.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : colors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatBadge(label: 'Giá mua', value: '\$${tile.price}'),
                    _StatBadge(
                        label: 'Thuê ban đầu', value: '\$${tile.baseRent}'),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSkip,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Bỏ qua'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: canAfford
                              ? const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                                )
                              : null,
                        ),
                        child: ElevatedButton(
                          onPressed: canAfford ? onBuy : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                canAfford ? Colors.transparent : null,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            canAfford ? 'Mua Ngay' : 'Không đủ tiền',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : colors.onSurfaceVariant)),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFFFBBF24) : colors.onSurface)),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  CHANCE / COMMUNITY CARD MODAL
// ───────────────────────────────────────────────────────────────────────────

class _ChanceCardModal extends StatelessWidget {
  const _ChanceCardModal({required this.card, required this.onDismiss});
  final MonopolyCard card;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              color: isDark ? const Color(0xFF1E293B) : colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: card.isChance
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF0284C7)),
              boxShadow: [
                BoxShadow(
                  color: (card.isChance
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF0284C7))
                      .withValues(alpha: 0.35),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(card.isChance ? '🎁 CƠ HỘI' : '🏛️ KHÍ VẬN',
                    style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  card.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  card.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Nhận Thưởng',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
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
//  PROPERTY DETAIL BOTTOM SHEET
// ───────────────────────────────────────────────────────────────────────────

class _PropertyDetailSheet extends StatelessWidget {
  const _PropertyDetailSheet({required this.tile, required this.vm});
  final MonopolyTile tile;
  final MonopolyViewModel vm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final owner = tile.ownerId != null
        ? vm.players.firstWhere((p) => p.id == tile.ownerId)
        : null;
    final canBuild = owner?.id == vm.currentPlayer.id &&
        tile.type == TileType.property &&
        tile.houses < 5 &&
        vm.currentPlayer.cash >= tile.houseCost;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
          const SizedBox(height: 14),
          if (tile.groupColor != null)
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: tile.groupColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            tile.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            owner != null
                ? 'Sở hữu bởi: ${owner.name}'
                : 'Chưa có ai sở hữu (Giá: \$${tile.price})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: owner != null ? owner.color.color : colors.primary,
            ),
          ),
          const SizedBox(height: 14),

          if (tile.type == TileType.property) ...[
            Text('Bảng Giá Tiền Thuê:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : colors.onSurfaceVariant)),
            const SizedBox(height: 6),
            _RentRow(label: 'Tiền thuê đất gốc', value: '\$${tile.baseRent}'),
            _RentRow(label: 'Với 1 Nhà 🟢', value: '\$${tile.baseRent * 4}'),
            _RentRow(label: 'Với 2 Nhà 🟢🟢', value: '\$${tile.baseRent * 6}'),
            _RentRow(
                label: 'Với 3 Nhà 🟢🟢🟢', value: '\$${tile.baseRent * 8}'),
            _RentRow(
                label: 'Với 4 Nhà 🟢🟢🟢🟢', value: '\$${tile.baseRent * 10}'),
            _RentRow(label: 'Với 1 Khách Sạn 🏨', value: '\$${tile.baseRent * 12}'),
            const SizedBox(height: 16),
            if (canBuild)
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      vm.buildHouse(vm.currentPlayer, tile);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: const Icon(Icons.foundation_rounded,
                        color: Colors.white),
                    label: Text(
                      'Xây ${tile.houses == 4 ? "Khách Sạn 🏨" : "Nhà 🏠"} (\$${tile.houseCost})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RentRow extends StatelessWidget {
  const _RentRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF475569))),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFFFBBF24) : Colors.black)),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  PLAYER ASSET BOTTOM SHEET
// ───────────────────────────────────────────────────────────────────────────

class _PlayerAssetSheet extends StatelessWidget {
  const _PlayerAssetSheet({required this.player, required this.vm});
  final MonopolyPlayer player;
  final MonopolyViewModel vm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final ownedTiles =
        vm.board.where((t) => t.ownerId == player.id).toList();

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(player.color.icon, size: 24, color: player.color.color),
              const SizedBox(width: 8),
              Text(
                'Tài Sản: ${player.name}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tiền mặt: \$${player.cash} · Tổng BĐS: ${ownedTiles.length}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (ownedTiles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('Chưa sở hữu bất động sản nào.',
                      style: TextStyle(color: Colors.grey))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ownedTiles.length,
                itemBuilder: (context, i) {
                  final t = ownedTiles[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (t.groupColor != null)
                          Container(
                            width: 10,
                            height: 24,
                            decoration: BoxDecoration(
                              color: t.groupColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark ? Colors.white : colors.onSurface)),
                        ),
                        Text('Thuê: \$${t.currentRent}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981))),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  NEW GAME & CONFIG SHEETS
// ───────────────────────────────────────────────────────────────────────────

class _NewGameConfirmationSheet extends StatelessWidget {
  const _NewGameConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF475569) : colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.help_outline_rounded,
              size: 40, color: Color(0xFF7C3AED)),
          const SizedBox(height: 12),
          Text(
            'Bắt đầu ván Cờ Tỷ Phú mới?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bàn cờ và tài sản hiện tại sẽ bị xóa.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                ),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Bắt đầu ván mới',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF475569)
                      : colors.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Tiếp tục chơi',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFE2E8F0)
                      : colors.onSurfaceVariant,
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

class _MonopolyConfigSheet extends StatelessWidget {
  const _MonopolyConfigSheet({required this.vm});
  final MonopolyViewModel vm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
            'Số người chơi Cờ Tỷ Phú 🎲',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('2 Người (1vs1 với Máy AI)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            leading: const Icon(Icons.smart_toy_rounded, color: Color(0xFF7C3AED)),
            onTap: () {
              vm.resetGame(playerCount: 2, vsAi: true);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('3 Người (1 Bạn + 2 Máy AI)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            leading: const Icon(Icons.group_rounded, color: Color(0xFF0284C7)),
            onTap: () {
              vm.resetGame(playerCount: 3, vsAi: true);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('4 Người (1 Bạn + 3 Máy AI)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            leading: const Icon(Icons.groups_rounded, color: Color(0xFFF59E0B)),
            onTap: () {
              vm.resetGame(playerCount: 4, vsAi: true);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('2 Người chơi (Chơi 2 người trên 1 máy)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            leading: const Icon(Icons.people_alt_rounded, color: Color(0xFF10B981)),
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

// ───────────────────────────────────────────────────────────────────────────
//  VICTORY OVERLAY
// ───────────────────────────────────────────────────────────────────────────

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF59E0B), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👑', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                const Text(
                  'TỶ PHÚ DUY NHẤT!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF59E0B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Chúc mừng ${winner.name} đã làm chủ toàn bộ bất động sản!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: onRestart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                      label: const Text('Bắt đầu ván mới',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onExit,
                  child: Text('Về sảnh trò chơi',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : colors.onSurfaceVariant)),
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
//  FLOATING MONEY CHIP
// ───────────────────────────────────────────────────────────────────────────

class _FloatingMoneyChip extends StatefulWidget {
  const _FloatingMoneyChip({required this.event});
  final FloatingMoneyEvent event;

  @override
  State<_FloatingMoneyChip> createState() => _FloatingMoneyChipState();
}

class _FloatingMoneyChipState extends State<_FloatingMoneyChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.5),
    ).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.event.isIncome
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final prefix = widget.event.isIncome ? '+' : '-';

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            '$prefix\$${widget.event.amount}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastBanner extends StatelessWidget {
  const _ToastBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7C3AED)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFC084FC), size: 18),
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

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.radius,
  });
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double radius;
}
