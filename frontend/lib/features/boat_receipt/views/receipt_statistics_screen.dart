import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../services/boat_receipt_repository.dart';
import 'receipt_bar_chart.dart';
import 'receipt_ui.dart';

enum _Period { week, month, year }

class ReceiptStatisticsScreen extends StatefulWidget {
  final int initialTabIndex;
  const ReceiptStatisticsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ReceiptStatisticsScreen> createState() =>
      _ReceiptStatisticsScreenState();
}

class _ReceiptStatisticsScreenState extends State<ReceiptStatisticsScreen> {
  final _repository = BoatReceiptRepository();
  late _Period _period;
  DateTime _anchor = DateTime.now();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _period = widget.initialTabIndex >= 2
        ? _Period.year
        : widget.initialTabIndex == 1
        ? _Period.month
        : _Period.week;
    _load();
  }

  String get _dateParam =>
      '${_anchor.year}-${_anchor.month.toString().padLeft(2, '0')}-${_anchor.day.toString().padLeft(2, '0')}';
  String get _monthParam =>
      '${_anchor.year}-${_anchor.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = switch (_period) {
        _Period.week => await _repository.getWeeklyStats(_dateParam),
        _Period.month => await _repository.getMonthlyStats(_monthParam),
        _Period.year => await _repository.getYearlyStats('${_anchor.year}'),
      };
      if (mounted) setState(() => _data = result);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectPeriod(_Period period) {
    setState(() {
      _period = period;
      _anchor = DateTime.now();
    });
    _load();
  }

  void _move(int direction) {
    setState(() {
      _anchor = switch (_period) {
        _Period.week => _anchor.add(Duration(days: 7 * direction)),
        _Period.month => DateTime(_anchor.year, _anchor.month + direction, 1),
        _Period.year => DateTime(_anchor.year + direction, 1, 1),
      };
    });
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ReceiptUi.canvas(context),
    appBar: ReceiptUi.appBar(
      context,
      'Thống kê',
      subtitle: 'Theo dõi chuyến, khối lượng và tiền trấu',
    ),
    body: Column(
      children: [
        _periodSelector(),
        _periodNavigator(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: ReceiptColors.blue),
                )
              : _errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: ReceiptErrorState(
                    message: _errorMessage!,
                    onRetry: _load,
                  ),
                )
              : RefreshIndicator(onRefresh: _load, child: _dashboard()),
        ),
      ],
    ),
  );

  Widget _periodSelector() => Container(
    color: ReceiptUi.surface(context),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: SegmentedButton<_Period>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: _Period.week,
          label: Text('Tuần'),
          icon: Icon(Icons.view_week_outlined),
        ),
        ButtonSegment(
          value: _Period.month,
          label: Text('Tháng'),
          icon: Icon(Icons.calendar_view_month_outlined),
        ),
        ButtonSegment(
          value: _Period.year,
          label: Text('Năm'),
          icon: Icon(Icons.calendar_today_outlined),
        ),
      ],
      selected: {_period},
      onSelectionChanged: (selected) => _selectPeriod(selected.first),
      style: ButtonStyle(
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        minimumSize: WidgetStateProperty.all(const Size(72, 52)),
      ),
    ),
  );

  Widget _periodNavigator() => Container(
    color: ReceiptUi.surface(context),
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
    child: Row(
      children: [
        IconButton(
          onPressed: () => _move(-1),
          tooltip: 'Kỳ trước',
          icon: const Icon(Icons.chevron_left_rounded, size: 30),
        ),
        Expanded(
          child: Text(
            _periodLabel(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: () => _move(1),
          tooltip: 'Kỳ sau',
          icon: const Icon(Icons.chevron_right_rounded, size: 30),
        ),
      ],
    ),
  );

  String _periodLabel() {
    if (_period == _Period.month) {
      return 'Tháng ${_anchor.month}/${_anchor.year}';
    }
    if (_period == _Period.year) return 'Năm ${_anchor.year}';
    final monday = _anchor.subtract(Duration(days: _anchor.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${monday.day}/${monday.month} – ${sunday.day}/${sunday.month}/${sunday.year}';
  }

  Widget _dashboard() {
    final data = _data ?? {};
    final chart = _chartPoints(data);
    final boats = List<Map<String, dynamic>>.from(
      (data['byBoat'] as List? ?? []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final totalKg = _int(data['totalKg']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _summary(data),
        const SizedBox(height: 14),
        ReceiptSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ReceiptSectionTitle('Biểu đồ khối lượng'),
              const SizedBox(height: 4),
              Text(
                _period == _Period.year
                    ? 'Đơn vị: tấn theo tháng'
                    : 'Đơn vị: tấn theo ngày',
                style: TextStyle(
                  fontSize: 14,
                  color: ReceiptUi.secondaryText(context),
                ),
              ),
              const SizedBox(height: 12),
              ReceiptBarChart(points: chart),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const ReceiptSectionTitle('Chi tiết theo ghe'),
        const SizedBox(height: 8),
        if (boats.isEmpty)
          const ReceiptEmptyState(
            icon: Icons.directions_boat_outlined,
            title: 'Chưa có chuyến ghe',
            message: 'Kỳ này chưa có phiếu nhập nào.',
          )
        else
          ...boats.map(
            (boat) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _boatCard(boat, totalKg),
            ),
          ),
      ],
    );
  }

  Widget _summary(Map<String, dynamic> data) {
    final trips = _int(data['trips']);
    final kg = _int(data['totalKg']);
    final amount = _int(data['totalAmount']);
    final avgPrice = _int(data['avgPricePerKg']);
    final avgKg = _int(data['avgKgPerTrip']);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ReceiptColors.blueStrong,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TỔNG KHỐI LƯỢNG',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFFBAE6FD),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.formatKgToTons(kg),
            style: const TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryChip(Icons.receipt_long_outlined, '$trips chuyến'),
              _summaryChip(
                Icons.scale_outlined,
                '${AppFormatters.formatKg(avgKg)}/chuyến',
              ),
              if (avgPrice > 0)
                _summaryChip(
                  Icons.sell_outlined,
                  AppFormatters.formatPricePerKg(avgPrice),
                ),
            ],
          ),
          if (amount > 0) ...[
            const Divider(color: Color(0xFF38BDF8), height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Tổng thành tiền',
                    style: TextStyle(fontSize: 16, color: Color(0xFFBAE6FD)),
                  ),
                ),
                Expanded(
                  child: Text(
                    AppFormatters.formatFullCurrency(amount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  List<ReceiptChartPoint> _chartPoints(Map<String, dynamic> data) {
    if (_period == _Period.year) {
      final rows = List.from(data['monthlyTotals'] ?? []);
      return rows.map((row) {
        final item = Map<String, dynamic>.from(row as Map);
        final raw = '${item['month'] ?? ''}';
        return ReceiptChartPoint(
          raw.length >= 7 ? raw.substring(5) : raw,
          _int(item['totalKg']) / 1000,
        );
      }).toList();
    }
    final rows = List.from(data['dailyTotals'] ?? []);
    return rows.map((row) {
      final item = Map<String, dynamic>.from(row as Map);
      final raw = '${item['date'] ?? ''}';
      return ReceiptChartPoint(
        raw.length >= 10 ? raw.substring(8) : raw,
        _int(item['totalKg']) / 1000,
      );
    }).toList();
  }

  Widget _boatCard(Map<String, dynamic> boat, int totalKg) {
    final kg = _int(boat['totalKg']);
    final trips = _int(boat['trips']);
    final amount = _int(boat['totalAmount']);
    final share = totalKg > 0 ? kg * 100 / totalKg : 0.0;
    final avg = trips > 0 ? kg ~/ trips : 0;
    return ReceiptSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ReceiptColors.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_boat_outlined,
                  color: ReceiptColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${boat['boatNumber'] ?? 'Không rõ'}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$trips chuyến · TB ${AppFormatters.formatKgToTons(avg)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: ReceiptUi.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                AppFormatters.formatKgToTons(kg),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: ReceiptColors.blueStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: share / 100,
              minHeight: 8,
              backgroundColor: ReceiptUi.line(context),
              color: ReceiptColors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${share.toStringAsFixed(1)}% tổng khối lượng',
                style: TextStyle(
                  fontSize: 14,
                  color: ReceiptUi.secondaryText(context),
                ),
              ),
              if (amount > 0)
                Expanded(
                  child: Text(
                    AppFormatters.formatCurrency(amount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ReceiptColors.green,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  int _int(dynamic value) => (value as num?)?.toInt() ?? 0;
}
