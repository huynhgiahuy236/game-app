import 'dart:math';
import 'package:flutter/material.dart';
import '../models/monopoly_models.dart';

class MonopolyEngine {
  static final _random = Random();

  /// Generates the complete 28-tile Vietnamese Monopoly board
  static List<MonopolyTile> createBoard() {
    return [
      // 0: Start
      MonopolyTile(index: 0, name: 'BẮT ĐẦU', type: TileType.start),
      // Group 1: Teal
      MonopolyTile(index: 1, name: 'Cần Thơ', type: TileType.property, price: 60, baseRent: 10, groupColor: const Color(0xFF0D9488)),
      MonopolyTile(index: 2, name: 'Cơ Hội', type: TileType.chance),
      MonopolyTile(index: 3, name: 'Mỹ Tho', type: TileType.property, price: 80, baseRent: 15, groupColor: const Color(0xFF0D9488)),
      MonopolyTile(index: 4, name: 'Thuế Thu Nhập', type: TileType.tax, price: 100),
      MonopolyTile(index: 5, name: 'Bến Xe Miền Tây', type: TileType.station, price: 150, baseRent: 25),
      // Group 2: Sky Blue
      MonopolyTile(index: 6, name: 'Vũng Tàu', type: TileType.property, price: 100, baseRent: 20, groupColor: const Color(0xFF0EA5E9)),
      MonopolyTile(index: 7, name: 'Khí Vận', type: TileType.communityChest),
      MonopolyTile(index: 8, name: 'Phan Thiết', type: TileType.property, price: 120, baseRent: 25, groupColor: const Color(0xFF0EA5E9)),
      // 9: Jail
      MonopolyTile(index: 9, name: 'NHÀ TÙ', type: TileType.jail),
      // Group 3: Purple
      MonopolyTile(index: 10, name: 'Đà Lạt', type: TileType.property, price: 140, baseRent: 30, groupColor: const Color(0xFF8B5CF6)),
      MonopolyTile(index: 11, name: 'Công Ty Điện', type: TileType.utility, price: 150, baseRent: 25),
      MonopolyTile(index: 12, name: 'Nha Trang', type: TileType.property, price: 160, baseRent: 35, groupColor: const Color(0xFF8B5CF6)),
      MonopolyTile(index: 13, name: 'Bến Xe Miền Đông', type: TileType.station, price: 150, baseRent: 25),
      // Group 4: Amber/Orange
      MonopolyTile(index: 14, name: 'Quy Nhơn', type: TileType.property, price: 180, baseRent: 40, groupColor: const Color(0xFFF59E0B)),
      // 15: Free Parking
      MonopolyTile(index: 15, name: 'BÃI XE MIỄN PHÍ', type: TileType.freeParking),
      MonopolyTile(index: 16, name: 'Đà Nẵng', type: TileType.property, price: 200, baseRent: 45, groupColor: const Color(0xFFF59E0B)),
      MonopolyTile(index: 17, name: 'Cơ Hội', type: TileType.chance),
      // Group 5: Red
      MonopolyTile(index: 18, name: 'Huế', type: TileType.property, price: 220, baseRent: 50, groupColor: const Color(0xFFEF4444)),
      MonopolyTile(index: 19, name: 'Hải Phòng', type: TileType.property, price: 240, baseRent: 55, groupColor: const Color(0xFFEF4444)),
      MonopolyTile(index: 20, name: 'Nhà Ga Hà Nội', type: TileType.station, price: 150, baseRent: 25),
      // 21: Go to Jail
      MonopolyTile(index: 21, name: 'VÀO TÙ', type: TileType.goToJail),
      // Group 6: Magenta/Rose
      MonopolyTile(index: 22, name: 'Hà Nội - Phố Cổ', type: TileType.property, price: 280, baseRent: 65, groupColor: const Color(0xFFD946EF)),
      MonopolyTile(index: 23, name: 'Khí Vận', type: TileType.communityChest),
      MonopolyTile(index: 24, name: 'Hà Nội - Tràng Tiền', type: TileType.property, price: 300, baseRent: 75, groupColor: const Color(0xFFD946EF)),
      // Group 7: Emerald
      MonopolyTile(index: 25, name: 'TP.HCM - Bến Thành', type: TileType.property, price: 350, baseRent: 90, groupColor: const Color(0xFF10B981)),
      MonopolyTile(index: 26, name: 'Thuế Xa Xỉ', type: TileType.tax, price: 150),
      MonopolyTile(index: 27, name: 'TP.HCM - Nguyễn Huệ', type: TileType.property, price: 400, baseRent: 110, groupColor: const Color(0xFF10B981)),
    ];
  }

  static const List<MonopolyCard> chanceCards = [
    MonopolyCard(title: 'Trúng Xổ Số!', description: 'Bạn nhận được thưởng \$100.', cashChange: 100, isChance: true),
    MonopolyCard(title: 'Bảo Trì Xe', description: 'Nộp phí sửa xe \$50.', cashChange: -50, isChance: true),
    MonopolyCard(title: 'Tăng Lương', description: 'Công ty thưởng \$150.', cashChange: 150, isChance: true),
    MonopolyCard(title: 'Du Lịch Đà Nẵng', description: 'Di chuyển thẳng tới Đà Nẵng.', cashChange: 0, movePosition: 16, isChance: true),
  ];

  static const List<MonopolyCard> communityCards = [
    MonopolyCard(title: 'Đền Bồi Thường', description: 'Nhận \$80 từ bảo hiểm.', cashChange: 80, isChance: false),
    MonopolyCard(title: 'Đóng Quỹ Từ Thiện', description: 'Ủng hộ \$40 cho cộng đồng.', cashChange: -40, isChance: false),
    MonopolyCard(title: 'Tế Tổ Thành Công', description: 'Nhận lộc \$120.', cashChange: 120, isChance: false),
    MonopolyCard(title: 'Vé Máy Bay', description: 'Bay thẳng tới TP.HCM Nguyễn Huệ.', cashChange: 0, movePosition: 27, isChance: false),
  ];

  static MonopolyCard drawChance() => chanceCards[_random.nextInt(chanceCards.length)];
  static MonopolyCard drawCommunity() => communityCards[_random.nextInt(communityCards.length)];

  /// AI decision: Returns true if AI wants to buy property
  static bool aiShouldBuy(MonopolyPlayer player, MonopolyTile tile) {
    if (player.cash >= tile.price + 80) return true;
    return false;
  }

  /// AI decision: Returns true if AI wants to build house
  static bool aiShouldBuild(MonopolyPlayer player, MonopolyTile tile) {
    if (tile.ownerId == player.id && tile.houses < 5 && player.cash >= tile.houseCost + 200) {
      return true;
    }
    return false;
  }
}
