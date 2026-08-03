import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_2048_model.dart';
import '../services/game_2048_repository.dart';
import '../viewmodels/game_2048_view_model.dart';

class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key, required this.repository});
  final Game2048Repository repository;

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen> {
  Game2048ViewModel? viewModel;
  final focusNode = FocusNode();
  Offset dragDelta = Offset.zero;

  // Double-back exit protection
  bool _isDoubleBackWaiting = false;
  Timer? _doubleBackTimer;

  // Non-blocking toast state
  String? _toastMessage;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await Game2048ViewModel.create(widget.repository);
    loaded.addListener(_refresh);
    if (mounted) setState(() => viewModel = loaded);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _doubleBackTimer?.cancel();
    _toastTimer?.cancel();
    viewModel?.removeListener(_refresh);
    viewModel?.dispose();
    focusNode.dispose();
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

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || viewModel == null) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => MoveDirection.up,
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => MoveDirection.down,
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => MoveDirection.left,
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD => MoveDirection.right,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    final moved = viewModel!.move(direction);
    if (moved) HapticFeedback.lightImpact();
    return KeyEventResult.handled;
  }

  void _endDrag(DragEndDetails _) {
    if (dragDelta.distance < 20 || viewModel == null) return;
    final horizontal = dragDelta.dx.abs() > dragDelta.dy.abs();
    final dir = horizontal
        ? (dragDelta.dx > 0 ? MoveDirection.right : MoveDirection.left)
        : (dragDelta.dy > 0 ? MoveDirection.down : MoveDirection.up);
    final moved = viewModel!.move(dir);
    if (moved) HapticFeedback.lightImpact();
    dragDelta = Offset.zero;
  }

  Future<void> _handleNewGameRequest() async {
    final vm = viewModel;
    if (vm == null) return;

    if (vm.game.moves == 0) {
      await vm.newGame();
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _NewGameConfirmationSheet(),
    );

    if (confirmed == true && mounted) {
      await vm.newGame();
    }
  }

  Future<void> _handleSizeChangeRequest() async {
    final vm = viewModel;
    if (vm == null) return;

    final selectedSize = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SizeSelectionSheet(currentSize: vm.game.size),
    );

    if (selectedSize != null && selectedSize != vm.game.size && mounted) {
      if (vm.game.moves > 0) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Đổi sang bàn ${selectedSize}x$selectedSize?'),
            content: const Text('Tiến trình ván chơi hiện tại sẽ bị thay thế.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Đồng ý'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }
      await vm.newGame(size: selectedSize);
    }
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackPress();
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
                    // ── Header ──────────────────────────────────────────────
                    Game2048Header(
                      onBack: _handleBackPress,
                      currentSize: vm.game.size,
                      onSizeTap: _handleSizeChangeRequest,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final maxBoardW = c.maxWidth - 24;
                          final maxBoardH = c.maxHeight - 180;
                          final boardSize = (maxBoardW < maxBoardH ? maxBoardW : maxBoardH)
                              .clamp(180.0, 480.0);

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 500),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ── Score & Best Score Cards ─────────────────────
                                    SizedBox(
                                      width: boardSize,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Expanded(
                                            child: _AnimatedScorePill(
                                              label: 'ĐIỂM',
                                              value: vm.game.score,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _AnimatedScorePill(
                                              label: 'KỶ LỤC',
                                              value: vm.game.bestScore,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // ── Board 2048 ─────────────────────────────────
                                    SizedBox(
                                      width: boardSize,
                                      height: boardSize,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanStart: (_) => dragDelta = Offset.zero,
                                        onPanUpdate: (details) => dragDelta += details.delta,
                                        onPanEnd: _endDrag,
                                        child: ShakeWidget(
                                          shake: vm.isInvalidMove,
                                          child: Board2048(
                                            boardSize: boardSize,
                                            gridSize: vm.game.size,
                                            tiles: vm.tiles,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // ── Action Buttons (Undo & New Game) ────────────
                                    SizedBox(
                                      width: boardSize,
                                      child: Game2048ActionBar(
                                        canUndo: vm.canUndo,
                                        onUndo: vm.undo,
                                        onNew: _handleNewGameRequest,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // ── Short Gameplay Hint ────────────────────────
                                    Text(
                                      'Vuốt trên bàn (${vm.game.size}x${vm.game.size}) hoặc dùng phím mũi tên / WASD.\n'
                                      'Hai ô cùng số sẽ hợp nhất một lần trong mỗi lượt.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12,
                                        height: 1.4,
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
                  ],
                ),

                // ── Non-blocking Toast Banner ──────────────────────────────────
                if (_toastMessage != null)
                  Positioned(
                    top: 60,
                    left: 20,
                    right: 20,
                    child: _ToastBanner(message: _toastMessage!),
                  ),

                // ── Result Overlays (Win / Game Over) ─────────────────────────
                if (vm.game.won && !vm.game.keepPlaying)
                  _ResultOverlay(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Bạn đã đạt 2048!',
                    message: 'Điểm hiện tại: ${vm.game.score}. Tiếp tục chinh phục kỷ lục mới?',
                    primaryLabel: 'Tiếp tục chơi',
                    secondaryLabel: 'Ván mới',
                    onPrimary: vm.continueAfterWin,
                    onSecondary: _handleNewGameRequest,
                  ),

                if (vm.game.gameOver)
                  _GameOverOverlay(
                    score: vm.game.score,
                    bestScore: vm.game.bestScore,
                    size: vm.game.size,
                    canUndo: vm.canUndo,
                    onNewGame: () => vm.newGame(),
                    onUndo: vm.undo,
                    onBack: _handleBackPress,
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
//  HEADER
// ───────────────────────────────────────────────────────────────────────────

class Game2048Header extends StatelessWidget {
  const Game2048Header({
    super.key,
    required this.onBack,
    required this.currentSize,
    required this.onSizeTap,
  });
  final VoidCallback onBack;
  final int currentSize;
  final VoidCallback onSizeTap;

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
                    '2048',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Ghép số. Giữ nhịp. Tiến xa.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onSizeTap,
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
                    Icon(Icons.grid_on_rounded, size: 16, color: colors.onPrimaryContainer),
                    const SizedBox(width: 4),
                    Text(
                      '${currentSize}x$currentSize',
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
          ],
        ),
      ),
    );
  }
}

// ── Score Pill ─────────────────────────────────────────────────────────────
class _AnimatedScorePill extends StatefulWidget {
  const _AnimatedScorePill({
    required this.label,
    required this.value,
  });
  final String label;
  final int value;

  @override
  State<_AnimatedScorePill> createState() => _AnimatedScorePillState();
}

class _AnimatedScorePillState extends State<_AnimatedScorePill>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _scale;
  int _lastValue = 0;
  int _gained = 0;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.value;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
      ),
    );
    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.2),
    ).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_anim);
  }

  @override
  void didUpdateWidget(covariant _AnimatedScorePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value > _lastValue) {
      _gained = widget.value - _lastValue;
      _anim.forward(from: 0.0);
    }
    _lastValue = widget.value;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: _scale,
          child: Container(
            constraints: const BoxConstraints(minWidth: 88),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${widget.value}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_anim.isAnimating && _gained > 0)
          Positioned(
            top: -10,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '+$_gained',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Action Bar — Undo & New Game
// ───────────────────────────────────────────────────────────────────────────

class Game2048ActionBar extends StatelessWidget {
  const Game2048ActionBar({
    super.key,
    required this.canUndo,
    required this.onUndo,
    required this.onNew,
  });
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Hoàn tác'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Ván mới'),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Board 2048 — Bảng chơi chính linh hoạt theo kích thước 4x4, 5x5, 6x6
// ───────────────────────────────────────────────────────────────────────────

class Board2048 extends StatelessWidget {
  const Board2048({
    super.key,
    required this.boardSize,
    required this.gridSize,
    required this.tiles,
  });
  final double boardSize;
  final int gridSize;
  final List<TileModel> tiles;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Bàn chơi 2048, $gridSize hàng $gridSize cột',
      child: Container(
        width: boardSize,
        height: boardSize,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.outline.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gap = gridSize >= 6 ? 6.0 : (gridSize == 5 ? 8.0 : 10.0);
            final cellSize = (constraints.maxWidth - (gap * (gridSize - 1))) / gridSize;

            return Stack(
              children: [
                // Recessed Empty Cells
                for (var r = 0; r < gridSize; r++)
                  for (var c = 0; c < gridSize; c++)
                    Positioned(
                      left: c * (cellSize + gap),
                      top: r * (cellSize + gap),
                      width: cellSize,
                      height: cellSize,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(gridSize >= 6 ? 10 : 14),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                      ),
                    ),

                // Active Animated Tiles with 3D Depth
                for (final tile in tiles)
                  _AnimatedTileItem(
                    key: ValueKey('tile_${tile.id}'),
                    tile: tile,
                    gridSize: gridSize,
                    cellSize: cellSize,
                    gap: gap,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedTileItem extends StatefulWidget {
  const _AnimatedTileItem({
    super.key,
    required this.tile,
    required this.gridSize,
    required this.cellSize,
    required this.gap,
  });
  final TileModel tile;
  final int gridSize;
  final double cellSize;
  final double gap;

  @override
  State<_AnimatedTileItem> createState() => _AnimatedTileItemState();
}

class _AnimatedTileItemState extends State<_AnimatedTileItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    if (widget.tile.mergedFrom != null) {
      _scaleAnim = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.16).chain(CurveTween(curve: Curves.easeOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.16, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
          weight: 50,
        ),
      ]).animate(_scaleController);
      _scaleController.forward();
    } else if (widget.tile.isNew) {
      _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
      );
      _scaleController.forward();
    } else {
      _scaleAnim = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = _tileStyle(widget.tile.value, colors);

    final left = widget.tile.col * (widget.cellSize + widget.gap);
    final top = widget.tile.row * (widget.cellSize + widget.gap);

    final baseFontSize = widget.gridSize >= 6
        ? (widget.tile.value >= 1000 ? 14.0 : 18.0)
        : (widget.gridSize == 5
            ? (widget.tile.value >= 1000 ? 17.0 : 22.0)
            : (widget.tile.value >= 10000
                ? 16.0
                : (widget.tile.value >= 1024 ? 20.0 : 25.0)));

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: widget.cellSize,
      height: widget.cellSize,
      child: AnimatedScale(
        scale: _scaleAnim.value,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(widget.gridSize >= 6 ? 10 : 14),
              border: Border.all(
                color: style.shadowColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: style.shadowColor.withValues(alpha: 0.6),
                  blurRadius: 0,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
                if (style.glowColor != null)
                  BoxShadow(
                    color: style.glowColor!,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${widget.tile.value}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: style.text,
                      fontSize: baseFontSize,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Tile Styling Palette (Ô nổi 3D Rực rỡ & Đầy đặn)
// ───────────────────────────────────────────────────────────────────────────

class _TileStyle {
  const _TileStyle({
    required this.background,
    required this.shadowColor,
    required this.text,
    this.glowColor,
  });
  final Color background;
  final Color shadowColor;
  final Color text;
  final Color? glowColor;
}

_TileStyle _tileStyle(int value, ColorScheme colors) {
  switch (value) {
    case 2:
      return const _TileStyle(
        background: Color(0xFF0D9488), // Soft Teal
        shadowColor: Color(0xFF0F766E),
        text: Colors.white,
      );
    case 4:
      return const _TileStyle(
        background: Color(0xFF0284C7), // Cyan Blue
        shadowColor: Color(0xFF0369A1),
        text: Colors.white,
      );
    case 8:
      return const _TileStyle(
        background: Color(0xFFF59E0B), // Warm Amber
        shadowColor: Color(0xFFD97706),
        text: Colors.white,
      );
    case 16:
      return const _TileStyle(
        background: Color(0xFFEA580C), // Vibrant Orange
        shadowColor: Color(0xFFC2410C),
        text: Colors.white,
      );
    case 32:
      return const _TileStyle(
        background: Color(0xFFE11D48), // Coral Rose
        shadowColor: Color(0xFFBE123C),
        text: Colors.white,
      );
    case 64:
      return const _TileStyle(
        background: Color(0xFF9F1239), // Red Pink
        shadowColor: Color(0xFF881337),
        text: Colors.white,
      );
    case 128:
      return const _TileStyle(
        background: Color(0xFF8B5CF6), // Purple
        shadowColor: Color(0xFF7C3AED),
        text: Colors.white,
        glowColor: Color(0x668B5CF6),
      );
    case 256:
      return const _TileStyle(
        background: Color(0xFF7C3AED), // Deep Purple
        shadowColor: Color(0xFF6D28D9),
        text: Colors.white,
        glowColor: Color(0x807C3AED),
      );
    case 512:
      return const _TileStyle(
        background: Color(0xFF6D28D9), // Dark Violet
        shadowColor: Color(0xFF5B21B6),
        text: Colors.white,
        glowColor: Color(0x996D28D9),
      );
    case 1024:
      return const _TileStyle(
        background: Color(0xFFD946EF), // Bright Magenta Accent
        shadowColor: Color(0xFFC026D3),
        text: Colors.white,
        glowColor: Color(0xB3D946EF),
      );
    case 2048:
      return const _TileStyle(
        background: Color(0xFFEAB308), // Special Gold
        shadowColor: Color(0xFFCA8A04),
        text: Color(0xFF1E1700),
        glowColor: Color(0xCCEAB308),
      );
    default:
      return const _TileStyle(
        background: Color(0xFF4C1D95), // Deep Cyber Violet
        shadowColor: Color(0xFF3B0764),
        text: Colors.white,
        glowColor: Color(0x804C1D95),
      );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Shake Widget — Rung nhẹ bàn chơi khi vuốt không hợp lệ
// ───────────────────────────────────────────────────────────────────────────

class ShakeWidget extends StatefulWidget {
  const ShakeWidget({
    super.key,
    required this.child,
    required this.shake,
    this.deltaX = 6.0,
    this.duration = const Duration(milliseconds: 250),
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
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
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
//  Non-blocking Toast Banner
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

// ───────────────────────────────────────────────────────────────────────────
//  Size Selection Bottom Sheet
// ───────────────────────────────────────────────────────────────────────────

class _SizeSelectionSheet extends StatelessWidget {
  const _SizeSelectionSheet({required this.currentSize});
  final int currentSize;

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
          Text(
            'Chọn kích thước bàn chơi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _SizeOptionTile(
            title: '4 × 4 (Cổ điển)',
            subtitle: 'Thử thách 2048 truyền thống',
            size: 4,
            isSelected: currentSize == 4,
            onTap: () => Navigator.pop(context, 4),
          ),
          const SizedBox(height: 8),
          _SizeOptionTile(
            title: '5 × 5 (Mở rộng)',
            subtitle: 'Thêm không gian ghép các chuỗi số lớn',
            size: 5,
            isSelected: currentSize == 5,
            onTap: () => Navigator.pop(context, 5),
          ),
          const SizedBox(height: 8),
          _SizeOptionTile(
            title: '6 × 6 (Khổng lồ)',
            subtitle: 'Thỏa sức chinh phục các kỷ lục siêu khủng',
            size: 6,
            isSelected: currentSize == 6,
            onTap: () => Navigator.pop(context, 6),
          ),
        ],
      ),
    );
  }
}

class _SizeOptionTile extends StatelessWidget {
  const _SizeOptionTile({
    required this.title,
    required this.subtitle,
    required this.size,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int size;
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${size}x$size',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: isSelected ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: colors.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
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
}

// ───────────────────────────────────────────────────────────────────────────
//  New Game Confirmation Bottom Sheet
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
            'Tiến trình ván chơi hiện tại sẽ bị thay thế.',
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
//  Result Overlay (Win / Game Over)
// ───────────────────────────────────────────────────────────────────────────

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

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
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
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
                Icon(icon, size: 48, color: colors.primary),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
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
                  child: FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
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
//  Game Over Overlay — Ưu tiên nút "Chơi ván mới" rực rỡ
// ───────────────────────────────────────────────────────────────────────────

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.score,
    required this.bestScore,
    required this.size,
    required this.canUndo,
    required this.onNewGame,
    required this.onUndo,
    required this.onBack,
  });

  final int score;
  final int bestScore;
  final int size;
  final bool canUndo;
  final VoidCallback onNewGame;
  final VoidCallback onUndo;
  final VoidCallback onBack;

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
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
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
                Icon(Icons.grid_off_rounded, size: 48, color: colors.primary),
                const SizedBox(height: 12),
                Text(
                  'Hết nước đi!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Điểm số: $score\nKỷ lục bàn ${size}x$size: $bestScore',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                // 1. Primary Action: Chơi ván mới
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onNewGame,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Chơi ván mới', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                // 2. Secondary Option: Hoàn tác nước vừa rồi (nếu canUndo)
                if (canUndo) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onUndo,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Hoàn tác nước vừa rồi', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // 3. Quay lại sảnh
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onBack,
                    child: const Text('Quay lại sảnh', style: TextStyle(fontWeight: FontWeight.w700)),
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