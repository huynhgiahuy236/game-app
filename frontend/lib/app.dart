import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/services/auth_repository.dart';
import 'features/auth/views/login_screen.dart';
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
            backgroundColor: Colors.blue.shade900,
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_boat_filled, size: 80, color: Colors.white),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Colors.amber, strokeWidth: 4),
                  SizedBox(height: 16),
                  Text(
                    'ĐANG TẢI ỨNG DỤNG CHỊ MƯỜI...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (!authRepository.isAuthenticated) {
          homeWidget = LoginScreen(authRepository: authRepository);
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
          home: homeWidget,
        );
      },
    );
  }
}
