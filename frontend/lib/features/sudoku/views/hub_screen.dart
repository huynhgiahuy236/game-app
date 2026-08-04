import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/games/game_metadata.dart';
import '../../../core/theme/app_theme.dart';
import '../../game_2048/services/game_2048_repository.dart';
import '../../game_2048/views/game_2048_screen.dart';
import '../models/sudoku_models.dart';
import '../services/sudoku_repository.dart';
import 'sudoku_game_screen.dart';
import '../../caro/services/caro_repository.dart';
import '../../caro/views/caro_game_screen.dart';
import '../../minesweeper/services/minesweeper_repository.dart';
import '../../minesweeper/views/minesweeper_game_screen.dart';
import '../../monopoly/services/monopoly_repository.dart';
import '../../monopoly/views/monopoly_game_screen.dart';
import '../../block_puzzle/services/block_puzzle_repository.dart';
import '../../block_puzzle/views/block_puzzle_screen.dart';
import '../../auth/services/auth_repository.dart';
import '../../settings/views/app_settings_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  HubScreen — root nav (3 tabs)
// ═══════════════════════════════════════════════════════════════════════════

class HubScreen extends StatefulWidget {
  const HubScreen({
    super.key,
    required this.repository,
    required this.game2048Repository,
    required this.caroRepository,
    required this.minesweeperRepository,
    required this.monopolyRepository,
    required this.blockPuzzleRepository,
    required this.onThemeChanged,
    this.authRepository,
  });
  final SudokuRepository repository;
  final Game2048Repository game2048Repository;
  final CaroRepository caroRepository;
  final MinesweeperRepository minesweeperRepository;
  final MonopolyRepository monopolyRepository;
  final BlockPuzzleRepository blockPuzzleRepository;
  final ValueChanged<ThemeMode> onThemeChanged;
  final AuthRepository? authRepository;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin {
  SudokuGame? saved;
  SudokuStats stats = SudokuStats();
  int best2048 = 0;
  List<int> scoreHistory2048 = const [];
  bool loading = true;
  int selectedTab = 0;
  late final AnimationController _navAnimCtrl;

  @override
  void initState() {
    super.initState();
    _navAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _load();
  }

  @override
  void dispose() {
    _navAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    saved = await widget.repository.loadGame();
    stats = await widget.repository.loadStats();
    best2048 = await widget.game2048Repository.bestScore();
    scoreHistory2048 = await widget.game2048Repository.scoreHistory();
    if (mounted) setState(() => loading = false);
    if (!await widget.repository.tutorialSeen() && mounted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showTutorial());
    }
  }

  Future<void> _showTutorial() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _TutorialSheet(),
    );
    await widget.repository.markTutorialSeen();
  }

  Future<void> _chooseDifficulty() async {
    final lastDifficulty = await widget.repository.loadLastDifficulty();
    if (!mounted) return;
    final difficulty = await showModalBottomSheet<Difficulty>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SudokuDifficultySheet(
        initialDifficulty: lastDifficulty,
        stats: stats,
      ),
    );
    if (difficulty != null && mounted) {
      await widget.repository.saveLastDifficulty(difficulty);
      if (mounted) {
        await SudokuGameScreen.startNew(
            context, widget.repository, difficulty);
        _load();
      }
    }
  }

  Future<void> _handleSudokuPlay() async {
    if (saved != null) {
      final choice = await showModalBottomSheet<_SudokuStartChoice>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _ContinueOrNewGameSheet(saved: saved!),
      );
      if (choice == _SudokuStartChoice.continueGame && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SudokuGameScreen(
              repository: widget.repository,
              initialGame: saved!,
            ),
          ),
        );
        _load();
      } else if (choice == _SudokuStartChoice.newGame && mounted) {
        await _chooseDifficulty();
      }
    } else {
      await _chooseDifficulty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = <Widget>[
      _GamesTab(
        loading: loading,
        saved: saved,
        best2048: best2048,
        onSudokuNew: _chooseDifficulty,
        onSudokuContinue: saved == null ? null : _handleSudokuPlay,
        onPlay2048: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  Game2048Screen(repository: widget.game2048Repository),
            ),
          );
          _load();
        },
        onPlayCaro: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CaroGameScreen(repository: widget.caroRepository),
            ),
          );
          _load();
        },
        onPlayMinesweeper: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MinesweeperGameScreen(
                  repository: widget.minesweeperRepository),
            ),
          );
          _load();
        },
        onPlayMonopoly: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MonopolyGameScreen(
                  repository: widget.monopolyRepository),
            ),
          );
          _load();
        },
        onPlayBlockPuzzle: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlockPuzzleScreen(
                  repository: widget.blockPuzzleRepository),
            ),
          );
          _load();
        },
      ),
      _StatsTab(
        stats: stats,
        best2048: best2048,
        scoreHistory: scoreHistory2048,
      ),
      AppSettingsScreen(
        currentModule: 'games',
        onThemeChanged: widget.onThemeChanged,
        authRepository: widget.authRepository,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(selectedTab),
          child: pages[selectedTab],
        ),
      ),
      bottomNavigationBar: _PremiumNavBar(
        selectedIndex: selectedTab,
        isDark: isDark,
        onChanged: (i) => setState(() => selectedTab = i),
      ),
    );
  }
}

