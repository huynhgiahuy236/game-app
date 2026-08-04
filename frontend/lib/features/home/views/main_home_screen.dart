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

class ModuleItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  ModuleItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
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
    final user = widget.authRepository.currentUser;
    final displayName = user?.displayName ?? 'Mẹ';

    final List<ModuleItem> allModules = [
      ModuleItem(
        id: 'boat_receipts',
        title: 'Sổ ghe',
        subtitle: 'Quản lý phiếu nhập lúa, ghe hàng',
        icon: Icons.directions_boat_filled,
        color: const Color(0xFF0066CC),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BoatReceiptHomeScreen()),
          );
        },
      ),
      ModuleItem(
        id: 'games',
        title: 'Trò chơi',
        subtitle: 'Cờ caro, Đổ mìn, 2048, Sudoku, cờ tỷ phú',
        icon: Icons.sports_esports,
        color: const Color(0xFF2E7D32),
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
              ),
            ),
          );
        },
      ),
    ];

    // Order modules by pinned status
    allModules.sort((a, b) {
      final aPinned = _pinnedModuleIds.contains(a.id);
      final bPinned = _pinnedModuleIds.contains(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          'CHỊ MƯỜI - $displayName',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 28),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đăng xuất', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  content: const Text(
                    'Bạn có chắc chắn muốn đăng xuất không?',
                    style: TextStyle(fontSize: 18),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy', style: TextStyle(fontSize: 18)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Đăng xuất', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await widget.authRepository.logout();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'CHỌN CHỨC NĂNG',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: allModules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final item = allModules[index];
                    final isPinned = _pinnedModuleIds.contains(item.id);

                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isPinned ? item.color : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: InkWell(
                        onTap: item.onTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: item.color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(item.icon, size: 42, color: item.color),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF111111),
                                          ),
                                        ),
                                        if (isPinned) ...[
                                          const SizedBox(width: 8),
                                          Icon(Icons.push_pin, size: 22, color: item.color),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.subtitle,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF555555),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                  color: isPinned ? item.color : Colors.grey,
                                  size: 28,
                                ),
                                onPressed: () => _togglePin(item.id),
                                tooltip: isPinned ? 'Gỡ ghim' : 'Ghim chức năng',
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 24),
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
        ),
      ),
    );
  }
}
