import 'package:flutter/material.dart';
import '../../../core/games/game_metadata.dart';
import '../../game_2048/services/game_2048_repository.dart';
import '../../game_2048/views/game_2048_screen.dart';
import '../models/sudoku_models.dart';
import '../services/sudoku_repository.dart';
import 'sudoku_game_screen.dart';

/// Trang chủ ─ điều hướng 3 tab: Trò chơi / Thành tích / Cài đặt.
class HubScreen extends StatefulWidget {
  const HubScreen({
    super.key,
    required this.repository,
    required this.game2048Repository,
    required this.onThemeChanged,
  });
  final SudokuRepository repository;
  final Game2048Repository game2048Repository;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  SudokuGame? saved;
  SudokuStats stats = SudokuStats();
  int best2048 = 0;
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
      ),
      _StatsTab(stats: stats, best2048: best2048),
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
  });

  final bool loading;
  final SudokuGame? saved;
  final int best2048;
  final VoidCallback onSudokuNew;
  final VoidCallback? onSudokuContinue;
  final VoidCallback onPlay2048;

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
        ],
      ],
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

class _GameIconBadge extends StatelessWidget {
  const _GameIconBadge({
    required this.icon,
    required this.background,
    required this.foreground,
  });
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(icon, color: foreground, size: 28),
  );
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
//  TAB 2 ─ THÀNH TÍCH
// ───────────────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.stats, required this.best2048});
  final SudokuStats stats;
  final int best2048;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completion = stats.started == 0
        ? 0
        : (stats.completed * 100 / stats.started).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SizedBox(
          height: 64,
          child: AppBrandHeader(subtitle: 'Theo dõi hành trình chơi'),
        ),
        const SizedBox(height: 28),
        _SectionLabel('Sudoku'),
        const SizedBox(height: 12),
        Card(
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
                      'Thống kê',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Bắt đầu',
                        value: '${stats.started}',
                      ),
                    ),
                    Expanded(
                      child: _StatTile(
                        label: 'Hoàn thành',
                        value: '${stats.completed}',
                      ),
                    ),
                    Expanded(
                      child: _StatTile(
                        label: 'Tỉ lệ',
                        value: '$completion%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _StatTile(
                  label: 'Chuỗi tốt nhất',
                  value: '${stats.bestStreak}',
                  full: true,
                ),
                if (stats.bestTimes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Divider(color: colors.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    'Kỷ lục thời gian',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...stats.bestTimes.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _diffLabel(e.key),
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                          Text(
                            _formatTime(e.value),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionLabel('2048'),
        const SizedBox(height: 12),
        Card(
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
                  '$best2048',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _diffLabel(String key) {
    switch (key) {
      case 'easy':
        return 'Dễ';
      case 'medium':
        return 'Trung bình';
      case 'hard':
        return 'Khó';
      case 'expert':
        return 'Chuyên gia';
      default:
        return key;
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60, s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.full = false,
  });
  final String label;
  final String value;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final child = Column(
      crossAxisAlignment: full ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: full ? 22 : 24,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: colors.onSurface,
          ),
        ),
      ],
    );
    if (full) return child;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
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