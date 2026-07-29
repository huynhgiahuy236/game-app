import 'package:flutter/material.dart';
import '../../../core/games/game_metadata.dart';
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

/// Trang chủ ─ điều hướng 3 tab: Trò chơi / Thành tích / Cài đặt.
class HubScreen extends StatefulWidget {
  const HubScreen({
    super.key,
    required this.repository,
    required this.game2048Repository,
    required this.caroRepository,
    required this.minesweeperRepository,
    required this.monopolyRepository,
    required this.onThemeChanged,
  });
  final SudokuRepository repository;
  final Game2048Repository game2048Repository;
  final CaroRepository caroRepository;
  final MinesweeperRepository minesweeperRepository;
  final MonopolyRepository monopolyRepository;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  SudokuGame? saved;
  SudokuStats stats = SudokuStats();
  int best2048 = 0;
  List<int> scoreHistory2048 = const [];
  bool loading = true;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    saved = await widget.repository.loadGame();
    stats = await widget.repository.loadStats();
    best2048 = await widget.game2048Repository.bestScore();
    scoreHistory2048 = await widget.game2048Repository.scoreHistory();
    if (mounted) setState(() => loading = false);
    if (!await widget.repository.tutorialSeen() && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
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
    final difficulty = await showModalBottomSheet<Difficulty>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _DifficultySheet(),
    );
    if (difficulty != null && mounted) {
      await SudokuGameScreen.startNew(context, widget.repository, difficulty);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _GamesTab(
        loading: loading,
        saved: saved,
        best2048: best2048,
        onSudokuNew: _chooseDifficulty,
        onSudokuContinue: saved == null
            ? null
            : () async {
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
              },
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
              builder: (_) =>
                  MinesweeperGameScreen(repository: widget.minesweeperRepository),
            ),
          );
          _load();
        },
        onPlayMonopoly: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MonopolyGameScreen(repository: widget.monopolyRepository),
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
      _SettingsTab(
        onThemeChanged: widget.onThemeChanged,
        onShowTutorial: _showTutorial,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
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
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (i) => setState(() => selectedTab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports_rounded),
            label: 'Trò chơi',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Thành tích',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  App brand header (logo + tên) ─ dùng chung mọi tab
// ───────────────────────────────────────────────────────────────────────────

class AppBrandHeader extends StatelessWidget {
  const AppBrandHeader({super.key, required this.subtitle, this.compact = false});
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
              child: Image.asset(
                'assets/logo.jpg',
                fit: BoxFit.cover,
                width: size,
                height: size,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Chị Mười',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
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

// ───────────────────────────────────────────────────────────────────────────
//  TAB 1 ─ TRÒ CHƠI
// ───────────────────────────────────────────────────────────────────────────

class _GamesTab extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SizedBox(
          height: 64,
          child: AppBrandHeader(subtitle: 'Chọn một trò và bắt đầu'),
        ),
        const SizedBox(height: 28),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _SectionLabel('Game của bạn'),
          const SizedBox(height: 12),
          _SudokuGameCard(
            hasSaved: saved != null,
            onNew: onSudokuNew,
            onContinue: onSudokuContinue,
          ),
          const SizedBox(height: 12),
          _Game2048Card(
            bestScore: best2048,
            onPlay: onPlay2048,
          ),
          const SizedBox(height: 12),
          _CaroGameCard(
            onPlay: onPlayCaro,
          ),
          const SizedBox(height: 12),
          _MinesweeperGameCard(
            onPlay: onPlayMinesweeper,
          ),
          const SizedBox(height: 12),
          _MonopolyGameCard(
            onPlay: onPlayMonopoly,
          ),
        ],
      ],
    );
  }
}

