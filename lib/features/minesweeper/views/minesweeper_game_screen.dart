import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
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
    with TickerProviderStateMixin {
  MinesweeperViewModel? viewModel;

  // Shake & Explosion Animation Controllers
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;
  late final AnimationController _explosionController;
  List<_ExplosionParticle> _particles = [];

  final TransformationController _transformationController =
      TransformationController();

  // Double-back exit protection
  bool _isDoubleBackWaiting = false;
  Timer? _doubleBackTimer;

  // Non-blocking toast state
  String? _toastMessage;
  Timer? _toastTimer;

  bool _hasCheckedSavedGame = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _shakeAnim = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    );

    _explosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _loadViewModel();
  }

  Future<void> _loadViewModel() async {
    final loaded = await MinesweeperViewModel.create(widget.repository);
    loaded.addListener(_refresh);
    if (mounted) {
      setState(() => viewModel = loaded);
      _checkPendingSavedGame(loaded);
    }
  }

  void _checkPendingSavedGame(MinesweeperViewModel vm) {
    if (_hasCheckedSavedGame) return;
    _hasCheckedSavedGame = true;

    if (vm.pendingSavedGame != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _ResumeGameSheet(
            savedState: vm.pendingSavedGame!,
            onResume: () {
              Navigator.pop(ctx);
              vm.resumeSavedGame();
            },
            onNewGame: () {
              Navigator.pop(ctx);
              vm.clearSavedGame();
            },
          ),
        );
      });
    }
  }

  void _refresh() {
    if (!mounted) return;
    final vm = viewModel;
    if (vm != null &&
        vm.status == MinesweeperStatus.lost &&
        !_shakeController.isAnimating) {
      _triggerExplosionEffect();
    }
    setState(() {});
  }

  void _triggerExplosionEffect() {
    HapticFeedback.lightImpact();
    _shakeController.forward(from: 0.0);
    _showToast('💥 Mìn nổ! Bấm Ván Mới để thử lại');

    // Generate 45 fire & smoke explosion particles
    final rand = Random();
    _particles = List.generate(55, (i) {
      final angle = rand.nextDouble() * 2 * pi;
      final speed = 140.0 + rand.nextDouble() * 320.0;
      final size = 4.0 + rand.nextDouble() * 12.0;
      final colors = [
        const Color(0xFFEF4444),
        const Color(0xFFF59E0B),
        const Color(0xFFF97316),
        const Color(0xFFDC2626),
        const Color(0xFFFEF08A),
        const Color(0xFF64748B),
      ];
      return _ExplosionParticle(
        angle: angle,
        speed: speed,
        size: size,
        color: colors[rand.nextInt(colors.length)],
        decay: 0.75 + rand.nextDouble() * 0.25,
      );
    });

    _explosionController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _doubleBackTimer?.cancel();
    _toastTimer?.cancel();
    viewModel?.removeListener(_refresh);
    viewModel?.dispose();
    _shakeController.dispose();
    _explosionController.dispose();
    _transformationController.dispose();
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

  Future<void> _handleNewGameRequest() async {
    final vm = viewModel;
    if (vm == null) return;

    if (vm.firstClickDone && vm.status == MinesweeperStatus.playing) {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const _NewGameConfirmationSheet(),
      );
      if (confirmed != true) return;
    }

    _transformationController.value = Matrix4.identity();
    await vm.startNewGame();
  }

  Future<void> _showDifficultySheet() async {
    final vm = viewModel;
    if (vm == null) return;

    final selected = await showModalBottomSheet<MinesweeperDifficulty>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _DifficultySelectionSheet(currentDifficulty: vm.difficulty),
    );

    if (selected != null && mounted) {
      if (selected == MinesweeperDifficulty.custom) {
        _showCustomConfigDialog();
      } else {
        if (vm.firstClickDone && vm.status == MinesweeperStatus.playing) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor:
                  isDark ? const Color(0xFF141B2D) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Đổi sang ${selected.label}?',
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800),
              ),
              content: Text(
                'Ván Dò Mìn hiện tại sẽ bị hủy và tính lại từ đầu.',
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
                      backgroundColor: const Color(0xFFEF4444)),
                  child: const Text('Đồng ý'),
                ),
              ],
            ),
          );
          if (confirm != true) return;
        }
        _transformationController.value = Matrix4.identity();
        await vm.startNewGame(newDiff: selected);
      }
    }
  }

  Future<void> _showCustomConfigDialog() async {
    final vm = viewModel;
    if (vm == null) return;

    final config = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => _CustomDifficultyDialog(
        initialRows: vm.customRows,
        initialCols: vm.customCols,
        initialMines: vm.customMines,
      ),
    );

    if (config != null && mounted) {
      _transformationController.value = Matrix4.identity();
      await vm.startNewGame(
        newDiff: MinesweeperDifficulty.custom,
        rows: config['rows'],
        cols: config['cols'],
        mines: config['mines'],
      );
    }
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
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
          child: CircularProgressIndicator(color: Color(0xFFEF4444)),
        ),
      );
    }

    final scale = _transformationController.value.getMaxScaleOnAxis();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C18) : colors.surface,
        body: Stack(
          children: [
            // Background Ambient Glow Effects
            Positioned(
              top: -80,
              left: -40,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.06),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                          : const Color(0xFFEF4444).withValues(alpha: 0.08),
                      blurRadius: 90,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              right: -40,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                      : const Color(0xFF7C3AED).withValues(alpha: 0.06),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                          : const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      blurRadius: 90,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── Top Header ──────────────────────────────────────────
                  _MinesweeperHeader(
                    difficulty: vm.difficulty,
                    soundMuted: vm.soundMuted,
                    isPaused: vm.status == MinesweeperStatus.paused,
                    onBack: _handleBackPress,
                    onDifficultyTap: _showDifficultySheet,
                    onSoundToggle: vm.toggleSoundMuted,
                    onPauseToggle: vm.togglePause,
                  ),

                  // ── Status Bar (HUD Timer & Flag Count) ─────────────────────
                  _MinesweeperStatusBar(vm: vm),

                  const SizedBox(height: 8),

                  // ── Touch Mode Switcher (Mở ô vs Cắm cờ) ────────────────
                  _MinesweeperModeToggle(vm: vm),

                  const SizedBox(height: 8),

                  // ── Board Container with Zoom/Pan & Explosion Shake ──────
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedBuilder(
                              animation: _shakeAnim,
                              builder: (context, child) {
                                final dx = sin(_shakeAnim.value * pi * 12) *
                                    (22 * (1 - _shakeAnim.value));
                                final dy = cos(_shakeAnim.value * pi * 10) *
                                    (14 * (1 - _shakeAnim.value));
                                return Transform.translate(
                                  offset: Offset(dx, dy),
                                  child: child,
                                );
                              },
                              child: InteractiveViewer(
                                panEnabled: vm.difficulty != MinesweeperDifficulty.easy,
                                scaleEnabled: true,
                                transformationController:
                                    _transformationController,
                                minScale: 0.5,
                                maxScale: 3.8,
                                boundaryMargin: const EdgeInsets.all(80.0),
                                onInteractionUpdate: (_) => setState(() {}),
                                child: Center(
                                  child: _MinesweeperBoardView(
                                    vm: vm,
                                    maxWidth: constraints.maxWidth - 20,
                                    maxHeight: constraints.maxHeight - 20,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Floating Reset Zoom Button
                        if (scale > 1.08)
                          Positioned(
                            bottom: 14,
                            right: 14,
                            child: FloatingActionButton.small(
                              onPressed: _resetZoom,
                              tooltip: 'Về kích thước chuẩn',
                              backgroundColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              foregroundColor: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              elevation: 6,
                              child: const Icon(Icons.zoom_out_map_rounded,
                                  size: 18),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Bottom Action Button (Ván mới) ─────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _handleNewGameRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded,
                              size: 22, color: Colors.white),
                          label: const Text(
                            'Ván mới 💣',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Explosive Screen Red Flash Layer ──────────────────────
            AnimatedBuilder(
              animation: _explosionController,
              builder: (context, _) {
                final v = _explosionController.value;
                if (v <= 0 || v >= 1.0) return const SizedBox.shrink();
                double flashOpacity = 0.0;
                if (v < 0.15) {
                  flashOpacity = (v / 0.15) * 0.5;
                } else if (v < 0.55) {
                  flashOpacity = (1.0 - (v - 0.15) / 0.4) * 0.5;
                }
                return IgnorePointer(
                  child: Container(
                    color: const Color(0xFFEF4444)
                        .withValues(alpha: flashOpacity.clamp(0.0, 1.0)),
                  ),
                );
              },
            ),

            // ── Shockwave & Fire Particle Explosion Canvas ────────────
            AnimatedBuilder(
              animation: _explosionController,
              builder: (context, _) {
                final v = _explosionController.value;
                if (v <= 0 || v >= 1.0) return const SizedBox.shrink();
                return IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _ExplosionPainter(
                      progress: v,
                      particles: _particles,
                    ),
                  ),
                );
              },
            ),

            // ── Non-blocking Toast Banner ────────────────────────────────
            if (_toastMessage != null)
              Positioned(
                top: 70,
                left: 20,
                right: 20,
                child: _ToastBanner(message: _toastMessage!),
              ),

            // ── Pause Overlay ───────────────────────────────────────────
            if (vm.status == MinesweeperStatus.paused)
              _MinesweeperPauseOverlay(
                onResume: vm.togglePause,
                onNewGame: _handleNewGameRequest,
              ),

            // ── Victory Overlay ─────────────────────────────────────────
            if (vm.status == MinesweeperStatus.won)
              _MinesweeperVictoryOverlay(
                elapsed: vm.elapsedSeconds,
                bestTime: vm.stats.getBestTimeFor(vm.difficulty),
                difficultyLabel: vm.difficulty.label,
                onRestart: () => vm.startNewGame(),
                onChangeDifficulty: _showDifficultySheet,
                onExit: _handleBackPress,
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  EXPLOSION PARTICLE CLASS & CUSTOM PAINTER
// ───────────────────────────────────────────────────────────────────────────

class _ExplosionParticle {
  _ExplosionParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.decay,
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double decay;
}

class _ExplosionPainter extends CustomPainter {
  _ExplosionPainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_ExplosionParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Expanding Shockwave Ring (Sóng xung kích nổ)
    if (progress < 0.85) {
      final ringRadius = (progress / 0.85) * (size.width * 0.7);
      final ringOpacity = (1.0 - (progress / 0.85)).clamp(0.0, 1.0);

      final ringPaint = Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: ringOpacity * 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0 * (1.0 - progress);
      canvas.drawCircle(center, ringRadius, ringPaint);

      final innerRingPaint = Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: ringOpacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawCircle(center, ringRadius * 0.8, innerRingPaint);
    }

    // 2. Fire & Embers Particle Burst (Hạt lửa & khói nổ tung)
    final pPaint = Paint();
    for (final p in particles) {
      final distance = p.speed * progress;
      final dx = center.dx + cos(p.angle) * distance;
      final dy = center.dy + sin(p.angle) * distance + (progress * progress * 110); // Gravity
      final opacity = (1.0 - (progress / p.decay)).clamp(0.0, 1.0);
      final particleRadius = p.size * (1.0 - progress * 0.5);

      if (opacity > 0) {
        pPaint.color = p.color.withValues(alpha: opacity);
        canvas.drawCircle(Offset(dx, dy), particleRadius, pPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ExplosionPainter oldDelegate) => true;
}

// ───────────────────────────────────────────────────────────────────────────
//  HEADER (No-overflow responsive header for mobile)
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperHeader extends StatelessWidget {
  const _MinesweeperHeader({
    required this.difficulty,
    required this.soundMuted,
    required this.isPaused,
    required this.onBack,
    required this.onDifficultyTap,
    required this.onSoundToggle,
    required this.onPauseToggle,
  });

  final MinesweeperDifficulty difficulty;
  final bool soundMuted;
  final bool isPaused;
  final VoidCallback onBack;
  final VoidCallback onDifficultyTap;
  final VoidCallback onSoundToggle;
  final VoidCallback onPauseToggle;

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
            // Back Button
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

            // Title & Subtitle (Flexibly shrinking to prevent ANY horizontal overflow)
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFF59E0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('💣', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Dò Mìn Pro',
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
                          'Khám phá ô mìn',
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

            const SizedBox(width: 4),

            // Difficulty Chip Selector
            InkWell(
              onTap: onDifficultyTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : colors.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      difficulty.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFF8FAFC)
                            : colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: Color(0xFFEF4444)),
                  ],
                ),
              ),
            ),

            // Sound Toggle
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              tooltip: soundMuted ? 'Bật âm' : 'Tắt âm',
              onPressed: onSoundToggle,
              icon: Icon(
                soundMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                size: 19,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : colors.onSurfaceVariant,
              ),
            ),

            // Pause Button
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              tooltip: isPaused ? 'Tiếp tục' : 'Tạm dừng',
              onPressed: onPauseToggle,
              icon: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 20,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  STATUS BAR (HUD Timer & Flag Count)
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperStatusBar extends StatelessWidget {
  const _MinesweeperStatusBar({required this.vm});
  final MinesweeperViewModel vm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    final minutes = (vm.elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (vm.elapsedSeconds % 60).toString().padLeft(2, '0');

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
            width: 1,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Mine Counter Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('🚩', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 5),
                  Text(
                    '${vm.remainingFlags}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: vm.remainingFlags < 0
                          ? const Color(0xFFEF4444)
                          : (isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0284C7)),
                    ),
                  ),
                ],
              ),
            ),

            // Grid Size Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                      )
                    : LinearGradient(
                        colors: [
                          colors.primaryContainer,
                          colors.primaryContainer.withValues(alpha: 0.8)
                        ],
                      ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF818CF8)
                      : colors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${vm.currentCols}×${vm.currentRows} · ${vm.currentMines} 💣',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? const Color(0xFFC7D2FE)
                      : colors.onPrimaryContainer,
                ),
              ),
            ),

            // Timer Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 5),
                  Text(
                    '$minutes:$seconds',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isDark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFD97706),
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
//  TOUCH MODE TOGGLE (Mở ô vs Cắm cờ)
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperModeToggle extends StatelessWidget {
  const _MinesweeperModeToggle({required this.vm});
  final MinesweeperViewModel vm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : colors.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ToggleButton(
                selected: !vm.flagMode,
                icon: Icons.touch_app_rounded,
                label: 'Mở ô 🔍',
                activeGradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                unselectedColor:
                    isDark ? const Color(0xFF94A3B8) : colors.onSurfaceVariant,
                onTap: () {
                  if (vm.flagMode) {
                    HapticFeedback.selectionClick();
                    vm.toggleFlagMode();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _ToggleButton(
                selected: vm.flagMode,
                icon: Icons.flag_rounded,
                label: 'Cắm cờ 🚩',
                activeGradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                ),
                unselectedColor:
                    isDark ? const Color(0xFF94A3B8) : colors.onSurfaceVariant,
                onTap: () {
                  if (!vm.flagMode) {
                    HapticFeedback.selectionClick();
                    vm.toggleFlagMode();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.activeGradient,
    required this.unselectedColor,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final Gradient activeGradient;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: selected ? activeGradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: (activeGradient as LinearGradient)
                        .colors
                        .first
                        .withValues(alpha: 0.35),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : unselectedColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected ? Colors.white : unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  BOARD VIEW (Adaptive Light/Dark Board Container)
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperBoardView extends StatelessWidget {
  const _MinesweeperBoardView({
    required this.vm,
    required this.maxWidth,
    required this.maxHeight,
  });

  final MinesweeperViewModel vm;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    final cols = vm.currentCols;
    final rows = vm.currentRows;

    double cellSize;
    if (vm.difficulty == MinesweeperDifficulty.easy) {
      final idealW = (maxWidth - (cols - 1) * 3) / cols;
      final idealH = (maxHeight - (rows - 1) * 3) / rows;
      cellSize = min(idealW, idealH).clamp(34.0, 52.0);
    } else if (vm.difficulty == MinesweeperDifficulty.medium) {
      cellSize = 32.0;
    } else {
      cellSize = 30.0;
    }

    final boardW = cellSize * cols + (cols - 1) * 3;
    final boardH = cellSize * rows + (rows - 1) * 3;

    final isLost = vm.status == MinesweeperStatus.lost;
    final isWon = vm.status == MinesweeperStatus.won;

    Color borderColor =
        isDark ? const Color(0xFF334155) : colors.outlineVariant;
    if (isLost) borderColor = const Color(0xFFEF4444);
    if (isWon) borderColor = const Color(0xFF10B981);

    return Container(
      width: boardW + 16,
      height: boardH + 16,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: -3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: boardW,
          height: boardH,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: vm.board.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemBuilder: (context, index) {
              final cell = vm.board[index];
              final row = index ~/ cols;
              final col = index % cols;
              final isEven = (row + col) % 2 == 0;

              return Listener(
                onPointerDown: (event) {
                  if (event.buttons == kSecondaryButton) {
                    vm.toggleFlag(index);
                  }
                },
                child: _MineTile(
                  cell: cell,
                  cellSize: cellSize,
                  isEven: isEven,
                  onTap: () => vm.handleCellTap(index),
                  onLongPress: () {
                    HapticFeedback.lightImpact();
                    vm.toggleFlag(index);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  SINGLE MINE TILE (Adaptive Light/Dark Tactile Tile)
// ───────────────────────────────────────────────────────────────────────────

class _MineTile extends StatelessWidget {
  const _MineTile({
    required this.cell,
    required this.cellSize,
    required this.isEven,
    required this.onTap,
    required this.onLongPress,
  });

  final MineCell cell;
  final double cellSize;
  final bool isEven;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Gradient? bgGradient;
    Color? bgColor;
    Border border;
    List<BoxShadow>? shadows;

    if (cell.exploded) {
      bgGradient = const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      border = Border.all(color: const Color(0xFFFCA5A5), width: 1.5);
      shadows = [
        BoxShadow(
          color: const Color(0xFFEF4444).withValues(alpha: 0.6),
          blurRadius: 8,
        ),
      ];
    } else if (cell.isIncorrectFlag) {
      bgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5);
      border = Border.all(color: const Color(0xFFEF4444), width: 1.5);
    } else if (cell.state == CellState.revealed) {
      // REVEALED (Đã mở): Sunken Soft Muted Terrain Surface
      if (isDark) {
        bgColor = isEven ? const Color(0xFF0F172A) : const Color(0xFF090E17);
        border = Border.all(color: const Color(0xFF1E293B), width: 0.6);
      } else {
        // Light Mode: Soft Muted Powder Slate
        bgColor = isEven ? const Color(0xFFF0F4F8) : const Color(0xFFE4E9F0);
        border = Border.all(color: const Color(0xFFD9E2EC), width: 0.6);
      }
      shadows = null; // Flat sunken terrain
    } else {
      // UNREVEALED (Chưa mở - Hidden): Soothing 3D Muted Slate Keys (0% Glare)
      if (isDark) {
        // Dark Mode: Deep Muted Steel Blue 3D Keys
        bgGradient = LinearGradient(
          colors: isEven
              ? const [Color(0xFF334155), Color(0xFF293548)]
              : const [Color(0xFF2C394B), Color(0xFF212C3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        border = Border.all(color: const Color(0xFF475569), width: 1.0);
        shadows = [
          const BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 0,
            offset: Offset(0, 3.0),
          ),
        ];
      } else {
        // Light Mode: Soft Muted Nordic Blue-Slate Keys
        bgGradient = LinearGradient(
          colors: isEven
              ? const [Color(0xFFBCCCDC), Color(0xFF9FB3C8)]
              : const [Color(0xFFA6B9CB), Color(0xFF8DA4BC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        border = Border.all(color: const Color(0xFF829AB1), width: 1.0);
        shadows = [
          const BoxShadow(
            color: Color(0xFF627D98),
            blurRadius: 0,
            offset: Offset(0, 3.0),
          ),
        ];
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(cellSize > 36 ? 8 : 6),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(cellSize > 36 ? 8 : 6),
            border: border,
            boxShadow: shadows,
          ),
          child: Center(
            child: _buildCellContent(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(bool isDark) {
    if (cell.exploded) {
      return const Text('💥', style: TextStyle(fontSize: 16));
    }

    if (cell.isIncorrectFlag) {
      return const Text('❌', style: TextStyle(fontSize: 14));
    }

    if (cell.state == CellState.flagged) {
      return Text('🚩', style: TextStyle(fontSize: max(10, cellSize * 0.48)));
    }

    if (cell.state == CellState.revealed) {
      if (cell.isMine) {
        return Text('💣', style: TextStyle(fontSize: max(10, cellSize * 0.48)));
      }
      if (cell.adjacentMines > 0) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${cell.adjacentMines}',
            style: TextStyle(
              fontSize: max(12, cellSize * 0.52),
              fontWeight: FontWeight.w900,
              color: _getMineNumberColor(cell.adjacentMines, isDark),
            ),
          ),
        );
      }
      // Blank revealed tile: show a tiny subtle dot for visual confirmation
      return Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Color _getMineNumberColor(int number, bool isDark) {
    if (isDark) {
      switch (number) {
        case 1:
          return const Color(0xFF38BDF8); // Vibrant Cyan Blue
        case 2:
          return const Color(0xFF4ADE80); // Emerald Green
        case 3:
          return const Color(0xFFF87171); // Crimson Red
        case 4:
          return const Color(0xFFA855F7); // Royal Purple
        case 5:
          return const Color(0xFFFBBF24); // Amber Gold
        case 6:
          return const Color(0xFF2DD4BF); // Vibrant Teal
        case 7:
          return const Color(0xFFF1F5F9); // Crisp White
        case 8:
          return const Color(0xFF94A3B8); // Slate Gray
        default:
          return const Color(0xFF94A3B8);
      }
    } else {
      switch (number) {
        case 1:
          return const Color(0xFF0284C7); // Rich Royal Blue
        case 2:
          return const Color(0xFF16A34A); // Deep Emerald Green
        case 3:
          return const Color(0xFFDC2626); // Deep Crimson Red
        case 4:
          return const Color(0xFF7C3AED); // Deep Violet
        case 5:
          return const Color(0xFFD97706); // Dark Amber
        case 6:
          return const Color(0xFF0D9488); // Deep Teal
        case 7:
          return const Color(0xFF334155); // Dark Charcoal
        case 8:
          return const Color(0xFF64748B); // Slate Gray
        default:
          return const Color(0xFF64748B);
      }
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  PAUSE OVERLAY
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperPauseOverlay extends StatelessWidget {
  const _MinesweeperPauseOverlay({
    required this.onResume,
    required this.onNewGame,
  });

  final VoidCallback onResume;
  final VoidCallback onNewGame;

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
                  color: isDark ? const Color(0xFF7C3AED) : colors.primary),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.2),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pause_circle_rounded,
                    size: 56,
                    color: isDark ? const Color(0xFFA78BFA) : colors.primary),
                const SizedBox(height: 12),
                Text(
                  'Tạm Dừng',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Đồng hồ đang tạm dừng. Bấm tiếp tục để chơi tiếp.',
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
                        colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: onResume,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white),
                      label: const Text('Tiếp tục chơi',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onNewGame,
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
                    icon: Icon(Icons.refresh_rounded,
                        size: 18,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : colors.onSurfaceVariant),
                    label: Text('Ván mới',
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

// ───────────────────────────────────────────────────────────────────────────
//  VICTORY OVERLAY
// ───────────────────────────────────────────────────────────────────────────

class _MinesweeperVictoryOverlay extends StatelessWidget {
  const _MinesweeperVictoryOverlay({
    required this.elapsed,
    required this.bestTime,
    required this.difficultyLabel,
    required this.onRestart,
    required this.onChangeDifficulty,
    required this.onExit,
  });

  final int elapsed;
  final int bestTime;
  final String difficultyLabel;
  final VoidCallback onRestart;
  final VoidCallback onChangeDifficulty;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    final minutes = (elapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed % 60).toString().padLeft(2, '0');
    final isNewRecord = bestTime == elapsed;

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
                  color: const Color(0xFF10B981).withValues(alpha: 0.8),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 12),
                const Text(
                  'RÀ PHÁ THÀNH CÔNG!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Bạn đã tháo gỡ toàn bộ mìn ($difficultyLabel) trong $minutes:$seconds!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (isNewRecord) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Text(
                      '🏆 KỶ LỤC MỚI!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
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
                      label: const Text('Chơi ván tiếp',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onChangeDifficulty,
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
                    child: Text('Chọn độ khó khác',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFE2E8F0)
                                : colors.onSurface)),
                  ),
                ),
                const SizedBox(height: 6),
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
//  DIFFICULTY SELECTION BOTTOM SHEET
// ───────────────────────────────────────────────────────────────────────────

class _DifficultySelectionSheet extends StatelessWidget {
  const _DifficultySelectionSheet({required this.currentDifficulty});
  final MinesweeperDifficulty currentDifficulty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            'Chọn độ khó Dò Mìn 💣',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          for (final diff in MinesweeperDifficulty.values) ...[
            _DifficultyOptionTile(
              difficulty: diff,
              isSelected: currentDifficulty == diff,
              onTap: () => Navigator.pop(context, diff),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DifficultyOptionTile extends StatelessWidget {
  const _DifficultyOptionTile({
    required this.difficulty,
    required this.isSelected,
    required this.onTap,
  });

  final MinesweeperDifficulty difficulty;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                : colors.primaryContainer.withValues(alpha: 0.5))
            : (isDark ? const Color(0xFF1E293B) : colors.surfaceContainerLow),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? (isDark ? const Color(0xFF7C3AED) : colors.primary)
              : (isDark ? const Color(0xFF334155) : colors.outlineVariant),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)])
                : null,
            color: isSelected
                ? null
                : (isDark ? const Color(0xFF334155) : colors.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _getBadgeLabel(difficulty),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : colors.onSurface),
              ),
            ),
          ),
        ),
        title: Text(
          difficulty.label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: isDark ? Colors.white : colors.onSurface,
          ),
        ),
        subtitle: Text(
          difficulty.subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : colors.onSurfaceVariant,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded,
                color: isDark ? const Color(0xFFA78BFA) : colors.primary)
            : Icon(Icons.chevron_right_rounded,
                color: isDark ? const Color(0xFF64748B) : colors.outline),
      ),
    );
  }

  String _getBadgeLabel(MinesweeperDifficulty diff) {
    switch (diff) {
      case MinesweeperDifficulty.easy:
        return '9×9';
      case MinesweeperDifficulty.medium:
        return '16×16';
      case MinesweeperDifficulty.hard:
        return '16×30';
      case MinesweeperDifficulty.custom:
        return '⚙️';
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  CUSTOM DIFFICULTY DIALOG
// ───────────────────────────────────────────────────────────────────────────

class _CustomDifficultyDialog extends StatefulWidget {
  const _CustomDifficultyDialog({
    required this.initialRows,
    required this.initialCols,
    required this.initialMines,
  });

  final int initialRows;
  final int initialCols;
  final int initialMines;

  @override
  State<_CustomDifficultyDialog> createState() =>
      _CustomDifficultyDialogState();
}

class _CustomDifficultyDialogState extends State<_CustomDifficultyDialog> {
  late int rows;
  late int cols;
  late int mines;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    rows = widget.initialRows;
    cols = widget.initialCols;
    mines = widget.initialMines;
  }

  void _validate() {
    final maxMines = (rows * cols * 0.4).floor();
    if (rows < 6 || rows > 30) {
      errorMessage = 'Số hàng phải từ 6 đến 30';
    } else if (cols < 6 || cols > 30) {
      errorMessage = 'Số cột phải từ 6 đến 30';
    } else if (mines < 1 || mines > maxMines) {
      errorMessage = 'Số mìn phải từ 1 đến $maxMines cho bàn ${rows}x$cols';
    } else {
      errorMessage = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final maxMines = (rows * cols * 0.4).floor();

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF141B2D) : colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Bàn chơi Tùy chỉnh ⚙️',
        style: TextStyle(
            color: isDark ? Colors.white : colors.onSurface,
            fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số hàng: $rows',
                style: TextStyle(
                    color: isDark ? Colors.white : colors.onSurface,
                    fontWeight: FontWeight.w700)),
            Slider(
              value: rows.toDouble(),
              min: 6,
              max: 30,
              divisions: 24,
              activeColor: const Color(0xFFEF4444),
              inactiveColor: isDark
                  ? const Color(0xFF334155)
                  : colors.outlineVariant,
              label: '$rows',
              onChanged: (v) {
                rows = v.toInt();
                if (mines > maxMines) mines = maxMines;
                _validate();
              },
            ),
            const SizedBox(height: 8),
            Text('Số cột: $cols',
                style: TextStyle(
                    color: isDark ? Colors.white : colors.onSurface,
                    fontWeight: FontWeight.w700)),
            Slider(
              value: cols.toDouble(),
              min: 6,
              max: 30,
              divisions: 24,
              activeColor: const Color(0xFFEF4444),
              inactiveColor: isDark
                  ? const Color(0xFF334155)
                  : colors.outlineVariant,
              label: '$cols',
              onChanged: (v) {
                cols = v.toInt();
                if (mines > maxMines) mines = maxMines;
                _validate();
              },
            ),
            const SizedBox(height: 8),
            Text('Số mìn: $mines (Tối đa $maxMines)',
                style: TextStyle(
                    color: isDark ? Colors.white : colors.onSurface,
                    fontWeight: FontWeight.w700)),
            Slider(
              value: mines.toDouble().clamp(1.0, maxMines.toDouble()),
              min: 1,
              max: maxMines.toDouble(),
              divisions: max(1, maxMines - 1),
              activeColor: const Color(0xFFF59E0B),
              inactiveColor: isDark
                  ? const Color(0xFF334155)
                  : colors.outlineVariant,
              label: '$mines',
              onChanged: (v) {
                mines = v.toInt();
                _validate();
              },
            ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy',
              style: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : colors.onSurfaceVariant)),
        ),
        FilledButton(
          onPressed: errorMessage == null
              ? () => Navigator.pop(
                  context, {'rows': rows, 'cols': cols, 'mines': mines})
              : null,
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444)),
          child: const Text('Tạo bàn'),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  RESUME SAVED GAME SHEET
// ───────────────────────────────────────────────────────────────────────────

class _ResumeGameSheet extends StatelessWidget {
  const _ResumeGameSheet({
    required this.savedState,
    required this.onResume,
    required this.onNewGame,
  });

  final MinesweeperSavedState savedState;
  final VoidCallback onResume;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    final minutes =
        (savedState.elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds =
        (savedState.elapsedSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
          Icon(Icons.bookmark_rounded,
              size: 44,
              color: isDark ? const Color(0xFFA78BFA) : colors.primary),
          const SizedBox(height: 12),
          Text(
            'Tiếp tục ván chơi dở?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bàn ${savedState.cols}×${savedState.rows} · ${savedState.minesCount} mìn · Thời gian: $minutes:$seconds',
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
                  colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                ),
              ),
              child: ElevatedButton(
                onPressed: onResume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Tiếp tục ván đang chơi',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onNewGame,
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
                'Bắt đầu ván mới',
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

// ───────────────────────────────────────────────────────────────────────────
//  NEW GAME CONFIRMATION SHEET
// ───────────────────────────────────────────────────────────────────────────

class _NewGameConfirmationSheet extends StatelessWidget {
  const _NewGameConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              size: 40, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          Text(
            'Bắt đầu ván mới?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tiến trình ván Dò Mìn hiện tại sẽ bị xóa.',
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
                  colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
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
                'Tiếp tục chơi ván cũ',
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

// ───────────────────────────────────────────────────────────────────────────
//  TOAST BANNER
// ───────────────────────────────────────────────────────────────────────────

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
                    color: Color(0xFFA78BFA), size: 18),
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
