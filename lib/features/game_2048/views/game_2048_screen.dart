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
                        final maxBoard2 = c.maxHeight - 32;
                        final boardSize = maxBoard < maxBoard2
                            ? maxBoard
                            : maxBoard2;
                        return Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
//  HEADER — tách riêng, gọn
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
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: SizedBox(
        height: 64,
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
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Ghép số. Giữ nhịp. Tiến xa.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _ScorePill(label: 'ĐIỂM', value: score),
            const SizedBox(width: 8),
            _ScorePill(label: 'KỶ LỤC', value: best),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 16,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) => _Tile(
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

class _TileState extends State<_Tile> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> mergeScale;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    mergeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: .92), weight: 18),
      TweenSequenceItem(
        tween: Tween(begin: .92, end: 1.12).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 42,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1), weight: 40),
    ]).animate(controller);
  }

  @override
  void didUpdateWidget(covariant _Tile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.merged && widget.moveRevision != oldWidget.moveRevision) {
      controller.forward(from: 0);
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = _tileStyle(widget.value, colors);

    return Semantics(
      label:
          'Hàng ${widget.index ~/ 4 + 1}, cột ${widget.index % 4 + 1}, ${widget.value == 0 ? "trống" : widget.value}',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: widget.value == 0
            ? const SizedBox(key: ValueKey('empty'))
            : ScaleTransition(
                key: ValueKey('v${widget.value}-r${widget.appearanceRevision}'),
                scale: mergeScale,
                child: Container(
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.outline.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: style.background.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.value}',
                    style: TextStyle(
                      color: style.text,
                      fontWeight: FontWeight.w900,
                      fontSize: widget.value >= 1024 ? 22 : 30,
                      height: 1,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TileStyle {
  const _TileStyle(this.background, this.text);
  final Color background;
  final Color text;
}

// Tông màu đồng nhất — không lè lọe, dùng cùng dải amber/coral/sky
_TileStyle _tileStyle(int value, ColorScheme colors) {
  if (value == 0) {
    return _TileStyle(colors.surfaceContainerHigh, Colors.transparent);
  }
  // Phối màu theo cấp số nhân — cùng tông với theme
  switch (value) {
    case 2:
      return _TileStyle(colors.primaryContainer, colors.onPrimaryContainer);
    case 4:
      return const _TileStyle(Color(0xFFCDEFE6), Color(0xFF002A22));
    case 8:
    case 16:
    case 32:
      return _TileStyle(colors.tertiaryContainer, colors.onTertiaryContainer);
    case 64:
    case 128:
      return _TileStyle(colors.surfaceContainerHigh, colors.onSurface);
    case 256:
    case 512:
      return _TileStyle(colors.primary, colors.onPrimary);
    case 1024:
    case 2048:
      return _TileStyle(colors.tertiary, colors.onTertiary);
    default:
      return _TileStyle(colors.error, colors.onError);
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