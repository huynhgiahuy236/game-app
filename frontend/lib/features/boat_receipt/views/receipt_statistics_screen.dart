import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../services/boat_receipt_repository.dart';

class ReceiptStatisticsScreen extends StatefulWidget {
  const ReceiptStatisticsScreen({super.key});

  @override
  State<ReceiptStatisticsScreen> createState() => _ReceiptStatisticsScreenState();
}

class _ReceiptStatisticsScreenState extends State<ReceiptStatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BoatReceiptRepository _repository = BoatReceiptRepository();

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _dailyData;
  Map<String, dynamic>? _monthlyData;
  Map<String, dynamic>? _yearlyData;
  List<dynamic>? _byBoatData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repository.getDailyStats(null),
        _repository.getMonthlyStats(null),
        _repository.getYearlyStats(null),
        _repository.getByBoatStats(null),
      ]);

      setState(() {
        _dailyData = results[0] as Map<String, dynamic>;
        _monthlyData = results[1] as Map<String, dynamic>;
        _yearlyData = results[2] as Map<String, dynamic>;
        _byBoatData = results[3] as List<dynamic>;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('THỐNG KÊ SỔ GHE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFDE047),
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 16),
          labelColor: const Color(0xFFFDE047),
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(text: 'Theo Ngày'),
            Tab(text: 'Theo Tháng'),
            Tab(text: 'Theo Năm'),
            Tab(text: 'Theo Ghe'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(fontSize: 18, color: Color(0xFFF43F5E))))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDailyTab(),
                    _buildMonthlyTab(),
                    _buildYearlyTab(),
                    _buildByBoatTab(),
                  ],
                ),
    );
  }

  Widget _buildDailyTab() {
    if (_dailyData == null) return const SizedBox();
    final trips = _dailyData!['trips'] ?? 0;
    final totalKg = _dailyData!['totalKg'] ?? 0;
    final totalTons = _dailyData!['totalTons'] ?? 0.0;
    final avgTons = _dailyData!['avgTonsPerTrip'] ?? 0.0;
    final byBoat = List.from(_dailyData!['byBoat'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCard(
            title: 'HÔM NAY',
            trips: trips,
            totalKg: totalKg,
            totalTons: totalTons,
            avgTons: avgTons,
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          const SizedBox(height: 24),
          const Text('PHÂN BỔ THEO GHE TRONG NGÀY', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (byBoat.isEmpty)
            const Text('Hôm nay chưa có chuyến ghe nào', style: TextStyle(fontSize: 18, color: Color(0xFF94A3B8)))
          else
            ...byBoat.map((b) => _buildBoatStatTile(b['boatNumber'], b['trips'], b['totalKg'])),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab() {
    if (_monthlyData == null) return const SizedBox();
    final trips = _monthlyData!['trips'] ?? 0;
    final totalKg = _monthlyData!['totalKg'] ?? 0;
    final totalTons = _monthlyData!['totalTons'] ?? 0.0;
    final avgTons = _monthlyData!['avgTonsPerTrip'] ?? 0.0;
    final highestDay = _monthlyData!['highestDay'];
    final byBoat = List.from(_monthlyData!['byBoat'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCard(
            title: 'THÁNG NÀY',
            trips: trips,
            totalKg: totalKg,
            totalTons: totalTons,
            avgTons: avgTons,
            gradient: const LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          const SizedBox(height: 20),

          if (highestDay != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEAB308), width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 38, color: Color(0xFFFDE047)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ngày nhập nhiều lúa nhất', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Text(
                          '${highestDay['date']} · ${AppFormatters.formatKgToTons(highestDay['totalKg'])} (${highestDay['trips']} chuyến)',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFFFDE047)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          const Text('TỔNG THEO TỪNG GHE TRONG THÁNG', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (byBoat.isEmpty)
            const Text('Tháng này chưa có chuyến ghe nào', style: TextStyle(fontSize: 18, color: Color(0xFF94A3B8)))
          else
            ...byBoat.map((b) => _buildBoatStatTile(b['boatNumber'], b['trips'], b['totalKg'])),
        ],
      ),
    );
  }

  Widget _buildYearlyTab() {
    if (_yearlyData == null) return const SizedBox();
    final trips = _yearlyData!['trips'] ?? 0;
    final totalKg = _yearlyData!['totalKg'] ?? 0;
    final totalTons = _yearlyData!['totalTons'] ?? 0.0;
    final highestMonth = _yearlyData!['highestMonth'];
    final monthlyTotals = List.from(_yearlyData!['monthlyTotals'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCard(
            title: 'NĂM ${_yearlyData!['year']}',
            trips: trips,
            totalKg: totalKg,
            totalTons: totalTons,
            avgTons: null,
            gradient: const LinearGradient(
              colors: [Color(0xFF581C87), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          const SizedBox(height: 20),

          if (highestMonth != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFA855F7), width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, size: 38, color: Color(0xFFC084FC)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tháng đạt khối lượng cao nhất', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Text(
                          'Tháng ${highestMonth['month']} · ${AppFormatters.formatKgToTons(highestMonth['totalKg'])}',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFFE9D5FF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          const Text('TỔNG THEO TỪNG THÁNG', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (monthlyTotals.isEmpty)
            const Text('Năm này chưa có chuyến ghe nào', style: TextStyle(fontSize: 18, color: Color(0xFF94A3B8)))
          else
            ...monthlyTotals.map((m) => _buildBoatStatTile('Tháng ${m['month']}', m['trips'], m['totalKg'])),
        ],
      ),
    );
  }

  Widget _buildByBoatTab() {
    if (_byBoatData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('TỔNG KHỐI LƯỢNG THEO SỐ GHE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          if (_byBoatData!.isEmpty)
            const Text('Chưa có dữ liệu ghe nào', style: TextStyle(fontSize: 18, color: Color(0xFF94A3B8)))
          else
            ..._byBoatData!.map((b) => _buildBoatStatTile(b['boatNumber'], b['trips'], b['totalKg'])),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int trips,
    required int totalKg,
    required double totalTons,
    required double? avgTons,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFDE047)),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Tổng chuyến', style: TextStyle(fontSize: 16, color: Color(0xFFE2E8F0))),
                  const SizedBox(height: 4),
                  Text('$trips chuyến', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              Container(width: 1.5, height: 50, color: Colors.white30),
              Column(
                children: [
                  const Text('Tổng khối lượng', style: TextStyle(fontSize: 16, color: Color(0xFFE2E8F0))),
                  const SizedBox(height: 4),
                  Text(
                    AppFormatters.formatKgToTons(totalKg),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          if (avgTons != null) ...[
            const Divider(color: Colors.white30, height: 28),
            Text(
              'Trung bình: ${avgTons.toStringAsFixed(3)} tấn / chuyến',
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoatStatTile(String label, int trips, int totalKg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_boat_filled_rounded, color: Color(0xFF38BDF8), size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('$trips chuyến nhập', style: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
          Text(
            AppFormatters.formatKgToTons(totalKg),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
          ),
        ],
      ),
    );
  }
}