// ─── Premium Navigation Bar ──────────────────────────────────────────────────

class _PremiumNavBar extends StatelessWidget {
  const _PremiumNavBar({
    required this.selectedIndex,
    required this.isDark,
    required this.onChanged,
  });
  final int selectedIndex;
  final bool isDark;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D1326).withValues(alpha: 0.95)
            : colors.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: isDark
                ? colors.primary.withValues(alpha: 0.15)
                : colors.outlineVariant,
            width: 1,
          ),
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ]
            : [],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.sports_esports_outlined,
                activeIcon: Icons.sports_esports_rounded,
                label: 'Trò chơi',
                selected: selectedIndex == 0,
                onTap: () => onChanged(0),
              ),
              _NavItem(
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events_rounded,
                label: 'Thành tích',
                selected: selectedIndex == 1,
                onTap: () => onChanged(1),
              ),
              _NavItem(
                icon: Icons.tune_outlined,
                activeIcon: Icons.tune_rounded,
                label: 'Cài đặt',
                selected: selectedIndex == 2,
                onTap: () => onChanged(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: selected ? 48 : 0,
                height: selected ? 30 : 0,
                decoration: selected
                    ? BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 20,
                  color: selected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ),
              if (!selected) ...[
                Icon(icon, size: 22, color: colors.onSurfaceVariant),
                const SizedBox(height: 2),
              ],
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 1 — TRÒ CHƠI  (full redesign)
// ═══════════════════════════════════════════════════════════════════════════

class _GamesTab extends StatefulWidget {
  const _GamesTab({
    required this.loading,
    required this.saved,
    required this.best2048,
    required this.onSudokuNew,
    required this.onSudokuContinue,
    required this.onPlay2048,
    required this.onPlayCaro,
    required this.onPlayMinesweeper,
    required this.onPlayMonopoly,
    required this.onPlayBlockPuzzle,
  });
  final bool loading;
  final SudokuGame? saved;
  final int best2048;
  final VoidCallback onSudokuNew;
  final VoidCallback? onSudokuContinue;
  final VoidCallback onPlay2048;
  final VoidCallback onPlayCaro;
  final VoidCallback onPlayMinesweeper;
  final VoidCallback onPlayMonopoly;
  final VoidCallback onPlayBlockPuzzle;

  @override
  State<_GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<_GamesTab>
    with SingleTickerProviderStateMixin {
  int selectedCategory = 0;
  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        // ── Fancy header ──────────────────────────────────────
        SliverToBoxAdapter(
          child: _HeroHeader(isDark: isDark),
        ),

        // ── Stats strip ───────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _StatsStrip(best2048: widget.best2048),
          ),
        ),

        // ── Category chips ────────────────────────────────────
        SliverToBoxAdapter(
          child: _CategoryRow(
            selected: selectedCategory,
            onChanged: (i) => setState(() => selectedCategory = i),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Game cards ────────────────────────────────────────
        if (widget.loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.separated(
              separatorBuilder: (ctx, sep) => const SizedBox(height: 12),
              itemCount: _visibleCards(selectedCategory).length,
              itemBuilder: (context, i) {
                final cards = _visibleCards(selectedCategory);
                return _StaggeredCard(
                  index: i,
                  controller: _staggerCtrl,
                  child: cards[i],
                );
              },
            ),
          ),
      ],
    );
  }

  List<Widget> _visibleCards(int cat) {
    final all = <Widget>[
      if (cat == 0 || cat == 1) ...[
        _GameCard(
          assetPath: 'assets/logo_game/sudoku.png',
          name: sudokuMetadata.name,
          description: widget.saved != null
              ? 'Có ván đang chơi dở'
              : sudokuMetadata.description,
          tag: 'Logic',
          tagColor: const Color(0xFF7C3AED),
          gradient: AppGradients.violetCyan,
          onPlay: widget.saved != null
              ? widget.onSudokuContinue!
              : widget.onSudokuNew,
          playLabel: widget.saved != null ? 'Tiếp tục' : 'Chơi',
          isHot: false,
        ),
        _GameCard(
          assetPath: 'assets/logo_game/2048.jpg',
          name: game2048Metadata.name,
          description: widget.best2048 > 0
              ? 'Kỷ lục: ${widget.best2048} điểm'
              : game2048Metadata.description,
          tag: 'Logic',
          tagColor: const Color(0xFF7C3AED),
          gradient: AppGradients.goldAmber,
          onPlay: widget.onPlay2048,
          playLabel: 'Chơi',
          isHot: true,
        ),
        _GameCard(
          assetPath: 'assets/logo_game/do-min.png',
          name: minesweeperMetadata.name,
          description: minesweeperMetadata.description,
          tag: 'Logic',
          tagColor: const Color(0xFF7C3AED),
          gradient: AppGradients.emeraldTeal,
          onPlay: widget.onPlayMinesweeper,
          playLabel: 'Chơi',
          isHot: false,
        ),
      ],
      if (cat == 0 || cat == 1) ...[
        _GameCard(
          assetPath: 'assets/logo_game/Block Puzzle.png',
          name: blockPuzzleMetadata.name,
          description: blockPuzzleMetadata.description,
          tag: 'Logic',
          tagColor: const Color(0xFF0D9488),
          gradient: AppGradients.emeraldTeal,
          onPlay: widget.onPlayBlockPuzzle,
          playLabel: 'Chơi',
          isHot: true,
        ),
      ],
      if (cat == 0 || cat == 2) ...[
        _GameCard(
          assetPath: 'assets/logo_game/ox.jpg',
          name: caroMetadata.name,
          description: caroMetadata.description,
          tag: 'Chiến thuật',
          tagColor: const Color(0xFF0891B2),
          gradient: AppGradients.roseGold,
          onPlay: widget.onPlayCaro,
          playLabel: 'Chơi',
          isHot: false,
        ),
        _GameCard(
          assetPath: 'assets/logo_game/co ty phu.jpg',
          name: monopolyMetadata.name,
          description: monopolyMetadata.description,
          tag: 'Chiến thuật',
          tagColor: const Color(0xFF0891B2),
          gradient: AppGradients.goldAmber,
          onPlay: widget.onPlayMonopoly,
          playLabel: 'Chơi',
          isHot: true,
        ),
      ],
    ];
    return all;
  }
}

