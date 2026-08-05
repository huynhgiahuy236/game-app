import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/services/auth_repository.dart';
import '../../block_puzzle/services/block_puzzle_repository.dart';
import '../../boat_receipt/views/boat_receipt_home_screen.dart';
import '../../caro/services/caro_repository.dart';
import '../../game_2048/services/game_2048_repository.dart';
import '../../minesweeper/services/minesweeper_repository.dart';
import '../../monopoly/services/monopoly_repository.dart';
import '../../settings/views/app_settings_screen.dart';
import '../../sudoku/services/sudoku_repository.dart';
import '../../sudoku/views/hub_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({
    super.key,
    required this.authRepository,
    required this.repository,
    required this.game2048Repository,
    required this.caroRepository,
    required this.minesweeperRepository,
    required this.monopolyRepository,
    required this.blockPuzzleRepository,
    required this.onThemeChanged,
  });

  final AuthRepository authRepository;
  final SudokuRepository repository;
  final Game2048Repository game2048Repository;
  final CaroRepository caroRepository;
  final MinesweeperRepository minesweeperRepository;
  final MonopolyRepository monopolyRepository;
  final BlockPuzzleRepository blockPuzzleRepository;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  List<String> _pinnedModuleIds = ['boat_receipts'];
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _loadPinnedModules();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _loadPinnedModules() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('pinned_modules');
    if (cached != null && mounted) setState(() => _pinnedModuleIds = cached);
  }

  Future<void> _togglePin(String id) async {
    setState(
      () => _pinnedModuleIds.contains(id)
          ? _pinnedModuleIds.remove(id)
          : _pinnedModuleIds.add(id),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_modules', _pinnedModuleIds);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần đăng nhập lại để tiếp tục sử dụng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.authRepository.logout();
  }

  void _openReceipts() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BoatReceiptHomeScreen(
        onThemeChanged: widget.onThemeChanged,
        authRepository: widget.authRepository,
      ),
    ),
  );

  void _openGames() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => HubScreen(
        repository: widget.repository,
        game2048Repository: widget.game2048Repository,
        caroRepository: widget.caroRepository,
        minesweeperRepository: widget.minesweeperRepository,
        monopolyRepository: widget.monopolyRepository,
        blockPuzzleRepository: widget.blockPuzzleRepository,
        onThemeChanged: widget.onThemeChanged,
        authRepository: widget.authRepository,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeDashboard(
            entrance: _entrance,
            displayName:
                widget.authRepository.currentUser?.displayName ?? 'Mười',
            isConnecting: widget.authRepository.isConnecting,
            connectionSeconds: widget.authRepository.startupSeconds,
            connectionMessage: widget.authRepository.startupMessage,
            pinnedIds: _pinnedModuleIds,
            onTogglePin: _togglePin,
            onReceipts: _openReceipts,
            onGames: _openGames,
            onLogout: _logout,
          ),
          AppSettingsScreen(
            currentModule: 'main',
            onThemeChanged: widget.onThemeChanged,
            authRepository: widget.authRepository,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: NavigationBar(
              height: 68,
              backgroundColor: Colors.transparent,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) =>
                  setState(() => _selectedIndex = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: 'Cài đặt',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.entrance,
    required this.displayName,
    required this.isConnecting,
    required this.connectionSeconds,
    required this.connectionMessage,
    required this.pinnedIds,
    required this.onTogglePin,
    required this.onReceipts,
    required this.onGames,
    required this.onLogout,
  });

  final AnimationController entrance;
  final String displayName;
  final bool isConnecting;
  final int connectionSeconds;
  final String connectionMessage;
  final List<String> pinnedIds;
  final ValueChanged<String> onTogglePin;
  final VoidCallback onReceipts;
  final VoidCallback onGames;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(child: _Atmosphere(color: scheme.primary)),
        SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final gutter = wide ? 32.0 : 20.0;
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 116),
                    sliver: SliverList.list(
                      children: [
                        _reveal(
                          0,
                          _TopBar(
                            onLogout: onLogout,
                            isConnecting: isConnecting,
                            connectionSeconds: connectionSeconds,
                            connectionMessage: connectionMessage,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _reveal(1, _Hero(displayName: displayName)),
                        const SizedBox(height: 28),
                        _reveal(
                          2,
                          _SectionHeading(
                            title: 'Không gian của bạn',
                            subtitle: 'Chọn một hành trình để bắt đầu',
                            count: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _reveal(
                          3,
                          wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: _ReceiptCard(
                                        pinned: pinnedIds.contains(
                                          'boat_receipts',
                                        ),
                                        onPin: () =>
                                            onTogglePin('boat_receipts'),
                                        onTap: onReceipts,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 5,
                                      child: _GameCard(
                                        pinned: pinnedIds.contains('games'),
                                        onPin: () => onTogglePin('games'),
                                        onTap: onGames,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _ReceiptCard(
                                      pinned: pinnedIds.contains(
                                        'boat_receipts',
                                      ),
                                      onPin: () => onTogglePin('boat_receipts'),
                                      onTap: onReceipts,
                                    ),
                                    const SizedBox(height: 16),
                                    _GameCard(
                                      pinned: pinnedIds.contains('games'),
                                      onPin: () => onTogglePin('games'),
                                      onTap: onGames,
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _reveal(int index, Widget child) {
    final start = math.min(index * .09, .36);
    final animation = CurvedAnimation(
      parent: entrance,
      curve: Interval(
        start,
        math.min(start + .58, 1),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _Atmosphere extends StatelessWidget {
  const _Atmosphere({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF070A16), Color(0xFF11102A), Color(0xFF080C18)]
              : const [Color(0xFFFFF7FB), Color(0xFFF8F3FF), Color(0xFFFFFAF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _OrbPainter(color: color, dark: dark),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.color, required this.dark});
  final Color color;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
    paint.color = color.withValues(alpha: dark ? .22 : .13);
    canvas.drawCircle(Offset(size.width * .92, 70), 130, paint);
    paint.color = const Color(0xFFF59E0B).withValues(alpha: dark ? .1 : .08);
    canvas.drawCircle(Offset(-20, size.height * .62), 110, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) => false;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onLogout,
    required this.isConnecting,
    required this.connectionSeconds,
    required this.connectionMessage,
  });
  final VoidCallback onLogout;
  final bool isConnecting;
  final int connectionSeconds;
  final String connectionMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const AppLogo(size: 46, radius: 15),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CHỊ MƯỜI', style: Theme.of(context).textTheme.titleLarge),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Row(
                  key: ValueKey('$isConnecting-$connectionSeconds'),
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isConnecting
                            ? scheme.tertiary
                            : AppTheme.emeraldGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isConnecting
                            ? '$connectionMessage • ${connectionSeconds}s'
                            : connectionMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.displayName});
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 238),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFFDB2777), Color(0xFFF97316)],
          stops: [0, .58, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .28),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(right: -24, top: -28, child: _HeroRings()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white.withValues(alpha: .2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFFFE082),
                      size: 17,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'SẴN SÀNG CHO HÔM NAY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Xin chào, Chị Mười',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Quản lý công việc gọn gàng,\nthư giãn thật vui.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .84),
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              const Row(
                children: [
                  _MiniStat(
                    icon: Icons.apps_rounded,
                    value: '2',
                    label: 'tiện ích',
                  ),
                  SizedBox(width: 10),
                  _MiniStat(
                    icon: Icons.videogame_asset_rounded,
                    value: '6',
                    label: 'trò chơi',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroRings extends StatelessWidget {
  const _HeroRings();
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 152,
        height: 152,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: .12),
            width: 22,
          ),
        ),
      ),
      Icon(
        Icons.auto_awesome_rounded,
        size: 42,
        color: Colors.white.withValues(alpha: .3),
      ),
    ],
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(
          '$value $label',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.count,
  });
  final String title;
  final String subtitle;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '$count MODULE',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
      ),
    ],
  );
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.pinned,
    required this.onPin,
    required this.onTap,
  });
  final bool pinned;
  final VoidCallback onPin;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _ModuleCard(
    minHeight: 280,
    title: 'Sổ ghe',
    subtitle: 'Phiếu nhập & thống kê trấu',
    eyebrow: 'CÔNG VIỆC',
    icon: Icons.directions_boat_filled_rounded,
    accent: const Color(0xFF22D3EE),
    gradient: const LinearGradient(
      colors: [Color(0xFF0E7490), Color(0xFF164E63)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    pinned: pinned,
    onPin: onPin,
    onTap: onTap,
    footer: const Row(
      children: [
        _DotLabel(color: Color(0xFF67E8F9), label: 'Sẵn sàng'),
        Spacer(),
        Icon(Icons.arrow_outward_rounded, color: Colors.white),
      ],
    ),
  );
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.pinned,
    required this.onPin,
    required this.onTap,
  });
  final bool pinned;
  final VoidCallback onPin;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _ModuleCard(
    minHeight: 280,
    title: 'Game',
    subtitle: '6 trò chơi • không giới hạn',
    eyebrow: 'GIẢI TRÍ',
    icon: Icons.sports_esports_rounded,
    accent: const Color(0xFFF0ABFC),
    gradient: const LinearGradient(
      colors: [Color(0xFF7E22CE), Color(0xFFBE185D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    pinned: pinned,
    onPin: onPin,
    onTap: onTap,
    footer: const Row(
      children: [
        _DotLabel(color: Color(0xFFF0ABFC), label: '6 trò chơi sẵn sàng'),
        Spacer(),
        Icon(Icons.arrow_outward_rounded, color: Colors.white),
      ],
    ),
  );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.minHeight,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.gradient,
    required this.pinned,
    required this.onPin,
    required this.onTap,
    required this.footer,
    this.eyebrow = '',
  });
  final double minHeight;
  final String title;
  final String subtitle;
  final String eyebrow;
  final IconData icon;
  final Color accent;
  final Gradient gradient;
  final bool pinned;
  final VoidCallback onPin;
  final VoidCallback onTap;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Mở $title',
    child: SizedBox(
      height: minHeight,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          icon,
                          color: const Color(0xFF171122),
                          size: 27,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: pinned ? 'Bỏ ghim' : 'Ghim module',
                        onPressed: onPin,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: .13),
                        ),
                        icon: Icon(
                          pinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          color: pinned
                              ? accent
                              : Colors.white.withValues(alpha: .8),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  footer,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DotLabel extends StatelessWidget {
  const _DotLabel({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 7)],
        ),
      ),
      const SizedBox(width: 7),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _GameChip extends StatelessWidget {
  const _GameChip({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Icon(icon, color: Colors.white.withValues(alpha: .85), size: 16),
  );
}
