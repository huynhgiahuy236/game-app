import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/block_puzzle_models.dart';
import '../services/block_puzzle_repository.dart';
import '../viewmodels/block_puzzle_view_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  COLOR PALETTE — vibrant, mirrors 2048 ocean/rainbow scheme
// ═══════════════════════════════════════════════════════════════════════════

const _kColors = <int, _BlockPalette>{
  1: _BlockPalette(Color(0xFF0D9488), Color(0xFF2DD4BF), Color(0xFF0F766E)), // Teal
  2: _BlockPalette(Color(0xFF0284C7), Color(0xFF38BDF8), Color(0xFF0369A1)), // Sky Blue
  3: _BlockPalette(Color(0xFFF59E0B), Color(0xFFFCD34D), Color(0xFFD97706)), // Amber
  4: _BlockPalette(Color(0xFFEA580C), Color(0xFFFB923C), Color(0xFFC2410C)), // Orange
  5: _BlockPalette(Color(0xFFE11D48), Color(0xFFFB7185), Color(0xFFBE123C)), // Rose
  6: _BlockPalette(Color(0xFF9333EA), Color(0xFFC084FC), Color(0xFF7E22CE)), // Purple
  7: _BlockPalette(Color(0xFF10B981), Color(0xFF34D399), Color(0xFF047857)), // Emerald
  8: _BlockPalette(Color(0xFF2563EB), Color(0xFF60A5FA), Color(0xFF1D4ED8)), // Blue
};

class _BlockPalette {
  const _BlockPalette(this.base, this.light, this.dark);
  final Color base;
  final Color light;
  final Color dark;
}

_BlockPalette _palette(int idx) =>
    _kColors[idx] ?? const _BlockPalette(Color(0xFF6366F1), Color(0xFFA5B4FC), Color(0xFF4338CA));

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class BlockPuzzleScreen extends StatefulWidget {
  const BlockPuzzleScreen({super.key, required this.repository});
  final BlockPuzzleRepository repository;

  @override
  State<BlockPuzzleScreen> createState() => _BlockPuzzleScreenState();
}

