import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_2048_model.dart';
import '../services/game_2048_repository.dart';
import '../viewmodels/game_2048_view_model.dart';

enum TileThemeStyle {
  vibrant('Rực Rỡ 🌈', 'Bảng màu Biển & Cầu Vồng rực rỡ'),
  classic('Cổ Điển 🏺', 'Tông màu Kem & Vàng 2048 truyền thống'),
  cyber('Cyber Neon ⚡', 'Tông màu Neon Cyberpunk đêm đô thị'),
  pastel('Nordic Slate 🍃', 'Tông mờ dịu mắt thư giãn ban đêm');

  const TileThemeStyle(this.label, this.desc);
  final String label;
  final String desc;
}

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

  // Selected Tile Theme Palette
  TileThemeStyle _currentTheme = TileThemeStyle.vibrant;

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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF141B2D) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Đổi sang bàn ${selectedSize}x$selectedSize?',
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800),
            ),
            content: Text(
              'Tiến trình ván chơi 2048 hiện tại sẽ bị xóa.',
              style: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Hủy',
                    style: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B))),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED)),
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

  Future<void> _handleThemeChangeRequest() async {
    final selectedTheme = await showModalBottomSheet<TileThemeStyle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ThemeSelectionSheet(currentTheme: _currentTheme),
    );

    if (selectedTheme != null && mounted) {
      setState(() => _currentTheme = selectedTheme);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    if (vm == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C18) : colors.surface,
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C18) : colors.surface,
        body: SafeArea(
          child: Focus(
            autofocus: true,
            focusNode: focusNode,
            onKeyEvent: _key,
            child: Stack(
              children: [
                Column(
                  children: [
                    // ── Top Header (Minimalist & Spacious) ───────────────
                    Game2048Header(
                      onBack: _handleBackPress,
                    ),

                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final maxBoardW = c.maxWidth - 24;
                          final maxBoardH = c.maxHeight - 210;
                          final boardSize =
                              (maxBoardW < maxBoardH ? maxBoardW : maxBoardH)
                                  .clamp(180.0, 480.0);

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 500),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ── Score HUD Bar ───────────────────────────
                                    SizedBox(
                                      width: boardSize,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
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

                                    // ── 2048 Board ─────────────────────────────────
                                    SizedBox(
                                      width: boardSize,
                                      height: boardSize,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanStart: (_) =>
                                            dragDelta = Offset.zero,
                                        onPanUpdate: (details) =>
                                            dragDelta += details.delta,
                                        onPanEnd: _endDrag,
                                        child: ShakeWidget(
                                          shake: vm.isInvalidMove,
                                          child: Board2048(
                                            boardSize: boardSize,
                                            gridSize: vm.game.size,
                                            tiles: vm.tiles,
                                            themeStyle: _currentTheme,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // ── Secondary Options Bar (Giao diện & Kích thước) ──
                                    SizedBox(
                                      width: boardSize,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              onTap: _handleThemeChangeRequest,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF1E293B)
                                                      : colors.surfaceContainerLow,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF334155)
                                                        : colors.outlineVariant,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                        Icons.palette_rounded,
                                                        size: 15,
                                                        color:
                                                            Color(0xFF7C3AED)),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        _currentTheme.label,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: isDark
                                                              ? Colors.white
                                                              : colors.onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: InkWell(
                                              onTap: _handleSizeChangeRequest,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF1E293B)
                                                      : colors.surfaceContainerLow,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF334155)
                                                        : colors.outlineVariant,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                        Icons.grid_on_rounded,
                                                        size: 15,
                                                        color:
                                                            Color(0xFF0284C7)),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Bàn ${vm.game.size}x${vm.game.size}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: isDark
                                                            ? Colors.white
                                                            : colors.onSurface,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // ── Primary Action Buttons (Undo & New Game) ────
                                    SizedBox(
                                      width: boardSize,
                                      child: Game2048ActionBar(
                                        canUndo: vm.canUndo,
                                        onUndo: vm.undo,
                                        onNew: _handleNewGameRequest,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // ── Hint ────────────────────────
                                    Text(
                                      'Vuốt trên bàn (${vm.game.size}×${vm.game.size}) hoặc dùng phím mũi tên / WASD để ghép số!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : colors.onSurfaceVariant,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
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

                // ── Overlays (Win / Game Over) ─────────────────────────
                if (vm.game.won && !vm.game.keepPlaying)
                  _ResultOverlay(
                    icon: Icons.auto_awesome_rounded,
                    title: 'ĐẠT CỘT MỐC 2048!',
                    message:
                        'Điểm hiện tại: ${vm.game.score}. Tiếp tục chinh phục kỷ lục mới?',
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
//  HEADER (No Overflow)
// ───────────────────────────────────────────────────────────────────────────

class Game2048Header extends StatelessWidget {
  const Game2048Header({
    super.key,
    required this.onBack,
  });
  final VoidCallback onBack;

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
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🧩', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '2048 Puzzle',
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
                    'Ghép số. Giữ nhịp. Tiến xa.',
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
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  SCORE HUD PILL
// ───────────────────────────────────────────────────────────────────────────

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
        tween: Tween(begin: 1.0, end: 1.16)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: 1.16, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: _scale,
          child: Container(
            constraints: const BoxConstraints(minWidth: 88),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : colors.onSurfaceVariant,
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
                      color: isDark ? const Color(0xFFFBBF24) : colors.onSurface,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                      fontSize: 12,
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
//  ACTION BAR
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: canUndo
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFDDF4FF))
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: canUndo
                    ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFFBAE6FD))
                    : Colors.transparent,
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: canUndo ? onUndo : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: Icon(
                Icons.undo_rounded,
                color: canUndo
                    ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                    : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
              ),
              label: Text(
                'Hoàn tác',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: canUndo
                      ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1))
                      : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: onNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Ván mới',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Colors.white,
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
//  SHAKE WIDGET
// ───────────────────────────────────────────────────────────────────────────

class ShakeWidget extends StatefulWidget {
  const ShakeWidget({
    super.key,
    required this.child,
    required this.shake,
    this.deltaX = 8.0,
    this.duration = const Duration(milliseconds: 350),
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
      TweenSequenceItem(tween: Tween(begin: -1.0, end: -0.5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.5, end: 0.0), weight: 1),
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
//  BOARD 2048
// ───────────────────────────────────────────────────────────────────────────

class Board2048 extends StatelessWidget {
  const Board2048({
    super.key,
    required this.boardSize,
    required this.gridSize,
    required this.tiles,
    required this.themeStyle,
  });

  final double boardSize;
  final int gridSize;
  final List<TileModel> tiles;
  final TileThemeStyle themeStyle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Bàn chơi 2048, $gridSize hàng $gridSize cột',
      child: Container(
        width: boardSize,
        height: boardSize,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : colors.outlineVariant,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gap = gridSize >= 6 ? 5.0 : (gridSize == 5 ? 7.0 : 9.0);
            final cellSize =
                (constraints.maxWidth - (gap * (gridSize - 1))) / gridSize;

            return Stack(
              children: [
                // Recessed Empty Slots
                for (var r = 0; r < gridSize; r++)
                  for (var c = 0; c < gridSize; c++)
                    Positioned(
                      left: c * (cellSize + gap),
                      top: r * (cellSize + gap),
                      width: cellSize,
                      height: cellSize,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                              : const Color(0xFFCBD5E1).withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(gridSize >= 6 ? 8 : 12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155).withValues(alpha: 0.4)
                                : const Color(0xFF94A3B8).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),

                // Active Animated Tiles
                for (final tile in tiles)
                  _AnimatedTileItem(
                    key: ValueKey('tile_${tile.id}'),
                    tile: tile,
                    gridSize: gridSize,
                    cellSize: cellSize,
                    gap: gap,
                    themeStyle: themeStyle,
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
    required this.themeStyle,
  });
  final TileModel tile;
  final int gridSize;
  final double cellSize;
  final double gap;
  final TileThemeStyle themeStyle;

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
          tween: Tween(begin: 1.0, end: 1.16)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.16, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _tileStyle(widget.tile.value, isDark, widget.themeStyle);

    final left = widget.tile.col * (widget.cellSize + widget.gap);
    final top = widget.tile.row * (widget.cellSize + widget.gap);

    final baseFontSize = widget.gridSize >= 6
        ? (widget.tile.value >= 1000 ? 13.0 : 16.0)
        : (widget.gridSize == 5
            ? (widget.tile.value >= 1000 ? 16.0 : 20.0)
            : (widget.tile.value >= 10000
                ? 15.0
                : (widget.tile.value >= 1024 ? 19.0 : 24.0)));

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
              borderRadius:
                  BorderRadius.circular(widget.gridSize >= 6 ? 8 : 12),
              border: Border.all(
                color: style.borderColor,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: style.shadowColor,
                  blurRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
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
//  TILE STYLING PALETTES
// ───────────────────────────────────────────────────────────────────────────

class _TileStyle {
  const _TileStyle({
    required this.background,
    required this.borderColor,
    required this.shadowColor,
    required this.text,
  });

  final Color background;
  final Color borderColor;
  final Color shadowColor;
  final Color text;
}

_TileStyle _tileStyle(int value, bool isDark, TileThemeStyle theme) {
  if (theme == TileThemeStyle.classic) {
    switch (value) {
      case 2:
        return _TileStyle(
          background: isDark ? const Color(0xFF334155) : const Color(0xFFEEE4DA),
          borderColor: isDark ? const Color(0xFF475569) : const Color(0xFFD6C7B7),
          shadowColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFC4B4A3),
          text: isDark ? Colors.white : const Color(0xFF776E65),
        );
      case 4:
        return _TileStyle(
          background: isDark ? const Color(0xFF475569) : const Color(0xFFEDE0C8),
          borderColor: isDark ? const Color(0xFF64748B) : const Color(0xFFD6C7B0),
          shadowColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFC4B49C),
          text: isDark ? Colors.white : const Color(0xFF776E65),
        );
      case 8:
        return const _TileStyle(
          background: Color(0xFFF2B179),
          borderColor: Color(0xFFF7C293),
          shadowColor: Color(0xFFD9965B),
          text: Colors.white,
        );
      case 16:
        return const _TileStyle(
          background: Color(0xFFF59563),
          borderColor: Color(0xFFF8AA80),
          shadowColor: Color(0xFFDC7A48),
          text: Colors.white,
        );
      case 32:
        return const _TileStyle(
          background: Color(0xFFF67C5F),
          borderColor: Color(0xFFF8957E),
          shadowColor: Color(0xFFDC6044),
          text: Colors.white,
        );
      case 64:
        return const _TileStyle(
          background: Color(0xFFF65E3B),
          borderColor: Color(0xFFF87C5E),
          shadowColor: Color(0xFFDC4220),
          text: Colors.white,
        );
      case 128:
        return const _TileStyle(
          background: Color(0xFFEDCF72),
          borderColor: Color(0xFFF2D98D),
          shadowColor: Color(0xFFD4B557),
          text: Colors.white,
        );
      case 256:
        return const _TileStyle(
          background: Color(0xFFEDCC61),
          borderColor: Color(0xFFF2D67E),
          shadowColor: Color(0xFFD4B246),
          text: Colors.white,
        );
      case 512:
        return const _TileStyle(
          background: Color(0xFFEDC850),
          borderColor: Color(0xFFF2D26D),
          shadowColor: Color(0xFFD4AE35),
          text: Colors.white,
        );
      case 1024:
        return const _TileStyle(
          background: Color(0xFFEDC53F),
          borderColor: Color(0xFFF2CE5C),
          shadowColor: Color(0xFFD4AA24),
          text: Colors.white,
        );
      case 2048:
        return const _TileStyle(
          background: Color(0xFFEDC22E),
          borderColor: Color(0xFFF2CB4B),
          shadowColor: Color(0xFFD4A713),
          text: Colors.white,
        );
      default:
        return const _TileStyle(
          background: Color(0xFF3C3A32),
          borderColor: Color(0xFF5A574C),
          shadowColor: Color(0xFF24231E),
          text: Colors.white,
        );
    }
  }

  if (theme == TileThemeStyle.cyber) {
    switch (value) {
      case 2:
        return const _TileStyle(
          background: Color(0xFF06B6D4), // Neon Cyan
          borderColor: Color(0xFF67E8F9),
          shadowColor: Color(0xFF0891B2),
          text: Colors.white,
        );
      case 4:
        return const _TileStyle(
          background: Color(0xFFEC4899), // Electric Pink
          borderColor: Color(0xFFF472B6),
          shadowColor: Color(0xFFDB2777),
          text: Colors.white,
        );
      case 8:
        return const _TileStyle(
          background: Color(0xFF84CC16), // Acid Green
          borderColor: Color(0xFFA3E635),
          shadowColor: Color(0xFF65A30D),
          text: Colors.white,
        );
      case 16:
        return const _TileStyle(
          background: Color(0xFFA855F7), // Cyber Purple
          borderColor: Color(0xFFC084FC),
          shadowColor: Color(0xFF9333EA),
          text: Colors.white,
        );
      case 32:
        return const _TileStyle(
          background: Color(0xFFF59E0B), // Neon Amber
          borderColor: Color(0xFFFBBF24),
          shadowColor: Color(0xFFD97706),
          text: Colors.white,
        );
      case 64:
        return const _TileStyle(
          background: Color(0xFFF43F5E), // Electric Crimson
          borderColor: Color(0xFFFB7185),
          shadowColor: Color(0xFFE11D48),
          text: Colors.white,
        );
      case 128:
        return const _TileStyle(
          background: Color(0xFF10B981), // Cyber Mint
          borderColor: Color(0xFF34D399),
          shadowColor: Color(0xFF047857),
          text: Colors.white,
        );
      case 256:
        return const _TileStyle(
          background: Color(0xFF6366F1), // Deep Indigo
          borderColor: Color(0xFFA5B4FC),
          shadowColor: Color(0xFF4338CA),
          text: Colors.white,
        );
      case 512:
        return const _TileStyle(
          background: Color(0xFFD946EF), // Hot Magenta
          borderColor: Color(0xFFE879F9),
          shadowColor: Color(0xFFC026D3),
          text: Colors.white,
        );
      case 1024:
        return const _TileStyle(
          background: Color(0xFFEAB308), // Ultra Yellow
          borderColor: Color(0xFFFDE047),
          shadowColor: Color(0xFFCA8A04),
          text: Colors.white,
        );
      case 2048:
        return const _TileStyle(
          background: Color(0xFFFACC15), // Cyber Gold
          borderColor: Color(0xFFFEF08A),
          shadowColor: Color(0xFFEAB308),
          text: Colors.white,
        );
      default:
        return const _TileStyle(
          background: Color(0xFF3B82F6),
          borderColor: Color(0xFF93C5FD),
          shadowColor: Color(0xFF1D4ED8),
          text: Colors.white,
        );
    }
  }

  if (theme == TileThemeStyle.pastel) {
    switch (value) {
      case 2:
        return const _TileStyle(
          background: Color(0xFF94A3B8), // Soft Slate
          borderColor: Color(0xFFCBD5E1),
          shadowColor: Color(0xFF64748B),
          text: Colors.white,
        );
      case 4:
        return const _TileStyle(
          background: Color(0xFF64748B), // Steel Slate
          borderColor: Color(0xFF94A3B8),
          shadowColor: Color(0xFF475569),
          text: Colors.white,
        );
      case 8:
        return const _TileStyle(
          background: Color(0xFF84A98C), // Muted Sage Green
          borderColor: Color(0xFFA3C4BC),
          shadowColor: Color(0xFF52796F),
          text: Colors.white,
        );
      case 16:
        return const _TileStyle(
          background: Color(0xFFC97C7C), // Muted Dusty Rose
          borderColor: Color(0xFFE29578),
          shadowColor: Color(0xFFB56576),
          text: Colors.white,
        );
      case 32:
        return const _TileStyle(
          background: Color(0xFFC27D56), // Muted Terracotta
          borderColor: Color(0xFFDD9368),
          shadowColor: Color(0xFFA05C36),
          text: Colors.white,
        );
      case 64:
        return const _TileStyle(
          background: Color(0xFFD4A373), // Muted Sand Gold
          borderColor: Color(0xFFE6BE94),
          shadowColor: Color(0xFFB07D4F),
          text: Colors.white,
        );
      case 128:
        return const _TileStyle(
          background: Color(0xFF52796F), // Muted Olive Teal
          borderColor: Color(0xFF84A98C),
          shadowColor: Color(0xFF354F52),
          text: Colors.white,
        );
      case 256:
        return const _TileStyle(
          background: Color(0xFF6B705C), // Muted Soft Khaki
          borderColor: Color(0xFFA5A58D),
          shadowColor: Color(0xFF4A4E3D),
          text: Colors.white,
        );
      case 512:
        return const _TileStyle(
          background: Color(0xFF9A8C98), // Muted Lavender Slate
          borderColor: Color(0xFFC9ADA7),
          shadowColor: Color(0xFF4A4E69),
          text: Colors.white,
        );
      case 1024:
        return const _TileStyle(
          background: Color(0xFF4A4E69), // Muted Dusk Blue
          borderColor: Color(0xFF9A8C98),
          shadowColor: Color(0xFF22223B),
          text: Colors.white,
        );
      case 2048:
        return const _TileStyle(
          background: Color(0xFFB5838D), // Muted Warm Ochre
          borderColor: Color(0xFFE5989B),
          shadowColor: Color(0xFF6D597A),
          text: Colors.white,
        );
      default:
        return const _TileStyle(
          background: Color(0xFF6D597A),
          borderColor: Color(0xFFB5838D),
          shadowColor: Color(0xFF355C7D),
          text: Colors.white,
        );
    }
  }

  // DEFAULT / VIBRANT (Ocean & Rainbow - Screenshot Palette)
  switch (value) {
    case 2:
      return const _TileStyle(
        background: Color(0xFF0D9488), // Emerald Teal from screenshot
        borderColor: Color(0xFF14B8A6),
        shadowColor: Color(0xFF0F766E),
        text: Colors.white,
      );
    case 4:
      return const _TileStyle(
        background: Color(0xFF0284C7), // Bright Ocean Blue from screenshot
        borderColor: Color(0xFF38BDF8),
        shadowColor: Color(0xFF0369A1),
        text: Colors.white,
      );
    case 8:
      return const _TileStyle(
        background: Color(0xFFF59E0B), // Warm Yellow-Orange from screenshot
        borderColor: Color(0xFFFBBF24),
        shadowColor: Color(0xFFD97706),
        text: Colors.white,
      );
    case 16:
      return const _TileStyle(
        background: Color(0xFFEA580C), // Deep Red-Orange from screenshot
        borderColor: Color(0xFFF97316),
        shadowColor: Color(0xFFC2410C),
        text: Colors.white,
      );
    case 32:
      return const _TileStyle(
        background: Color(0xFFE11D48), // Hot Pink / Magenta Red from screenshot
        borderColor: Color(0xFFFB7185),
        shadowColor: Color(0xFFBE123C),
        text: Colors.white,
      );
    case 64:
      return const _TileStyle(
        background: Color(0xFF9333EA), // Deep Royal Purple
        borderColor: Color(0xFFC084FC),
        shadowColor: Color(0xFF7E22CE),
        text: Colors.white,
      );
    case 128:
      return const _TileStyle(
        background: Color(0xFF10B981), // Jade Emerald
        borderColor: Color(0xFF34D399),
        shadowColor: Color(0xFF047857),
        text: Colors.white,
      );
    case 256:
      return const _TileStyle(
        background: Color(0xFF2563EB), // Royal Blue
        borderColor: Color(0xFF60A5FA),
        shadowColor: Color(0xFF1D4ED8),
        text: Colors.white,
      );
    case 512:
      return const _TileStyle(
        background: Color(0xFFF43F5E), // Bright Crimson Rose
        borderColor: Color(0xFFFDA4AF),
        shadowColor: Color(0xFFE11D48),
        text: Colors.white,
      );
    case 1024:
      return const _TileStyle(
        background: Color(0xFF84CC16), // Lime Gold
        borderColor: Color(0xFFA3E635),
        shadowColor: Color(0xFF65A30D),
        text: Colors.white,
      );
    case 2048:
      return const _TileStyle(
        background: Color(0xFFEAB308), // Pure Crown Gold
        borderColor: Color(0xFFFDE047),
        shadowColor: Color(0xFFCA8A04),
        text: Colors.white,
      );
    default:
      return const _TileStyle(
        background: Color(0xFF6366F1),
        borderColor: Color(0xFFA5B4FC),
        shadowColor: Color(0xFF4338CA),
        text: Colors.white,
      );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  RESULT OVERLAY
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.75),
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
                  blurRadius: 26,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 52, color: const Color(0xFF7C3AED)),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : colors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
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
                      onPressed: onPrimary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(primaryLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF475569)
                            : colors.outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(secondaryLabel,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFE2E8F0)
                                : colors.onSurface)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🚫', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  'KHÔNG THỂ DI CHUYỂN!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFEF4444),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Điểm số đạt được: $score\nKỷ lục bàn ${size}x$size: $bestScore',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                if (canUndo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onUndo,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          side: const BorderSide(color: Color(0xFF7C3AED)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.undo_rounded,
                            color: Color(0xFF7C3AED)),
                        label: const Text('Hoàn tác bước trước ↩️',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7C3AED))),
                      ),
                    ),
                  ),
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
                      onPressed: onNewGame,
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
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onBack,
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
//  SHEETS
// ───────────────────────────────────────────────────────────────────────────

class _ThemeSelectionSheet extends StatelessWidget {
  const _ThemeSelectionSheet({required this.currentTheme});
  final TileThemeStyle currentTheme;

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
            'Chọn Bảng Màu Giao Diện 🎨',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          for (final t in TileThemeStyle.values) ...[
            Container(
              decoration: BoxDecoration(
                color: currentTheme == t
                    ? (isDark
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                        : colors.primaryContainer.withValues(alpha: 0.5))
                    : (isDark
                        ? const Color(0xFF1E293B)
                        : colors.surfaceContainerLow),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: currentTheme == t
                      ? const Color(0xFF7C3AED)
                      : (isDark
                          ? const Color(0xFF334155)
                          : colors.outlineVariant),
                  width: currentTheme == t ? 2 : 1,
                ),
              ),
              child: ListTile(
                onTap: () => Navigator.pop(context, t),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: currentTheme == t
                        ? const Color(0xFF7C3AED)
                        : (isDark
                            ? const Color(0xFF334155)
                            : colors.surfaceContainerHigh),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.palette_rounded,
                      size: 20,
                      color: currentTheme == t
                          ? Colors.white
                          : (isDark ? Colors.white : colors.onSurface),
                    ),
                  ),
                ),
                title: Text(
                  t.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : colors.onSurface,
                  ),
                ),
                subtitle: Text(
                  t.desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : colors.onSurfaceVariant,
                  ),
                ),
                trailing: currentTheme == t
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF7C3AED))
                    : Icon(Icons.chevron_right_rounded,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : colors.outline),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SizeSelectionSheet extends StatelessWidget {
  const _SizeSelectionSheet({required this.currentSize});
  final int currentSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    final sizes = [
      (4, 'Bàn 4x4', 'Kích thước cổ điển 2048'),
      (5, 'Bàn 5x5', 'Thách thức bàn rộng vừa'),
      (6, 'Bàn 6x6', 'Bàn siêu rộng thoải mái ghép'),
    ];

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
            'Chọn kích thước bàn 2048 🧩',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          for (final (sz, title, desc) in sizes) ...[
            Container(
              decoration: BoxDecoration(
                color: currentSize == sz
                    ? (isDark
                        ? const Color(0xFF0284C7).withValues(alpha: 0.2)
                        : colors.primaryContainer.withValues(alpha: 0.5))
                    : (isDark
                        ? const Color(0xFF1E293B)
                        : colors.surfaceContainerLow),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: currentSize == sz
                      ? const Color(0xFF0284C7)
                      : (isDark
                          ? const Color(0xFF334155)
                          : colors.outlineVariant),
                  width: currentSize == sz ? 2 : 1,
                ),
              ),
              child: ListTile(
                onTap: () => Navigator.pop(context, sz),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: currentSize == sz
                        ? const Color(0xFF0284C7)
                        : (isDark
                            ? const Color(0xFF334155)
                            : colors.surfaceContainerHigh),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${sz}x$sz',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: currentSize == sz
                            ? Colors.white
                            : (isDark ? Colors.white : colors.onSurface),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : colors.onSurface,
                  ),
                ),
                subtitle: Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : colors.onSurfaceVariant,
                  ),
                ),
                trailing: currentSize == sz
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF0284C7))
                    : Icon(Icons.chevron_right_rounded,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : colors.outline),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

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
            'Bắt đầu ván 2048 mới?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tiến trình ván chơi 2048 hiện tại sẽ bị xóa.',
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