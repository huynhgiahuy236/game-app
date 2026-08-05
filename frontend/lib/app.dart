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
            backgroundColor: const Color(0xFF1E1435),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C5CC4).withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/splat.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const AppLogo(size: 140, radius: 32),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(
                      width: 180,
                      child: LinearProgressIndicator(
                        color: Color(0xFF7C5CC4),
                        backgroundColor: Color(0xFF382A5C),
                        minHeight: 6,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ĐANG TẢI ỨNG DỤNG CHỊ MƯỜI...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
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
