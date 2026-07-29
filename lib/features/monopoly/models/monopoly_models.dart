import 'package:flutter/material.dart';

enum TileType {
  start,
  property,
  station,
  utility,
  chance,
  communityChest,
  tax,
  jail,
  freeParking,
  goToJail,
}

enum PlayerColor {
  red('Đỏ', Color(0xFFEF4444), Icons.directions_car_rounded),
  blue('Xanh Dương', Color(0xFF3B82F6), Icons.sailing_rounded),
  amber('Vàng Gold', Color(0xFFF59E0B), Icons.pets_rounded),
  purple('Tím Accent', Color(0xFF8B5CF6), Icons.rocket_launch_rounded);

  const PlayerColor(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

class MonopolyPlayer {
  MonopolyPlayer({
    required this.id,
    required this.name,
    required this.color,
    this.isAi = false,
    this.cash = 1500,
    this.position = 0,
    this.inJail = false,
    this.jailTurns = 0,
    this.bankrupt = false,
  });

  final String id;
  final String name;
  final PlayerColor color;
  final bool isAi;
  int cash;
  int position;
  bool inJail;
  int jailTurns;
  bool bankrupt;

  int get netWorth => cash;
}

class MonopolyTile {
  MonopolyTile({
    required this.index,
    required this.name,
    required this.type,
    this.price = 0,
    this.baseRent = 0,
    this.groupColor,
    this.ownerId,
    this.houses = 0,
  });

  final int index;
  final String name;
  final TileType type;
  final int price;
  final int baseRent;
  final Color? groupColor;
  String? ownerId;
  int houses; // 0..4 houses, 5 = hotel

  int get currentRent {
    if (type == TileType.property) {
      if (houses == 0) return baseRent;
      return baseRent * (houses + 1) * 2;
    } else if (type == TileType.station) {
      return baseRent;
    }
    return 0;
  }
}

class MonopolyCard {
  const MonopolyCard({
    required this.title,
    required this.description,
    required this.cashChange,
    this.movePosition,
  });

  final String title;
  final String description;
  final int cashChange;
  final int? movePosition;
}

class MonopolyStats {
  MonopolyStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.maxCashEarned = 0,
  });

  int gamesPlayed;
  int gamesWon;
  int maxCashEarned;

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'maxCashEarned': maxCashEarned,
      };

  factory MonopolyStats.fromJson(Map<String, dynamic> json) => MonopolyStats(
        gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
        gamesWon: (json['gamesWon'] as num?)?.toInt() ?? 0,
        maxCashEarned: (json['maxCashEarned'] as num?)?.toInt() ?? 0,
      );
}