class _MonopolyGameCard extends StatelessWidget {
  const _MonopolyGameCard({required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.casino_rounded,
                    color: colors.onTertiaryContainer,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      monopolyMetadata.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monopolyMetadata.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Chơi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinesweeperGameCard extends StatelessWidget {
  const _MinesweeperGameCard({required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.dangerous_rounded,
                    color: colors.onErrorContainer,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      minesweeperMetadata.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      minesweeperMetadata.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Chơi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaroGameCard extends StatelessWidget {
  const _CaroGameCard({required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _GameImageBadge(
                assetPath: 'assets/logo_game/ox.jpg',
                background: null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      caroMetadata.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caroMetadata.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Chơi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _SudokuGameCard extends StatelessWidget {
  const _SudokuGameCard({
    required this.hasSaved,
    required this.onNew,
    this.onContinue,
  });
  final bool hasSaved;
  final VoidCallback onNew;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: hasSaved ? onContinue : onNew,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _GameImageBadge(
                assetPath: 'assets/logo_game/sudoku.png',
                background: null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sudokuMetadata.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasSaved ? 'Có ván đang chơi dở' : sudokuMetadata.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: hasSaved ? onContinue : onNew,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(hasSaved ? 'Tiếp tục' : 'Chơi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Game2048Card extends StatelessWidget {
  const _Game2048Card({required this.bestScore, required this.onPlay});
  final int bestScore;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _GameImageBadge(
                assetPath: 'assets/logo_game/2048.jpg',
                background: null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      game2048Metadata.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bestScore > 0
                          ? 'Kỷ lục: $bestScore'
                          : game2048Metadata.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Chơi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameImageBadge extends StatelessWidget {
  const _GameImageBadge({
    required this.assetPath,
    this.background,
  });
  final String assetPath;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background ?? colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  TAB 2 ─ THÀNH TÍCH (dạng biểu đồ)
// ───────────────────────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Thành tích Sudoku',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Thành tích 2048',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SizedBox(
          height: 64,
          child: AppBrandHeader(subtitle: 'Theo dõi thành tích các trò chơi'),
        ),
        const SizedBox(height: 24),
        _SectionLabel('Danh sách trò chơi'),
        const SizedBox(height: 12),

        // ── Card Thành tích Sudoku ──────────────────────────────────
        _StatsGameCard(
          title: 'Sudoku',
          subtitle: 'Thắng ${stats.completed} ván • Tỉ lệ ${(stats.started == 0 ? 0 : (stats.completed * 100 / stats.started)).round()}%',
          assetPath: 'assets/logo_game/sudoku.png',
          onTap: () => _showSudokuDetail(context),
        ),
        const SizedBox(height: 12),

        // ── Card Thành tích 2048 ─────────────────────────────────────
        _StatsGameCard(
          title: '2048',
          subtitle: 'Kỷ lục: $best2048 điểm',
          assetPath: 'assets/logo_game/2048.jpg',
          onTap: () => _show2048Detail(context),
        ),
      ],
    );
  }
}

class _StatsGameCard extends StatelessWidget {
  const _StatsGameCard({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _GameImageBadge(assetPath: assetPath),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Chi tiết'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card tổng quan Sudoku — 3 chỉ số chính.
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
            Row(
              children: [
                Icon(Icons.insights_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Text(
                  'Tổng quan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCell(
                    label: 'Bắt đầu',
                    value: '${stats.started}',
                  ),
                ),
                Expanded(
                  child: _MetricCell(
                    label: 'Hoàn thành',
                    value: '${stats.completed}',
                  ),
                ),
                Expanded(
                  child: _MetricCell(
                    label: 'Tỉ lệ',
                    value: '$completion%',
                  ),
                ),
                Expanded(
                  child: _MetricCell(
                    label: 'Streak',
                    value: '${stats.bestStreak}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Biểu đồ cột: số ván bắt đầu / hoàn thành theo từng độ khó Sudoku.
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
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ván theo độ khó',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _LegendDot(color: colors.primary, label: 'Bắt đầu'),
                const SizedBox(width: 8),
                _LegendDot(
                  color: colors.tertiary,
                  label: 'Hoàn thành',
                ),
              ],
            ),
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
                      icon: Icons.bar_chart_rounded,
                    ),
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

/// Biểu đồ cột: thời gian kỷ lục theo độ khó (đơn vị giây).
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
            Row(
              children: [
                Icon(Icons.timer_outlined, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kỷ lục thời gian',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _LegendDot(color: colors.tertiary, label: 'Giây'),
              ],
            ),
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
                      icon: Icons.timer_outlined,
                    ),
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

/// Card tổng quan 2048.
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
              child: Icon(
                Icons.crop_square_rounded,
                color: colors.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kỷ lục 2048',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Điểm cao nhất',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$best',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Biểu đồ cột: lịch sử điểm các ván 2048 gần nhất.
class _Game2048ScoreChart extends StatelessWidget {
  const _Game2048ScoreChart({required this.history});
  final List<int> history;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = <_ChartEntry>[];
    for (var i = 0; i < history.length; i++) {
      entries.add(
        _ChartEntry(
          label: '${i + 1}',
          started: history[i],
          completed: 0,
        ),
      );
    }
    final hasData = entries.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lịch sử điểm',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _LegendDot(color: colors.tertiary, label: 'Ván ${entries.length}'),
              ],
            ),
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
                      formatValue: (v) => '$v',
                    )
                  : _EmptyChart(
                      message: 'Chưa có ván 2048 nào',
                      icon: Icons.show_chart_rounded,
                    ),
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

// ── Helpers ─────────────────────────────────────────────────────────────────

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
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return LayoutBuilder(
      builder: (context, c) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final e in entries) ...[
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
          ],
        );
      },
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
    final h1 = single ? entry.started : entry.started;
    final h2 = single ? 0 : entry.completed;
    final v1 = h1 / maxValue;
    final v2 = h2 / maxValue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Số hiển thị trên đầu cột
          Text(
            (h1 > 0 ? formatValue?.call(h1) ?? '$h1' : ''),
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
                    fraction: v1,
                    color: primary,
                    track: track,
                  ),
                ),
                if (!single) ...[
                  const SizedBox(width: 3),
                  Expanded(
                    child: _AnimatedBar(
                      fraction: v2,
                      color: accent,
                      track: track,
                    ),
                  ),
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
    _anim = Tween<double>(begin: 0, end: widget.fraction.clamp(0.0, 1.0))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fraction != widget.fraction) {
      _anim = Tween<double>(
        begin: oldWidget.fraction.clamp(0.0, 1.0),
        end: widget.fraction.clamp(0.0, 1.0),
      ).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
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
      builder: (context, c) {
        return AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: c.maxHeight,
                  decoration: BoxDecoration(
                    color: widget.track,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Container(
                  height: c.maxHeight * _anim.value,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            );
          },
        );
      },
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
          Text(
            message,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(int seconds) {
  final m = seconds ~/ 60, s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ───────────────────────────────────────────────────────────────────────────
//  TAB 3 ─ CÀI ĐẶT
// ───────────────────────────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.onThemeChanged,
    required this.onShowTutorial,
  });
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onShowTutorial;

  @override
  Widget build(BuildContext context) {
    final mode = Theme.of(context).brightness;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SizedBox(
          height: 64,
          child: AppBrandHeader(subtitle: 'Cá nhân hoá trải nghiệm'),
        ),
        const SizedBox(height: 28),
        _SectionLabel('Giao diện'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _ThemeOption(
                icon: Icons.brightness_auto_rounded,
                title: 'Theo hệ thống',
                subtitle: 'Tự động theo thiết bị',
                selected: MediaQuery.platformBrightnessOf(context) == mode,
                onTap: () => onThemeChanged(ThemeMode.system),
              ),
              const Divider(height: 1, indent: 64),
              _ThemeOption(
                icon: Icons.light_mode_rounded,
                title: 'Sáng',
                subtitle: 'Nền trắng, chữ đậm',
                selected: mode == Brightness.light,
                onTap: () => onThemeChanged(ThemeMode.light),
              ),
              const Divider(height: 1, indent: 64),
              _ThemeOption(
                icon: Icons.dark_mode_rounded,
                title: 'Tối',
                subtitle: 'Nền xanh đen, dịu mắt',
                selected: mode == Brightness.dark,
                onTap: () => onThemeChanged(ThemeMode.dark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionLabel('Hỗ trợ'),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('Hướng dẫn Sudoku'),
            subtitle: const Text('Xem lại cách chơi'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onShowTutorial,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Về ứng dụng'),
            subtitle: const Text('Chị Mười • v1.0'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Chị Mười',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 Chị Mười Games',
              children: const [
                SizedBox(height: 12),
                Text(
                  'Sudoku và 2048 — chơi nhanh, gọn, đẹp.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? colors.primary : colors.onSurfaceVariant),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? colors.primary : colors.onSurface,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colors.primary)
          : const Icon(Icons.radio_button_unchecked_rounded),
      onTap: onTap,
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  SHEETS: chọn độ khó + hướng dẫn
// ───────────────────────────────────────────────────────────────────────────

class _DifficultySheet extends StatefulWidget {
  const _DifficultySheet();
  @override
  State<_DifficultySheet> createState() => _DifficultySheetState();
}

class _DifficultySheetState extends State<_DifficultySheet> {
  Difficulty selected = Difficulty.easy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'Chọn độ khó',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Bạn luôn có thể quay lại và chọn mức khác.',
              ),
            ),
            const SizedBox(height: 4),
            ...Difficulty.values.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected == d
                      ? colors.primaryContainer
                      : colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => selected = d),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected == d
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected == d
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  d.description,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
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
            child: Text(
              'Cách chơi Sudoku',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const _Tip(
            Icons.grid_3x3_rounded,
            'Mỗi hàng, cột và ô vuông 3×3 chứa đủ các số 1–9.',
          ),
          const _Tip(
            Icons.edit_note_rounded,
            'Bật Ghi chú để lưu các ứng viên nhỏ trong ô.',
          ),
          const _Tip(
            Icons.lightbulb_outline_rounded,
            'Dùng tối đa 3 gợi ý; sai 3 lần sẽ kết thúc lượt.',
          ),
          const _Tip(
            Icons.keyboard_rounded,
            'Máy tính: phím mũi tên, 1–9, N, H, P và Ctrl/Cmd+Z.',
          ),
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
            child: Icon(icon, color: colors.onPrimaryContainer, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: const TextStyle(height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}