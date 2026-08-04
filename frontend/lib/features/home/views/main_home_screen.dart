import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/services/auth_repository.dart';
import '../../sudoku/views/hub_screen.dart';
import '../../sudoku/services/sudoku_repository.dart';
import '../../game_2048/services/game_2048_repository.dart';
import '../../caro/services/caro_repository.dart';
import '../../minesweeper/services/minesweeper_repository.dart';
import '../../monopoly/services/monopoly_repository.dart';
import '../../block_puzzle/services/block_puzzle_repository.dart';
import '../../boat_receipt/views/boat_receipt_home_screen.dart';
import '../../settings/views/app_settings_screen.dart';

class ModuleItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final Color accentColor;
  final VoidCallback onTap;

  ModuleItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.accentColor,
    required this.onTap,
  });
}

class MainHomeScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final SudokuRepository repository;
  final Game2048Repository game2048Repository;
  final CaroRepository caroRepository;
  final MinesweeperRepository minesweeperRepository;
  final MonopolyRepository monopolyRepository;
  final BlockPuzzleRepository blockPuzzleRepository;
  final Function(ThemeMode) onThemeChanged;

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

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentBottomNavIndex = 0;
  List<String> _pinnedModuleIds = ['boat_receipts'];

  @override
  void initState() {
    super.initState();
    _loadPinnedModules();
  }

  Future<void> _loadPinnedModules() async {
    final sp = await SharedPreferences.getInstance();
    final cached = sp.getStringList('pinned_modules');
    if (cached != null) {
      setState(() {
        _pinnedModuleIds = cached;
      });
    }
  }

  Future<void> _togglePin(String moduleId) async {
    setState(() {
      if (_pinnedModuleIds.contains(moduleId)) {
        _pinnedModuleIds.remove(moduleId);
      } else {
        _pinnedModuleIds.add(moduleId);
      }
    });
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('pinned_modules', _pinnedModuleIds);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: IndexedStack(
        index: _currentBottomNavIndex,
        children: [
          _buildHomeContent(context),
          AppSettingsScreen(
            currentModule: 'main',
            onThemeChanged: widget.onThemeChanged,
            authRepository: widget.authRepository,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 70,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          indicatorColor: const Color(0xFF0284C7),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 15,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? (isDark ? Colors.white : const Color(0xFF0284C7))
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 26,
              color: states.contains(WidgetState.selected)
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentBottomNavIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentBottomNavIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(Icons.grid_view_rounded, color: Colors.white),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_rounded),
              selectedIcon: Icon(Icons.settings_rounded, color: Colors.white),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    final user = widget.authRepository.currentUser;
    final displayName = user?.displayName ?? 'Mẹ';

    final List<ModuleItem> allModules = [
      ModuleItem(
        id: 'boat_receipts',
        title: 'SỔ GHE NHẬP LÚA',
        subtitle: 'Chụp phiếu & Thống kê khối lượng',
        icon: Icons.directions_boat_filled_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentColor: const Color(0xFF38BDF8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BoatReceiptHomeScreen(
                onThemeChanged: widget.onThemeChanged,
                authRepository: widget.authRepository,
              ),
            ),
          );
        },
      ),
      ModuleItem(
        id: 'games',
        title: 'KHO TRÒ CHƠI',
        subtitle: 'Caro, 2048, Sudoku, Đổ mìn, Cờ tỷ phú',
        icon: Icons.sports_esports_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1065), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentColor: const Color(0xFF2DD4BF),
        onTap: () {
          Navigator.push(
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
        },
      ),
    ];

    allModules.sort((a, b) {
      final aPinned = _pinnedModuleIds.contains(a.id);
      final bPinned = _pinnedModuleIds.contains(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.face_5_rounded, size: 28, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(width: 12),
            Text(
              'Chào $displayName',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 28, color: Color(0xFFF43F5E)),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text('Đăng xuất', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  content: const Text(
                    'Đăng xuất khỏi ứng dụng?',
                    style: TextStyle(fontSize: 18, color: Color(0xFFCBD5E1)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy', style: TextStyle(fontSize: 18, color: Color(0xFF94A3B8))),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                      child: const Text('Đăng xuất', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await widget.authRepository.logout();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        itemCount: allModules.length,
        separatorBuilder: (_, index) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          final item = allModules[index];
          final isPinned = _pinnedModuleIds.contains(item.id);

          return Container(
            decoration: BoxDecoration(
              gradient: item.gradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: item.accentColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isPinned ? item.accentColor : Colors.white.withValues(alpha: 0.15),
                width: isPinned ? 2.5 : 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: item.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(item.icon, size: 40, color: item.accentColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                    color: isPinned ? item.accentColor : Colors.white54,
                                    size: 26,
                                  ),
                                  onPressed: () => _togglePin(item.id),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, size: 20, color: item.accentColor),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