// ─── Hero Header ─────────────────────────────────────────────────────────────

class _HeroHeader extends StatefulWidget {
  const _HeroHeader({required this.isDark});
  final bool isDark;

  @override
  State<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<_HeroHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 52, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF1C1038), Color(0xFF0D1326)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFEDE9FE), Color(0xFFCFF1FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: isDark
              ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
              : const Color(0xFF7C3AED).withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 28,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
          // Logo with glow
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/logo.jpg',
                fit: BoxFit.cover,
                width: 56,
                height: 56,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (context, _) {
                    return ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFFA78BFA),
                                  const Color(0xFF22D3EE),
                                  const Color(0xFFA78BFA),
                                ]
                              : [
                                  const Color(0xFF6D28D9),
                                  const Color(0xFF0891B2),
                                  const Color(0xFF6D28D9),
                                ],
                          stops: [
                            (_shimmer.value - 0.3).clamp(0.0, 1.0),
                            _shimmer.value.clamp(0.0, 1.0),
                            (_shimmer.value + 0.3).clamp(0.0, 1.0),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds);
                      },
                      child: const Text(
                        'Chị Mười',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Bộ sưu tập game trí tuệ đỉnh cao ✨',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF9B9EC8)
                        : const Color(0xFF4B5478),
                  ),
                ),
              ],
            ),
          ),
          // Star burst decoration
          _PulsingDot(isDark: isDark),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.isDark});
  final bool isDark;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF22D3EE),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22D3EE).withValues(alpha: _ctrl.value * 0.6 + 0.2),
                blurRadius: _ctrl.value * 12 + 4,
                spreadRadius: _ctrl.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Stats Strip ─────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.best2048});
  final int best2048;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? const Color(0xFF141B2D)
            : colors.surfaceContainerLow,
        border: Border.all(
          color: isDark
              ? colors.primary.withValues(alpha: 0.12)
              : colors.outlineVariant,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatPill(
              icon: Icons.sports_esports_rounded,
              label: '5 Game',
              color: const Color(0xFF7C3AED),
            ),
            VerticalDivider(
              width: 24,
              thickness: 1,
              color: isDark
                  ? colors.outlineVariant
                  : colors.outlineVariant,
            ),
            _StatPill(
              icon: Icons.star_rounded,
              label: '2048: $best2048',
              color: const Color(0xFFF59E0B),
            ),
            VerticalDivider(
              width: 24,
              thickness: 1,
              color: colors.outlineVariant,
            ),
            _StatPill(
              icon: Icons.wifi_off_rounded,
              label: 'Offline',
              color: const Color(0xFF10B981),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Row ─────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _CatChip(label: '✨ Tất cả', active: selected == 0,
              onTap: () => onChanged(0)),
          const SizedBox(width: 8),
          _CatChip(label: '🧩 Logic', active: selected == 1,
              onTap: () => onChanged(1)),
          const SizedBox(width: 8),
          _CatChip(label: '⚔️ Chiến thuật', active: selected == 2,
              onTap: () => onChanged(2)),
        ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? (isDark
                  ? const Color(0xFF3B1F6E)
                  : colors.primaryContainer)
              : (isDark
                  ? const Color(0xFF141B2D)
                  : colors.surfaceContainerLow),
          border: Border.all(
            color: active
                ? (isDark
                    ? const Color(0xFF7C3AED)
                    : colors.primary)
                : colors.outlineVariant,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active && isDark
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active
                ? (isDark ? const Color(0xFFA78BFA) : colors.primary)
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Game Card ───────────────────────────────────────────────────────────────

class _GameCard extends StatefulWidget {
  const _GameCard({
    required this.assetPath,
    required this.name,
    required this.description,
    required this.tag,
    required this.tagColor,
    required this.gradient,
    required this.onPlay,
    required this.playLabel,
    required this.isHot,
  });

  final String assetPath;
  final String name;
  final String description;
  final String tag;
  final Color tagColor;
  final Gradient gradient;
  final VoidCallback onPlay;
  final String playLabel;
  final bool isHot;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressed = true;
    _pressCtrl.reverse();
  }

  void _onTapUp(TapUpDetails _) {
    _release();
    widget.onPlay();
  }

  void _onTapCancel() => _release();

  void _release() {
    if (_pressed) {
      _pressed = false;
      _pressCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _pressCtrl,
      builder: (context, child) => Transform.scale(
        scale: _pressCtrl.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark
                ? const Color(0xFF141B2D)
                : colors.surfaceContainerLow,
            border: Border.all(
              color: isDark
                  ? colors.primary.withValues(alpha: 0.12)
                  : colors.outlineVariant,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: widget.tagColor.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Image with gradient side accent
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(19),
                      bottomLeft: Radius.circular(19),
                    ),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: widget.gradient,
                      ),
                      child: Image.asset(
                        widget.assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => const Icon(
                          Icons.games_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  // HOT badge
                  if (widget.isHot)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🔥 HOT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tag chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.tagColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.tag,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: widget.tagColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Play button
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _GradientPlayButton(
                  label: widget.playLabel,
                  gradient: widget.gradient,
                  onTap: widget.onPlay,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientPlayButton extends StatelessWidget {
  const _GradientPlayButton({
    required this.label,
    required this.gradient,
    required this.onTap,
  });
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient)
                  .colors
                  .first
                  .withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ─── Staggered Card Animation ─────────────────────────────────────────────────

class _StaggeredCard extends StatelessWidget {
  const _StaggeredCard({
    required this.index,
    required this.controller,
    required this.child,
  });
  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.1).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 2 — THÀNH TÍCH
// ═══════════════════════════════════════════════════════════════════════════

class _StatsTab extends StatelessWidget {
  const _StatsTab({
    required this.stats,
    required this.best2048,
    required this.scoreHistory,
  });
  final SudokuStats stats;
  final int best2048;
  final List<int> scoreHistory;

  void _showSudokuDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(20),
          children: [
            _DragHandle(),
            const SizedBox(height: 16),
            Text('Thành tích Sudoku',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            _SudokuOverviewCard(stats: stats),
            const SizedBox(height: 12),
            _SudokuDifficultyChart(stats: stats),
            const SizedBox(height: 12),
            _SudokuBestTimesChart(stats: stats),
          ],
        ),
      ),
    );
  }

  void _show2048Detail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(20),
          children: [
            _DragHandle(),
            const SizedBox(height: 16),
            Text('Thành tích 2048',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            _Game2048OverviewCard(best: best2048),
            const SizedBox(height: 12),
            _Game2048ScoreChart(history: scoreHistory),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completion = stats.started == 0
        ? 0
        : (stats.completed * 100 / stats.started).round();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Thành tích',
            subtitle: 'Theo dõi hành trình chinh phục',
            isDark: isDark,
          ),
        ),

        // XP ring card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _XPCard(
              completion: completion,
              completed: stats.completed,
              started: stats.started,
              best2048: best2048,
              isDark: isDark,
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _SectionLabel('Trò chơi'),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _StatsGameCard(
                title: 'Sudoku',
                subtitle:
                    'Thắng ${stats.completed} ván • Tỉ lệ $completion%',
                assetPath: 'assets/logo_game/sudoku.png',
                accentColor: const Color(0xFF7C3AED),
                onTap: () => _showSudokuDetail(context),
              ),
              const SizedBox(height: 10),
              _StatsGameCard(
                title: '2048',
                subtitle: 'Kỷ lục: $best2048 điểm',
                assetPath: 'assets/logo_game/2048.jpg',
                accentColor: const Color(0xFFF59E0B),
                onTap: () => _show2048Detail(context),
              ),
              const SizedBox(height: 10),
              _StatsGameCard(
                title: 'Dò Mìn',
                subtitle: 'Phiêu lưu với mìn không thương tiếc 💣',
                assetPath: 'assets/logo_game/do-min.png',
                accentColor: const Color(0xFF10B981),
                onTap: () {},
              ),
              const SizedBox(height: 10),
              _StatsGameCard(
                title: 'Cờ Caro',
                subtitle: 'Đấu trí với AI hoặc bạn bè',
                assetPath: 'assets/logo_game/ox.jpg',
                accentColor: const Color(0xFF0891B2),
                onTap: () {},
              ),
              const SizedBox(height: 10),
              _StatsGameCard(
                title: 'Cờ Tỷ Phú',
                subtitle: 'Làm giàu nhanh nhất Việt Nam 🏙️',
                assetPath: 'assets/logo_game/co ty phu.jpg',
                accentColor: const Color(0xFFEF4444),
                onTap: () {},
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _XPCard extends StatelessWidget {
  const _XPCard({
    required this.completion,
    required this.completed,
    required this.started,
    required this.best2048,
    required this.isDark,
  });
  final int completion;
  final int completed;
  final int started;
  final int best2048;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF1C1038), Color(0xFF0D1326)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  const Color(0xFF6D28D9).withValues(alpha: 0.08),
                  const Color(0xFF0891B2).withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: isDark
              ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
              : const Color(0xFF7C3AED).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: _RingPainter(
                progress: completion / 100,
                ringColor: const Color(0xFF7C3AED),
                trackColor: isDark
                    ? const Color(0xFF252847)
                    : const Color(0xFFEDE9FE),
              ),
              child: Center(
                child: Text(
                  '$completion%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? const Color(0xFFA78BFA)
                        : const Color(0xFF6D28D9),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientText(
                  'Chiến binh Trí tuệ',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA78BFA), Color(0xFF22D3EE)],
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                _MiniStat(
                  label: 'Sudoku hoàn thành',
                  value: '$completed/$started',
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(height: 3),
                _MiniStat(
                  label: 'Điểm 2048 cao nhất',
                  value: '$best2048',
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });
  final double progress;
  final Color ringColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 6;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final ringPaint = Paint()
      ..shader = LinearGradient(
        colors: [ringColor, const Color(0xFF22D3EE)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress;
}

class _StatsGameCard extends StatelessWidget {
  const _StatsGameCard({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.accentColor,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String assetPath;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: isDark ? const Color(0xFF141B2D) : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                  ),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.2),
                            blurRadius: 10,
                          )
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset(assetPath, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Shared Helpers
// ═══════════════════════════════════════════════════════════════════════════


class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            title,
            gradient: const LinearGradient(
              colors: [Color(0xFFA78BFA), Color(0xFF22D3EE)],
            ),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? const Color(0xFF9B9EC8)
                  : const Color(0xFF4B5478),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.5,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Stats Detail Charts (Sudoku + 2048)
// ═══════════════════════════════════════════════════════════════════════════

class _SudokuOverviewCard extends StatelessWidget {
  const _SudokuOverviewCard({required this.stats});
  final SudokuStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completion = stats.started == 0
        ? 0
        : (stats.completed * 100 / stats.started).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.insights_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Text('Tổng quan',
                  style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                    child: _MetricCell(
                        label: 'Bắt đầu', value: '${stats.started}')),
                Expanded(
                    child: _MetricCell(
                        label: 'Hoàn thành',
                        value: '${stats.completed}')),
                Expanded(
                    child: _MetricCell(
                        label: 'Tỉ lệ', value: '$completion%')),
                Expanded(
                    child: _MetricCell(
                        label: 'Streak', value: '${stats.bestStreak}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SudokuDifficultyChart extends StatelessWidget {
  const _SudokuDifficultyChart({required this.stats});
  final SudokuStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = <_ChartEntry>[
      for (final d in Difficulty.values)
        _ChartEntry(
          label: d.label,
          started: stats.startedByDifficulty[d.name] ?? 0,
          completed: stats.completedByDifficulty[d.name] ?? 0,
        ),
    ];
    final hasData = entries.any((e) => e.started > 0 || e.completed > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bar_chart_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Ván theo độ khó',
                      style: Theme.of(context).textTheme.titleLarge)),
              _LegendDot(color: colors.primary, label: 'Bắt đầu'),
              const SizedBox(width: 8),
              _LegendDot(color: colors.tertiary, label: 'Hoàn thành'),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: hasData
                  ? _BarChart(
                      entries: entries,
                      primary: colors.primary,
                      accent: colors.tertiary,
                      track: colors.surfaceContainer,
                      labelColor: colors.onSurfaceVariant,
                      maxValue: _max(entries),
                    )
                  : _EmptyChart(
                      message: 'Chưa có ván Sudoku nào',
                      icon: Icons.bar_chart_rounded),
            ),
          ],
        ),
      ),
    );
  }

  int _max(List<_ChartEntry> entries) {
    var m = 1;
    for (final e in entries) {
      if (e.started > m) m = e.started;
      if (e.completed > m) m = e.completed;
    }
    return m;
  }
}

class _SudokuBestTimesChart extends StatelessWidget {
  const _SudokuBestTimesChart({required this.stats});
  final SudokuStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = <_ChartEntry>[
      for (final d in Difficulty.values)
        _ChartEntry(
          label: d.label,
          started: stats.bestTimes[d.name] ?? 0,
          completed: 0,
        ),
    ];
    final hasData = entries.any((e) => e.started > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.timer_outlined, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Kỷ lục thời gian',
                      style: Theme.of(context).textTheme.titleLarge)),
              _LegendDot(color: colors.tertiary, label: 'Giây'),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: hasData
                  ? _BarChart(
                      entries: entries,
                      primary: colors.tertiary,
                      accent: colors.tertiary,
                      track: colors.surfaceContainer,
                      labelColor: colors.onSurfaceVariant,
                      maxValue: _max(entries),
                      single: true,
                      formatValue: (v) => _formatTime(v),
                    )
                  : _EmptyChart(
                      message: 'Chưa hoàn thành ván nào',
                      icon: Icons.timer_outlined),
            ),
          ],
        ),
      ),
    );
  }

  int _max(List<_ChartEntry> entries) {
    var m = 1;
    for (final e in entries) {
      if (e.started > m) m = e.started;
    }
    return m;
  }
}