class _BlockPuzzleScreenState extends State<BlockPuzzleScreen>
    with TickerProviderStateMixin {
  BlockPuzzleViewModel? _vm;

  // Double-back
  bool _isDoubleBackWaiting = false;
  Timer? _doubleBackTimer;

  // Toast
  String? _toastMessage;
  Timer? _toastTimer;

  // Flash animation for cleared lines
  late final AnimationController _flashCtrl;
  late final Animation<double> _flashAnim;

  // Score pop
  late final AnimationController _scorePopCtrl;
  late final Animation<double> _scorePopScale;
  late final Animation<double> _scorePopFade;
  int _lastScore = 0;
  int _scoreGain = 0;

  // Board GlobalKey for RenderBox
  final _boardKey = GlobalKey();

  // Hover state
  (int, int)? _hoverCell;
  bool _canPlaceAtHover = false;

  // Board inner padding (to avoid ClipRRect cutting cells)
  static const double _boardPad = 8.0;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flashAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut));

    _scorePopCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scorePopScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 65,
      ),
    ]).animate(_scorePopCtrl);
    _scorePopFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _scorePopCtrl, curve: const Interval(0.6, 1.0)),
    );

    _load();
  }

  Future<void> _load() async {
    final vm = await BlockPuzzleViewModel.create(widget.repository);
    vm.addListener(_onVmChanged);
    if (mounted) {
      setState(() {
        _vm = vm;
        _lastScore = vm.game.score;
      });
    }
  }

  void _onVmChanged() {
    if (!mounted) return;
    final vm = _vm;
    if (vm != null) {
      final newScore = vm.game.score;
      if (newScore > _lastScore) {
        _scoreGain = newScore - _lastScore;
        _scorePopCtrl.forward(from: 0.0);
      }
      _lastScore = newScore;

      if (vm.lastClearedRows.isNotEmpty || vm.lastClearedCols.isNotEmpty) {
        _flashCtrl.forward(from: 0.0);
        HapticFeedback.mediumImpact();
      } else if (vm.newlyPlacedCells.isNotEmpty) {
        HapticFeedback.lightImpact();
      }

      if (vm.game.isGameOver) {
        HapticFeedback.heavyImpact();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _doubleBackTimer?.cancel();
    _toastTimer?.cancel();
    _flashCtrl.dispose();
    _scorePopCtrl.dispose();
    _vm?.removeListener(_onVmChanged);
    _vm?.dispose();
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
      if (mounted) setState(() => _isDoubleBackWaiting = false);
    });
  }

  /// Convert a global finger position → board cell (row, col)
  (int, int)? _offsetToCell(Offset globalPos, double cellSize, double gap) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPos);
    // Subtract inner padding
    final inner = local - const Offset(_boardPad, _boardPad);
    final stride = cellSize + gap;
    final col = (inner.dx / stride).floor();
    final row = (inner.dy / stride).floor();
    if (row < 0 || row >= BlockPuzzleGame.boardSize) return null;
    if (col < 0 || col >= BlockPuzzleGame.boardSize) return null;
    return (row, col);
  }

  (int, int)? _snapCell(BlockPiece piece, (int, int) rawCell) {
    final minR = piece.cells.map((c) => c.$1).reduce(min);
    final minC = piece.cells.map((c) => c.$2).reduce(min);
    return (rawCell.$1 - minR, rawCell.$2 - minC);
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (vm == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C18) : const Color(0xFFF0F4FF),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488))),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF06091A) : const Color(0xFFF0F4FF),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ── Board sizing ───────────────────────────────────────────
              // Reserve: header(52) + scorePills(80) + tray(130) + hint(32) + gaps(24)
              const reservedH = 52.0 + 80.0 + 130.0 + 32.0 + 24.0;
              final availW = constraints.maxWidth - 32.0; // horizontal margin
              final availH = constraints.maxHeight - reservedH;
              final boardPx = min(availW, availH).clamp(240.0, 420.0);
              const gap = 2.0;
              // Inner content = boardPx - 2*padding
              final innerPx = boardPx - 2 * _boardPad;
              final cellSize = (innerPx - gap * (BlockPuzzleGame.boardSize - 1)) /
                  BlockPuzzleGame.boardSize;

              return Stack(
                children: [
                  Column(
                    children: [
                      // ── Header ─────────────────────────────────────────
                      _BPHeader(onBack: _handleBackPress, isDark: isDark),

                      // ── Score HUD ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: ScaleTransition(
                                scale: _scorePopScale,
                                child: _GlowScorePill(
                                  label: 'ĐIỂM',
                                  value: vm.game.score,
                                  glowColor: const Color(0xFF0D9488),
                                  isDark: isDark,
                                  isMain: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _GlowScorePill(
                                label: 'KỶ LỤC',
                                value: vm.game.bestScore,
                                glowColor: const Color(0xFFEAB308),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _GlowScorePill(
                                label: 'CHUỖI',
                                value: vm.game.combo,
                                glowColor: const Color(0xFFE11D48),
                                isDark: isDark,
                                showFire: vm.game.combo >= 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Board ──────────────────────────────────────────
                      _BlockBoard(
                        boardKey: _boardKey,
                        vm: vm,
                        boardPx: boardPx,
                        cellSize: cellSize,
                        gap: gap,
                        innerPad: _boardPad,
                        flashAnim: _flashAnim,
                        hoverCell: _hoverCell,
                        canPlaceAtHover: _canPlaceAtHover,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 12),

                      // ── Piece Tray ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _PieceTray(
                          vm: vm,
                          boardKey: _boardKey,
                          cellSize: cellSize,
                          gap: gap,
                          isDark: isDark,
                          onDragStarted: vm.startDrag,
                          onDragUpdate: (globalPos) {
                            final trayIdx = vm.draggingTrayIndex;
                            if (trayIdx == null) return;
                            final piece = vm.game.tray[trayIdx];
                            if (piece == null) return;
                            final rawCell = _offsetToCell(globalPos, cellSize, gap);
                            if (rawCell == null) {
                              if (_hoverCell != null) {
                                setState(() { _hoverCell = null; _canPlaceAtHover = false; });
                              }
                              return;
                            }
                            final snapped = _snapCell(piece, rawCell);
                            if (snapped == null) return;
                            final can = vm.game.canPlace(piece, snapped.$1, snapped.$2);
                            if (snapped != _hoverCell || can != _canPlaceAtHover) {
                              setState(() { _hoverCell = snapped; _canPlaceAtHover = can; });
                            }
                          },
                          onDragEnd: (globalPos) {
                            final trayIdx = vm.draggingTrayIndex;
                            if (trayIdx == null) return;
                            final piece = vm.game.tray[trayIdx];
                            if (piece == null) { vm.cancelDrag(); return; }
                            final rawCell = _offsetToCell(globalPos, cellSize, gap);
                            bool placed = false;
                            if (rawCell != null) {
                              final snapped = _snapCell(piece, rawCell);
                              if (snapped != null) {
                                placed = vm.tryPlace(snapped.$1, snapped.$2);
                              }
                            }
                            if (!placed) vm.cancelDrag();
                            setState(() { _hoverCell = null; _canPlaceAtHover = false; });
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Hint ───────────────────────────────────────────
                      Text(
                        'Kéo mảnh vào bàn  ·  Xóa hàng & cột để ghi điểm',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  // ── Score gain pop ─────────────────────────────────────
                  if (_scoreGain > 0)
                    Positioned(
                      top: 130,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _scorePopCtrl,
                          builder: (context, anim) => Opacity(
                            opacity: _scorePopFade.value,
                            child: Transform.translate(
                              offset: Offset(0, -50 * _scorePopCtrl.value),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '+$_scoreGain',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Toast ──────────────────────────────────────────────
                  if (_toastMessage != null)
                    Positioned(
                      top: 64,
                      left: 24,
                      right: 24,
                      child: _Toast(message: _toastMessage!),
                    ),

                  // ── Game Over ──────────────────────────────────────────
                  if (vm.game.isGameOver)
                    _GameOverOverlay(
                      score: vm.game.score,
                      best: vm.game.bestScore,
                      totalClears: vm.game.totalClears,
                      isDark: isDark,
                      onNewGame: () => vm.newGame(),
                      onBack: _handleBackPress,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _BPHeader extends StatelessWidget {
  const _BPHeader({required this.onBack, required this.isDark});
  final VoidCallback onBack;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            // Back button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : colors.outlineVariant,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : colors.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Game icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Text('🟦', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Block Puzzle',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Xếp mảnh · Xóa hàng · Lên điểm!',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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

// ═══════════════════════════════════════════════════════════════════════════
//  GLOW SCORE PILL
// ═══════════════════════════════════════════════════════════════════════════

class _GlowScorePill extends StatelessWidget {
  const _GlowScorePill({
    required this.label,
    required this.value,
    required this.glowColor,
    required this.isDark,
    this.isMain = false,
    this.showFire = false,
  });
  final String label;
  final int value;
  final Color glowColor;
  final bool isDark;
  final bool isMain;
  final bool showFire;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF0F172A), glowColor, 0.08)
            : Color.lerp(Colors.white, glowColor, 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? glowColor.withValues(alpha: 0.25)
              : glowColor.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: isDark ? 0.18 : 0.1),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: glowColor,
                ),
              ),
              if (showFire) ...[
                const SizedBox(width: 2),
                const Text('🔥', style: TextStyle(fontSize: 9)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  BOARD
// ═══════════════════════════════════════════════════════════════════════════

class _BlockBoard extends StatelessWidget {
  const _BlockBoard({
    required this.boardKey,
    required this.vm,
    required this.boardPx,
    required this.cellSize,
    required this.gap,
    required this.innerPad,
    required this.flashAnim,
    required this.hoverCell,
    required this.canPlaceAtHover,
    required this.isDark,
  });

  final GlobalKey boardKey;
  final BlockPuzzleViewModel vm;
  final double boardPx;
  final double cellSize;
  final double gap;
  final double innerPad;
  final Animation<double> flashAnim;
  final (int, int)? hoverCell;
  final bool canPlaceAtHover;
  final bool isDark;

  Set<(int, int)> _buildGhostCells() {
    final result = <(int, int)>{};
    final trayIdx = vm.draggingTrayIndex;
    if (trayIdx == null || hoverCell == null) return result;
    final piece = vm.game.tray[trayIdx];
    if (piece == null) return result;
    for (final (dr, dc) in piece.cells) {
      final r = hoverCell!.$1 + dr;
      final c = hoverCell!.$2 + dc;
      if (r >= 0 && r < BlockPuzzleGame.boardSize &&
          c >= 0 && c < BlockPuzzleGame.boardSize) {
        result.add((r, c));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ghostCells = _buildGhostCells();

    return Center(
      child: Container(
        key: boardKey,
        width: boardPx,
        height: boardPx,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B1120) : const Color(0xFFE8EDF5),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? const Color(0xFF1E3A5F).withValues(alpha: 0.8)
                : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 28,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
            if (isDark)
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.06),
                blurRadius: 40,
                spreadRadius: -6,
              ),
          ],
        ),
        child: Padding(
          // Inner padding avoids cells touching the rounded border
          padding: EdgeInsets.all(innerPad),
          child: AnimatedBuilder(
            animation: flashAnim,
            builder: (context, _) {
              return CustomPaint(
                painter: _BoardPainter(
                  board: vm.game.board,
                  cellSize: cellSize,
                  gap: gap,
                  clearedRows: vm.lastClearedRows,
                  clearedCols: vm.lastClearedCols,
                  flashValue: flashAnim.value,
                  ghostCells: ghostCells,
                  canPlace: canPlaceAtHover,
                  newlyPlaced: vm.newlyPlacedCells,
                  isDark: isDark,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.board,
    required this.cellSize,
    required this.gap,
    required this.clearedRows,
    required this.clearedCols,
    required this.flashValue,
    required this.ghostCells,
    required this.canPlace,
    required this.newlyPlaced,
    required this.isDark,
  });

  final List<List<int>> board;
  final double cellSize;
  final double gap;
  final List<int> clearedRows;
  final List<int> clearedCols;
  final double flashValue;
  final Set<(int, int)> ghostCells;
  final bool canPlace;
  final Set<(int, int)> newlyPlaced;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final stride = cellSize + gap;
    final radius = Radius.circular(cellSize * 0.22);

    // Pre-compute paints
    final emptyFill = Paint()
      ..color = isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.55)
          : const Color(0xFFCBD5E1).withValues(alpha: 0.55);
    final emptyBorder = Paint()
      ..color = isDark
          ? const Color(0xFF334155).withValues(alpha: 0.35)
          : const Color(0xFF94A3B8).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (int r = 0; r < BlockPuzzleGame.boardSize; r++) {
      for (int c = 0; c < BlockPuzzleGame.boardSize; c++) {
        final left = c * stride;
        final top = r * stride;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cellSize, cellSize),
          radius,
        );

        final colorIdx = board[r][c];
        final isGhost = ghostCells.contains((r, c));
        final isCleared = clearedRows.contains(r) || clearedCols.contains(c);
        final isNew = newlyPlaced.contains((r, c));

        if (colorIdx == 0) {
          // Empty
          if (isGhost) {
            final alpha = 0.45 + 0.15 * sin(DateTime.now().millisecondsSinceEpoch / 200);
            canvas.drawRRect(
              rect,
              Paint()
                ..color = canPlace
                    ? const Color(0xFF0D9488).withValues(alpha: alpha.clamp(0.35, 0.6))
                    : const Color(0xFFE11D48).withValues(alpha: 0.35),
            );
            canvas.drawRRect(
              rect,
              Paint()
                ..color = canPlace
                    ? const Color(0xFF2DD4BF).withValues(alpha: 0.85)
                    : const Color(0xFFFB7185).withValues(alpha: 0.7)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.8,
            );
          } else {
            canvas.drawRRect(rect, emptyFill);
            canvas.drawRRect(rect, emptyBorder);
          }
        } else {
          // Filled
          final pal = _palette(colorIdx);
          Color cellColor = pal.base;
          Color lightColor = pal.light;

          // Flash-to-white on clear
          if (isCleared && flashValue > 0) {
            cellColor = Color.lerp(cellColor, Colors.white, flashValue * 0.9)!;
            lightColor = Color.lerp(lightColor, Colors.white, flashValue)!;
          }

          // Bottom shadow block
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left, top + cellSize * 0.12, cellSize, cellSize),
              radius,
            ),
            Paint()..color = pal.dark.withValues(alpha: isCleared ? 0.2 : 0.75),
          );

          // Main fill
          canvas.drawRRect(rect, Paint()..color = cellColor);

          // Top gloss
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left + 3, top + 3, cellSize - 6, cellSize * 0.38),
              Radius.circular(cellSize * 0.16),
            ),
            Paint()..color = Colors.white.withValues(alpha: 0.28),
          );

          // Border
          canvas.drawRRect(
            rect,
            Paint()
              ..color = lightColor.withValues(alpha: isCleared ? 0.4 : 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );

          // Newly-placed white ring
          if (isNew) {
            canvas.drawRRect(
              rect,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.5)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.2,
            );
          }
        }
      }
    }

    // Clear flash overlay
    if (flashValue > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: flashValue * 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}


// ═══════════════════════════════════════════════════════════════════════════
//  PIECE TRAY
// ═══════════════════════════════════════════════════════════════════════════

class _PieceTray extends StatelessWidget {
  const _PieceTray({
    required this.vm,
    required this.boardKey,
    required this.cellSize,
    required this.gap,
    required this.isDark,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final BlockPuzzleViewModel vm;
  final GlobalKey boardKey;
  final double cellSize;
  final double gap;
  final bool isDark;
  final ValueChanged<int> onDragStarted;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<Offset> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D1326).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? const Color(0xFF1E3A5F).withValues(alpha: 0.8)
              : colors.outlineVariant,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) {
          final piece = vm.game.tray[i];
          // Preview cell size: fixed compact size that fits in tray
          const trayCellSize = 22.0;
          const trayGap = 2.0;
          return _TraySlot(
            piece: piece,
            index: i,
            cellSize: trayCellSize,
            gap: trayGap,
            isDark: isDark,
            isDragging: vm.draggingTrayIndex == i,
            onDragStarted: () => onDragStarted(i),
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          );
        }),
      ),
    );
  }
}

class _TraySlot extends StatefulWidget {
  const _TraySlot({
    required this.piece,
    required this.index,
    required this.cellSize,
    required this.gap,
    required this.isDark,
    required this.isDragging,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });
  final BlockPiece? piece;
  final int index;
  final double cellSize;
  final double gap;
  final bool isDark;
  final bool isDragging;
  final VoidCallback onDragStarted;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<Offset> onDragEnd;

  @override
  State<_TraySlot> createState() => _TraySlotState();
}

class _TraySlotState extends State<_TraySlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;
  bool _isDragActive = false;
  Offset _dragOffset = Offset.zero;
  Offset _startPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  (double, double) _pieceDimensions(BlockPiece piece) {
    final maxR = piece.cells.map((c) => c.$1).reduce(max);
    final maxC = piece.cells.map((c) => c.$2).reduce(max);
    return (
      (maxC + 1) * (widget.cellSize + widget.gap) - widget.gap,
      (maxR + 1) * (widget.cellSize + widget.gap) - widget.gap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final piece = widget.piece;

    // Empty slot — subtle dashed placeholder
    if (piece == null) {
      return SizedBox(
        width: 90,
        height: 90,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isDark
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 20,
              color: widget.isDark
                  ? const Color(0xFF1E3A5F)
                  : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      );
    }

    final (pw, ph) = _pieceDimensions(piece);
    final pal = _palette(piece.colorIndex);

    Widget pieceWidget = SizedBox(
      width: pw,
      height: ph,
      child: CustomPaint(
        painter: _PiecePainter(
          piece: piece,
          cellSize: widget.cellSize,
          gap: widget.gap,
          glowColor: pal.base,
        ),
        size: Size(pw, ph),
      ),
    );

    return Listener(
      onPointerDown: (e) {
        if (widget.isDragging) return;
        _pressCtrl.forward();
        _startPos = e.position;
        _dragOffset = e.position;
      },
      onPointerMove: (e) {
        _dragOffset = e.position;
        if (!_isDragActive) {
          final dist = (e.position - _startPos).distance;
          if (dist > 6) {
            setState(() => _isDragActive = true);
            widget.onDragStarted();
            _pressCtrl.reverse();
          }
        }
        if (_isDragActive) widget.onDragUpdate(e.position);
      },
      onPointerUp: (e) {
        _pressCtrl.reverse();
        if (_isDragActive) {
          widget.onDragEnd(e.position);
          setState(() => _isDragActive = false);
        }
      },
      onPointerCancel: (_) {
        _pressCtrl.reverse();
        if (_isDragActive) {
          widget.onDragEnd(_dragOffset);
          setState(() => _isDragActive = false);
        }
      },
      child: SizedBox(
        width: 90,
        height: 90,
        child: AnimatedBuilder(
          animation: _pressAnim,
          builder: (context, child) => Transform.scale(
            scale: _pressAnim.value,
            child: AnimatedOpacity(
              opacity: _isDragActive ? 0.25 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Center(child: pieceWidget),
            ),
          ),
        ),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  _PiecePainter({
    required this.piece,
    required this.cellSize,
    required this.gap,
    required this.glowColor,
  });
  final BlockPiece piece;
  final double cellSize;
  final double gap;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final pal = _palette(piece.colorIndex);
    final stride = cellSize + gap;
    final radius = Radius.circular(cellSize * 0.22);

    for (final (dr, dc) in piece.cells) {
      final left = dc * stride;
      final top = dr * stride;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, cellSize, cellSize),
        radius,
      );

      // Shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top + cellSize * 0.14, cellSize, cellSize),
          radius,
        ),
        Paint()..color = pal.dark.withValues(alpha: 0.75),
      );
      // Fill
      canvas.drawRRect(rect, Paint()..color = pal.base);
      // Gloss
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 2, top + 2, cellSize - 4, cellSize * 0.38),
          Radius.circular(cellSize * 0.15),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.3),
      );
      // Border
      canvas.drawRRect(
        rect,
        Paint()
          ..color = pal.light.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.piece.id != piece.id || old.cellSize != cellSize;
}

// ═══════════════════════════════════════════════════════════════════════════
//  TOAST
// ═══════════════════════════════════════════════════════════════════════════

class _Toast extends StatelessWidget {
  const _Toast({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
            ),
          ],
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GAME OVER OVERLAY
// ═══════════════════════════════════════════════════════════════════════════

class _GameOverOverlay extends StatefulWidget {
  const _GameOverOverlay({
    required this.score,
    required this.best,
    required this.totalClears,
    required this.isDark,
    required this.onNewGame,
    required this.onBack,
  });
  final int score;
  final int best;
  final int totalClears;
  final bool isDark;
  final VoidCallback onNewGame;
  final VoidCallback onBack;

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideY;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideY = Tween<double>(begin: 80, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNewBest = widget.score > 0 && widget.score >= widget.best;
    final colors = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _slideY.value),
                child: Transform.scale(
                  scale: _scale.value,
                  child: child,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF0B1120)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                      blurRadius: 40,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon badge
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.45),
                            blurRadius: 24,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isNewBest ? '🏆' : '🟦',
                          style: const TextStyle(fontSize: 34),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      isNewBest ? 'KỶ LỤC MỚI!' : 'HẾT LƯỢT!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isNewBest
                          ? 'Tuyệt vời! Bạn đã phá vỡ kỷ lục cũ!'
                          : 'Không còn mảnh nào đặt được nữa!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Stats row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _GOStat(label: 'ĐIỂM', value: widget.score,
                              color: const Color(0xFF0D9488), isDark: widget.isDark),
                          _Divider(isDark: widget.isDark),
                          _GOStat(label: 'KỶ LỤC', value: widget.best,
                              color: const Color(0xFFEAB308), isDark: widget.isDark),
                          _Divider(isDark: widget.isDark),
                          _GOStat(label: 'HÀNG XÓA', value: widget.totalClears,
                              color: const Color(0xFF9333EA), isDark: widget.isDark),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Play again
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: widget.onNewGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                          label: const Text(
                            'Chơi lại',
                            style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: widget.onBack,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          side: BorderSide(
                            color: widget.isDark
                                ? const Color(0xFF334155)
                                : colors.outlineVariant,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Về trang chủ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: widget.isDark ? const Color(0xFFE2E8F0) : colors.onSurface,
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
      ),
    );
  }
}

class _GOStat extends StatelessWidget {
  const _GOStat({required this.label, required this.value, required this.color, required this.isDark});
  final String label;
  final int value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            )),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: isDark
          ? const Color(0xFF1E293B)
          : const Color(0xFFE2E8F0),
    );
  }
}
