class GameMetadata {
  const GameMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.offline,
  });
  final String id;
  final String name;
  final String description;
  final String category;
  final bool offline;
}

const sudokuMetadata = GameMetadata(
  id: 'sudoku',
  name: 'Sudoku',
  description: 'Một khoảng lặng cho trí óc — điền đủ 1 đến 9.',
  category: 'Logic',
  offline: true,
);

const game2048Metadata = GameMetadata(
  id: '2048',
  name: '2048',
  description: 'Ghép những ô số giống nhau và chạm tới 2048.',
  category: 'Puzzle',
  offline: true,
);