class _Game2048OverviewCard extends StatelessWidget {
  const _Game2048OverviewCard({required this.best});
  final int best;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.crop_square_rounded,
                  color: colors.onTertiaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kỷ lục 2048',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text('Điểm cao nhất',
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
            Text('$best',
                style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}

class _Game2048ScoreChart extends StatelessWidget {
  const _Game2048ScoreChart({required this.history});
  final List<int> history;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = <_ChartEntry>[
      for (var i = 0; i < history.length; i++)
        _ChartEntry(label: '${i + 1}', started: history[i], completed: 0),
    ];
    final hasData = entries.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.show_chart_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Lịch sử điểm',
                      style: Theme.of(context).textTheme.titleLarge)),
              _LegendDot(
                  color: colors.tertiary,
                  label: 'Ván ${entries.length}'),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: hasData
                  ? _BarChart(
                      entries: entries,
                      primary: colors.tertiary,
                      accent: colors.tertiary,
                      track: colors.surfaceContainer,
                      labelColor: colors.onSurfaceVariant,
                      maxValue: _maxChart(entries),
                      single: true,
                      formatValue: (v) => '$v',
                    )
                  : _EmptyChart(
                      message: 'Chưa có ván 2048 nào',
                      icon: Icons.show_chart_rounded),
            ),
          ],
        ),
      ),
    );
  }

  int _maxChart(List<_ChartEntry> entries) {
    var m = 1;
    for (final e in entries) {
      if (e.started > m) m = e.started;
    }
    return m;
  }
}

