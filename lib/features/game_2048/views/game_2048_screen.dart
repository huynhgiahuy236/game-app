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
    viewModel?.removeListener(_refresh);
    viewModel?.dispose();
    focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || viewModel == null) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => MoveDirection.up,
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.keyS => MoveDirection.down,
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.keyA => MoveDirection.left,
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD => MoveDirection.right,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    viewModel!.move(direction);
    return KeyEventResult.handled;
  }

  void _endDrag(DragEndDetails _) {
    if (dragDelta.distance < 28 || viewModel == null) return;
    final horizontal = dragDelta.dx.abs() > dragDelta.dy.abs();
    final dir = horizontal
        ? (dragDelta.dx > 0 ? MoveDirection.right : MoveDirection.left)
        : (dragDelta.dy > 0 ? MoveDirection.down : MoveDirection.up);
    HapticFeedback.selectionClick();
    viewModel!.move(dir);
    dragDelta = Offset.zero;
  }

  Future<void> _newGame() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bắt đầu ván mới?'),
            content: const Text('Điểm và bàn hiện tại sẽ được thay thế.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ván mới'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await viewModel!.newGame();
  }

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    if (vm == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Focus(
          autofocus: true,
          focusNode: focusNode,
          onKeyEvent: _key,
          child: Stack(
            children: [
              Column(
                children: [
                  Game2048Header(
                    score: vm.game.score,
                    best: vm.game.bestScore,
                    onBack: () => Navigator.pop(context),
                    onNew: _newGame,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final maxBoard = c.maxWidth - 32;
                        final maxBoard2 = c.maxHeight - 110;
                        final boardSize = maxBoard < maxBoard2
                            ? maxBoard
                            : maxBoard2;
                        return Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Điểm số nằm ngay trên ô chơi ─────────────────
                                SizedBox(
                                  width: boardSize.clamp(220.0, 480.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _AnimatedScorePill(
                                        label: 'ĐIỂM',
                                        value: vm.game.score,
                                      ),
                                      _AnimatedScorePill(
                                        label: 'KỶ LỤC',
                                        value: vm.game.bestScore,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // ── Bàn chơi 2048 ──────────────────────────────────────────────
                                SizedBox(
                                  width: boardSize.clamp(220.0, 480.0),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanStart: (_) =>
                                        dragDelta = Offset.zero,
                                    onPanUpdate: (details) =>
                                        dragDelta += details.delta,
                                    onPanEnd: _endDrag,
                                    child: Board2048(
                                      board: vm.game.board,
                                      mergedIndices: vm.lastMergedIndices,
                                      moveRevision: vm.moveRevision,
                                      appearanceRevision: vm.appearanceRevision,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Game2048ActionBar(
                                  canUndo: vm.canUndo,
                                  onUndo: vm.undo,
                                  onNew: _newGame,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Vuốt trên bàn hoặc dùng phím mũi tên / WASD.\n'
                                  'Hai ô cùng số sẽ hợp nhất một lần trong mỗi lượt.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (vm.game.won && !vm.game.keepPlaying)
                _ResultOverlay(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Bạn đã đạt 2048!',
                  message: 'Tiếp tục để xem bạn có thể đi xa đến đâu.',
                  primaryLabel: 'Tiếp tục',
                  onPrimary: vm.continueAfterWin,
                  onSecondary: _newGame,
                ),
              if (vm.game.gameOver)
                _ResultOverlay(
                  icon: Icons.grid_off_rounded,
                  title: 'Hết nước đi',
                  message: 'Điểm của bạn: ${vm.game.score}. Thử lại nhé?',
                  primaryLabel: 'Chơi lại',
                  onPrimary: vm.newGame,
                  onSecondary: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  HEADER — Tinh gọn, thanh thoát
// ───────────────────────────────────────────────────────────────────────────

class Game2048Header extends StatelessWidget {
  const Game2048Header({
    super.key,
    required this.score,
    required this.best,
    required this.onBack,
    required this.onNew,
  });
  final int score;
  final int best;
  final VoidCallback onBack;
  final VoidCallback onNew;

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
          ],
        ),
      ),
    );
  }
}

// ── Nút Điểm Số Nảy Động & Hiện Điểm Cộng ──────────────────────────────────────
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
                Text(
                  '${widget.value}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: colors.onSurface,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E), // Vibrant Green +Popup
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
//  Action bar — Undo / New — đồng nhất
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
//  Board — bảng 2048, swipe + animation
// ───────────────────────────────────────────────────────────────────────────

class Board2048 extends StatelessWidget {
  const Board2048({
    super.key,
    required this.board,
    required this.mergedIndices,
    required this.moveRevision,
    required this.appearanceRevision,
  });
  final List<int> board;
  final Set<int> mergedIndices;
  final int moveRevision;
  final int appearanceRevision;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Bàn chơi 2048, 4 hàng 4 cột',
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
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
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 16,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (context, index) => _Tile(
              key: ValueKey('tile_${index}_${board[index]}'),
              value: board[index],
              index: index,
              merged: mergedIndices.contains(index),
              moveRevision: moveRevision,
              appearanceRevision: appearanceRevision,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    super.key,
    required this.value,
    required this.index,
    required this.merged,
    required this.moveRevision,
    required this.appearanceRevision,
  });
  final int value;
  final int index;
  final bool merged;
  final int moveRevision;
  final int appearanceRevision;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  double _scale = 1.0;

  @override
  void didUpdateWidget(covariant _Tile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.merged && widget.moveRevision != oldWidget.moveRevision) {
      _bounce();
      HapticFeedback.lightImpact();
    }
  }

  void _bounce() async {
    if (!mounted) return;
    setState(() => _scale = 1.14);
    await Future.delayed(const Duration(milliseconds: 140));
    if (mounted) {
      setState(() => _scale = 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = _tileStyle(widget.value, colors);

    if (widget.value == 0) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      );
    }

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: style.shadowColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: style.shadowColor.withValues(alpha: 0.6),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 6),
              ),
              if (style.glowColor != null)
                BoxShadow(
                  color: style.glowColor!,
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Center(
            child: Text(
              '${widget.value}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: style.text,
                fontSize: widget.value >= 10000
                    ? 16
                    : (widget.value >= 1024
                        ? 20
                        : (widget.value >= 100 ? 24 : 26)),
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

// ── Phối màu 2048 Hài Hòa & Sang Trọng ──────────────────────────────────────────
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
//  Overlay
// ───────────────────────────────────────────────────────────────────────────

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

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
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 56, color: colors.primary),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
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
                        child: Text(primaryLabel),
                      ),
                    ),
                    TextButton(
                      onPressed: onSecondary,
                      child: const Text('Lựa chọn khác'),
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