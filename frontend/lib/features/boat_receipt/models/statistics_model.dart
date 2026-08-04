class SummaryItem {
  final int trips;
  final int weightKg;
  final double weightTons;

  SummaryItem({required this.trips, required this.weightKg, required this.weightTons});

  factory SummaryItem.fromJson(Map<String, dynamic> json) {
    return SummaryItem(
      trips: json['trips'] ?? 0,
      weightKg: json['weightKg'] ?? 0,
      weightTons: (json['weightTons'] ?? 0.0).toDouble(),
    );
  }
}

class HomeSummaryModel {
  final SummaryItem today;
  final SummaryItem month;

  HomeSummaryModel({required this.today, required this.month});

  factory HomeSummaryModel.fromJson(Map<String, dynamic> json) {
    return HomeSummaryModel(
      today: SummaryItem.fromJson(json['today'] ?? {}),
      month: SummaryItem.fromJson(json['month'] ?? {}),
    );
  }
}

class BoatGroupStat {
  final String boatNumber;
  final int trips;
  final int totalKg;
  final double totalTons;

  BoatGroupStat({
    required this.boatNumber,
    required this.trips,
    required this.totalKg,
    required this.totalTons,
  });

  factory BoatGroupStat.fromJson(Map<String, dynamic> json) {
    return BoatGroupStat(
      boatNumber: json['boatNumber'] ?? '',
      trips: json['trips'] ?? 0,
      totalKg: json['totalKg'] ?? 0,
      totalTons: (json['totalTons'] ?? 0.0).toDouble(),
    );
  }
}

class PeriodTotalStat {
  final String label; // Date (YYYY-MM-DD) or Month (YYYY-MM)
  final int trips;
  final int totalKg;
  final double totalTons;

  PeriodTotalStat({
    required this.label,
    required this.trips,
    required this.totalKg,
    required this.totalTons,
  });

  factory PeriodTotalStat.fromJson(Map<String, dynamic> json) {
    return PeriodTotalStat(
      label: json['date'] ?? json['month'] ?? '',
      trips: json['trips'] ?? 0,
      totalKg: json['totalKg'] ?? 0,
      totalTons: (json['totalTons'] ?? 0.0).toDouble(),
    );
  }
}
