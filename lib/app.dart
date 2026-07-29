import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/game_2048/services/game_2048_repository.dart';
import 'features/sudoku/services/sudoku_repository.dart';
import 'features/sudoku/views/hub_screen.dart';

class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  final SudokuRepository repository = SudokuRepository();
  final Game2048Repository game2048Repository = Game2048Repository();
  ThemeMode themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chị Mười',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: HubScreen(
        repository: repository,
        game2048Repository: game2048Repository,
        onThemeChanged: (mode) => setState(() => themeMode = mode),
      ),
    );
  }
}
