import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../services/boat_receipt_repository.dart';

class ReceiptStatisticsScreen extends StatefulWidget {
  final int initialTabIndex;

  const ReceiptStatisticsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

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
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 28),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text('THỐNG KÊ SỔ GHE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? const Color(0xFFFDE047) : const Color(0xFF0284C7),
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 16),
          labelColor: isDark ? const Color(0xFFFDE047) : const Color(0xFF0284C7),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
    final trips = (_dailyData!['trips'] as num?)?.toInt() ?? 0;
    final totalKg = (_dailyData!['totalKg'] as num?)?.toInt() ?? 0;
    final totalTons = (_dailyData!['totalTons'] as num?)?.toDouble() ?? 0.0;
    final avgTons = (_dailyData!['avgTonsPerTrip'] as num?)?.toDouble() ?? 0.0;
    final byBoat = List.from(_dailyData!['byBoat'] ?? []);

    final totalAmount = (_dailyData!['totalAmount'] as num?)?.toInt() ?? 0;
    final avgPricePerKg = (_dailyData!['avgPricePerKg'] as num?)?.toInt() ?? 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            totalAmount: totalAmount,
            avgPricePerKg: avgPricePerKg,
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          const SizedBox(height: 24),
          Text('PHÂN BỔ THEO GHE TRONG NGÀY', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 12),
          if (byBoat.isEmpty)
            Text('Hôm nay chưa có chuyến ghe nào', style: TextStyle(fontSize: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))
          else
            ...byBoat.map((b) => _buildBoatStatTile(b['boatNumber'], (b['trips'] as num).toInt(), (b['totalKg'] as num).toInt())),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab() {
    if (_monthlyData == null) return const SizedBox();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final trips = (_monthlyData!['trips'] as num?)?.toInt() ?? 0;
    final totalKg = (_monthlyData!['totalKg'] as num?)?.toInt() ?? 0;
    final totalTons = (_monthlyData!['totalTons'] as num?)?.toDouble() ?? 0.0;
    final avgTons = (_monthlyData!['avgTonsPerTrip'] as num?)?.toDouble() ?? 0.0;
    final highestDay = _monthlyData!['highestDay'];
    final byBoat = List.from(_monthlyData!['byBoat'] ?? []);

    final totalAmount = (_monthlyData!['totalAmount'] as num?)?.toInt() ?? 0;
    final avgPricePerKg = (_monthlyData!['avgPricePerKg'] as num?)?.toInt() ?? 0;

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
            totalAmount: totalAmount,
            avgPricePerKg: avgPricePerKg,
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
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                        Text('Ngày nhập nhiều trấu nhất', style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          '${highestDay['date']} · ${AppFormatters.formatKgToTons((highestDay['totalKg'] as num).toInt())} (${highestDay['trips']} chuyến)',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFFDE047) : const Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          Text('TỔNG THEO TỪNG GHE TRONG THÁNG', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 12),
          if (byBoat.isEmpty)
            Text('Tháng này chưa có chuyến ghe nào', style: TextStyle(fontSize: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))
          else
            ...byBoat.map((b) => _buildBoatStatTile(b['boatNumber'], (b['trips'] as num).toInt(), (b['totalKg'] as num).toInt())),
        ],
      ),
    );
  }

  Widget _buildYearlyTab() {
    if (_yearlyData == null) return const SizedBox();
    final trips = (_yearlyData!['trips'] as num?)?.toInt() ?? 0;
    final totalKg = (_yearlyData!['totalKg'] as num?)?.toInt() ?? 0;
    final totalTons = (_yearlyData!['totalTons'] as num?)?.toDouble() ?? 0.0;
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
                          'Tháng ${highestMonth['month']} · ${AppFormatters.formatKgToTons((highestMonth['totalKg'] as num).toInt())}',
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
            ...monthlyTotals.map((m) => _buildBoatStatTile('Tháng ${m['month']}', (m['trips'] as num).toInt(), (m['totalKg'] as num).toInt())),
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
            ..._byBoatData!.map((b) => _buildBoatStatTile(b['boatNumber'], (b['trips'] as num).toInt(), (b['totalKg'] as num).toInt())),
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
    int totalAmount = 0,
    int avgPricePerKg = 0,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
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
                  const Text('Tổng chuyến', style: TextStyle(fontSize: 15, color: Color(0xFFE2E8F0))),
                  const SizedBox(height: 4),
                  Text('$trips chuyến', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              Container(width: 1.5, height: 45, color: Colors.white30),
              Column(
                children: [
                  const Text('Tổng khối lượng', style: TextStyle(fontSize: 15, color: Color(0xFFE2E8F0))),
                  const SizedBox(height: 4),
                  Text(
                    AppFormatters.formatKgToTons(totalKg),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          if (totalAmount > 0) ...[
            const Divider(color: Colors.white30, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Tổng tiền trấu', style: TextStyle(fontSize: 15, color: Color(0xFFFDE047))),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.formatCurrency(totalAmount),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFFDE047)),
                    ),
                  ],
                ),
                if (avgPricePerKg > 0) ...[
                  Container(width: 1.5, height: 45, color: Colors.white30),
                  Column(
                    children: [
                      const Text('Giá trấu trung bình', style: TextStyle(fontSize: 15, color: Color(0xFFFDE047))),
                      const SizedBox(height: 4),
                      Text(
                        AppFormatters.formatPricePerKg(avgPricePerKg),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFDE047)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
          if (avgTons != null) ...[
            const SizedBox(height: 12),
            Text(
              'Trung bình: ${avgTons.toStringAsFixed(3)} tấn / chuyến',
              style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoatStatTile(String label, int trips, int totalKg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                child: const Icon(Icons.directions_boat_filled_rounded, color: Color(0xFF0284C7), size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text('$trips chuyến nhập', style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          Text(
            AppFormatters.formatKgToTons(totalKg),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
          ),
        ],
      ),
    );
  }
}
