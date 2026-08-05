import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/services/auth_repository.dart';
import 'features/home/views/main_home_screen.dart';
import 'features/game_2048/services/game_2048_repository.dart';
import 'features/sudoku/services/sudoku_repository.dart';
import 'features/caro/services/caro_repository.dart';
import 'features/minesweeper/services/minesweeper_repository.dart';
import 'features/monopoly/services/monopoly_repository.dart';
import 'features/block_puzzle/services/block_puzzle_repository.dart';

class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  final AuthRepository authRepository = AuthRepository();
  final SudokuRepository repository = SudokuRepository();
  final Game2048Repository game2048Repository = Game2048Repository();
  final CaroRepository caroRepository = CaroRepository();
  final MinesweeperRepository minesweeperRepository = MinesweeperRepository();
  final MonopolyRepository monopolyRepository = MonopolyRepository();
  final BlockPuzzleRepository blockPuzzleRepository = BlockPuzzleRepository();
  ThemeMode themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    authRepository.initSession();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authRepository,
      builder: (context, _) {
        Widget homeWidget;

        if (authRepository.isLoading) {
          homeWidget = Scaffold(
            backgroundColor: const Color(0xFF0F091F),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/splat.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1E1435),
                    child: const Center(child: AppLogo(size: 140, radius: 32)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 180,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 36,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ĐANG TẢI ỨNG DỤNG CHỊ MƯỜI...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: const LinearProgressIndicator(
                            color: Color(0xFF9066FF),
                            backgroundColor: Color(0x66FFFFFF),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          homeWidget = MainHomeScreen(
            authRepository: authRepository,
            repository: repository,
            game2048Repository: game2048Repository,
            caroRepository: caroRepository,
            minesweeperRepository: minesweeperRepository,
            monopolyRepository: monopolyRepository,
            blockPuzzleRepository: blockPuzzleRepository,
            onThemeChanged: (mode) => setState(() => themeMode = mode),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Chị Mười',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          locale: const Locale('vi', 'VN'),
          supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: homeWidget,
        );
      },
    );
  }
}