// ─── Chart primitives ────────────────────────────────────────────────────────

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color:
                  Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
}

class _ChartEntry {
  const _ChartEntry({
    required this.label,
    required this.started,
    required this.completed,
  });
  final String label;
  final int started;
  final int completed;
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.entries,
    required this.primary,
    required this.accent,
    required this.track,
    required this.labelColor,
    required this.maxValue,
    this.single = false,
    this.formatValue,
  });
  final List<_ChartEntry> entries;
  final Color primary;
  final Color accent;
  final Color track;
  final Color labelColor;
  final int maxValue;
  final bool single;
  final String Function(int v)? formatValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final e in entries)
          Expanded(
            child: _Bar(
              entry: e,
              maxValue: maxValue,
              primary: primary,
              accent: accent,
              track: track,
              labelColor: labelColor,
              single: single,
              formatValue: formatValue,
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.entry,
    required this.maxValue,
    required this.primary,
    required this.accent,
    required this.track,
    required this.labelColor,
    required this.single,
    this.formatValue,
  });
  final _ChartEntry entry;
  final int maxValue;
  final Color primary;
  final Color accent;
  final Color track;
  final Color labelColor;
  final bool single;
  final String Function(int v)? formatValue;

  @override
  Widget build(BuildContext context) {
    final h1 = entry.started;
    final h2 = single ? 0 : entry.completed;
    final v1 = h1 / maxValue;
    final v2 = h2 / maxValue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            h1 > 0 ? formatValue?.call(h1) ?? '$h1' : '',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: labelColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                    child: _AnimatedBar(
                        fraction: v1, color: primary, track: track)),
                if (!single) ...[
                  const SizedBox(width: 3),
                  Expanded(
                      child: _AnimatedBar(
                          fraction: v2, color: accent, track: track)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBar extends StatefulWidget {
  const _AnimatedBar({
    required this.fraction,
    required this.color,
    required this.track,
  });
  final double fraction;
  final Color color;
  final Color track;

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim =
        Tween<double>(begin: 0, end: widget.fraction.clamp(0.0, 1.0))
            .animate(CurvedAnimation(
                parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedBar old) {
    super.didUpdateWidget(old);
    if (old.fraction != widget.fraction) {
      _anim = Tween<double>(
        begin: old.fraction.clamp(0.0, 1.0),
        end: widget.fraction.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
          parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: c.maxHeight,
              decoration: BoxDecoration(
                color: widget.track,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Container(
              height: c.maxHeight * _anim.value,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message, required this.icon});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: colors.outline),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(
                  color: colors.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }
}

String _formatTime(int seconds) {
  final m = seconds ~/ 60, s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════════════════════════════════
//  Difficulty Sheet + Tutorial Sheet
// ═══════════════════════════════════════════════════════════════════════════

enum _SudokuStartChoice { continueGame, newGame }

class _ContinueOrNewGameSheet extends StatelessWidget {
  const _ContinueOrNewGameSheet({required this.saved});
  final SudokuGame saved;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            Text(
              'Tiếp tục ván chơi?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bạn đang có một ván Sudoku chưa hoàn thành.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141B2D) : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.grid_3x3_rounded, color: colors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Độ khó: ${saved.difficulty.label}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Thời gian: ${formatTime(saved.elapsedSeconds)} • Lỗi: ${saved.mistakes}/${saved.mistakeLimit}',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _SudokuStartChoice.continueGame),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Tiếp tục ván đang chơi', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, _SudokuStartChoice.newGame),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: colors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Chơi ván mới', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class SudokuDifficultySheet extends StatefulWidget {
  const SudokuDifficultySheet({
    super.key,
    this.initialDifficulty = Difficulty.easy,
    this.stats,
  });
  final Difficulty initialDifficulty;
  final SudokuStats? stats;

  @override
  State<SudokuDifficultySheet> createState() => _SudokuDifficultySheetState();
}

class _SudokuDifficultySheetState extends State<SudokuDifficultySheet> {
  late Difficulty selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initialDifficulty;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            Text(
              'Chọn độ khó',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Chọn cấp độ phù hợp để bắt đầu ván mới.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ...Difficulty.values.map(
              (d) {
                final isSelected = selected == d;
                final bestTime = widget.stats?.bestTimes[d.name];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primaryContainer.withValues(alpha: isDark ? 0.4 : 0.8)
                          : (isDark ? const Color(0xFF141B2D) : colors.surfaceContainer),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? colors.primary : colors.outlineVariant.withValues(alpha: 0.5),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => selected = d),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? colors.primary : colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          d.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: isSelected ? colors.primary : colors.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          d.challengeStars,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFF59E0B),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      d.description,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (bestTime != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Kỷ lục: ${formatTime(bestTime)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: const Text('Bắt đầu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialSheet extends StatelessWidget {
  const _TutorialSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text('Cách chơi Sudoku',
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              const _Tip(Icons.grid_3x3_rounded,
                  'Mỗi hàng, cột và ô vuông 3×3 chứa đủ các số 1–9.'),
              const _Tip(Icons.edit_note_rounded,
                  'Bật Ghi chú để lưu các ứng viên nhỏ trong ô.'),
              const _Tip(Icons.lightbulb_outline_rounded,
                  'Dùng tối đa 3 gợi ý; sai 3 lần sẽ kết thúc lượt.'),
              const _Tip(Icons.keyboard_rounded,
                  'Máy tính: phím mũi tên, 1–9, N, H, P và Ctrl/Cmd+Z.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đã hiểu'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(icon, color: colors.onPrimaryContainer, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text,
                  style: const TextStyle(height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Exposed brand header (used by other screens if needed).
class AppBrandHeader extends StatelessWidget {
  const AppBrandHeader(
      {super.key, required this.subtitle, this.compact = false});
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = compact ? 44.0 : 52.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.28),
              child: Image.asset('assets/logo.jpg',
                  fit: BoxFit.cover, width: size, height: size),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Chị Mười',
                    style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}