import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../services/boat_receipt_repository.dart';
import 'receipt_detail_screen.dart';
import 'receipt_ui.dart';

enum _Period { week, month, year }

class ReceiptStatisticsScreen extends StatefulWidget {
  const ReceiptStatisticsScreen({super.key, this.initialTabIndex = 0});
  final int initialTabIndex;

  @override
  State<ReceiptStatisticsScreen> createState() =>
      _ReceiptStatisticsScreenState();
}

class _ReceiptStatisticsScreenState extends State<ReceiptStatisticsScreen> {
  final _repository = BoatReceiptRepository();
  late _Period _period;
  DateTime _anchor = DateTime.now();
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _previousData;
  String? _error;
  bool _loading = true;

  List<BoatReceiptModel> _periodReceipts = [];

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final previousAnchor = switch (_period) {
        _Period.week => _anchor.subtract(const Duration(days: 7)),
        _Period.month => DateTime(_anchor.year, _anchor.month - 1),
        _Period.year => DateTime(_anchor.year - 1),
      };
      final values = await Future.wait([
        _fetchStats(_anchor),
        _fetchStats(previousAnchor),
        _fetchPeriodReceipts(_anchor),
      ]);
      if (mounted) {
        setState(() {
          _data = values[0] as Map<String, dynamic>;
          _previousData = values[1] as Map<String, dynamic>;
          _periodReceipts = values[2] as List<BoatReceiptModel>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<BoatReceiptModel>> _fetchPeriodReceipts(DateTime anchor) {
    switch (_period) {
      case _Period.week:
        final startOfWeek = anchor.subtract(Duration(days: anchor.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final fromStr =
            '${startOfWeek.year}-${_two(startOfWeek.month)}-${_two(startOfWeek.day)}';
        final toStr =
            '${endOfWeek.year}-${_two(endOfWeek.month)}-${_two(endOfWeek.day)}';
        return _repository.getReceipts(from: fromStr, to: toStr, limit: 100);
      case _Period.month:
        final monthStr = '${anchor.year}-${_two(anchor.month)}';
        return _repository.getReceipts(month: monthStr, limit: 100);
      case _Period.year:
        final yearStr = '${anchor.year}';
        return _repository.getReceipts(year: yearStr, limit: 100);
    }
  }

  Future<Map<String, dynamic>> _fetchStats(DateTime anchor) =>
      switch (_period) {
        _Period.week => _repository.getWeeklyStats(
          '${anchor.year}-${_two(anchor.month)}-${_two(anchor.day)}',
        ),
        _Period.month => _repository.getMonthlyStats(
          '${anchor.year}-${_two(anchor.month)}',
        ),
        _Period.year => _repository.getYearlyStats('${anchor.year}'),
      };

  void _changePeriod(_Period value) {
    if (_period == value) return;
    setState(() {
      _period = value;
      _anchor = DateTime.now();
    });
    _load();
  }

  void _move(int step) {
    setState(() {
      _anchor = switch (_period) {
        _Period.week => _anchor.add(Duration(days: step * 7)),
        _Period.month => DateTime(_anchor.year, _anchor.month + step),
        _Period.year => DateTime(_anchor.year + step),
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
      subtitle: 'Xem tổng quan hoặc riêng từng ghe',
    ),
    body: Column(
      children: [
        _compactControls(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: ReceiptColors.blue),
                )
              : _error != null
              ? ReceiptErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _content()),
        ),
      ],
    ),
  );

  Widget _compactControls() => Container(
    color: ReceiptUi.surface(context),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: ReceiptUi.canvas(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(child: _periodButton('Tuần', _Period.week)),
              Expanded(child: _periodButton('Tháng', _Period.month)),
              Expanded(child: _periodButton('Năm', _Period.year)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _arrow(Icons.chevron_left_rounded, 'Kỳ trước', -1),
            Expanded(
              child: Text(
                _periodLabel(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _arrow(Icons.chevron_right_rounded, 'Kỳ sau', 1),
          ],
        ),
      ],
    ),
  );

  Widget _periodButton(String label, _Period value) {
    final selected = _period == value;
    return InkWell(
      onTap: () => _changePeriod(value),
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ReceiptUi.surface(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x160F172A),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: selected
                ? ReceiptColors.blueStrong
                : ReceiptUi.secondaryText(context),
          ),
        ),
      ),
    );
  }

  Widget _arrow(IconData icon, String tooltip, int step) =>
      IconButton.filledTonal(
        onPressed: () => _move(step),
        tooltip: tooltip,
        icon: Icon(icon, size: 28),
      );

  Widget _content() {
    final data = _data ?? const <String, dynamic>{};
    final boats = _boats(data);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _summary(data, boats),
        const SizedBox(height: 22),
        ReceiptSectionTitle(
          'Danh sách ${_periodReceipts.length} chuyến trong kỳ',
        ),
        const SizedBox(height: 10),
        if (_periodReceipts.isEmpty)
          const ReceiptEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Không có chuyến nào',
            message: 'Trong khoảng thời gian này chưa phát sinh phiếu cân trấu.',
          )
        else
          ..._periodReceipts.map(
            (receipt) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _receiptTile(receipt),
            ),
          ),
      ],
    );
  }

  Widget _receiptTile(BoatReceiptModel receipt) {
    final isAg = receipt.boatNumber.toUpperCase().contains('AG');
    final boatColor = isAg ? ReceiptColors.green : ReceiptColors.blueStrong;
    final totalAmount = receipt.weightKg * receipt.pricePerKg;

    return ReceiptSurface(
      borderColor: boatColor.withValues(alpha: 0.4),
      surfaceColor: ReceiptUi.surface(context),
      onTap: () async {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptDetailScreen(receiptId: receipt.id),
          ),
        );
        _load();
      },
      child: Row(
        children: [
          BoatAvatarBadge(boatNumber: receipt.boatNumber, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghe ${receipt.boatNumber}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: boatColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppFormatters.formatDate(receipt.receiptDate),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ReceiptUi.secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.formatKgToTons(receipt.weightKg),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: ReceiptUi.ink(context),
                ),
              ),
              if (totalAmount > 0) ...[
                const SizedBox(height: 3),
                Text(
                  AppFormatters.formatCurrency(totalAmount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ReceiptColors.green,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: ReceiptUi.secondaryText(context),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ReceiptSurface(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: ReceiptColors.blueSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: ReceiptColors.blueStrong, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: ReceiptUi.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, size: 28),
      ],
    ),
  );

  Future<void> _showDetails(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> boats,
  ) => _showStatsSheet('Chi tiết thống kê', [
    _comparison(data, _previousData ?? const {}),
    const SizedBox(height: 12),
    _operatingMetrics(data),
    const SizedBox(height: 12),
    _highlights(data, boats),
    const SizedBox(height: 12),
    _breakdown(data),
  ]);

  Future<void> _openBoatsScreen(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> boats,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _BoatStatsScreen(
        initialPeriod: _period,
        initialAnchor: _anchor,
        repository: _repository,
      ),
    ),
  );

  Future<void> _openBoatDetails(
    Map<String, dynamic> boat,
    Map<String, dynamic> data,
  ) {
    final boatNumber = '${boat['boatNumber'] ?? 'Không rõ'}';
    final kg = _int(boat['totalKg']);
    final trips = _int(boat['trips']);
    final amount = _int(boat['totalAmount']);
    final avgKg = trips == 0 ? 0 : kg ~/ trips;
    final avgPrice = kg == 0 ? 0 : amount ~/ kg;
    final boatReceipts = _periodReceipts
        .where(
          (r) =>
              r.boatNumber.trim().toUpperCase() ==
              boatNumber.trim().toUpperCase(),
        )
        .toList();

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          backgroundColor: ReceiptUi.canvas(routeContext),
          appBar: ReceiptUi.appBar(
            routeContext,
            'Ghe $boatNumber',
            subtitle: _periodLabel(),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _boatCard(boat, _int(data['totalKg'])),
              const SizedBox(height: 14),
              ReceiptSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ReceiptSectionTitle('Chi tiết hoạt động'),
                    const SizedBox(height: 10),
                    _detailRow('Số chuyến', '$trips chuyến'),
                    _detailRow(
                      'Trung bình/chuyến',
                      AppFormatters.formatKg(avgKg),
                    ),
                    if (avgPrice > 0)
                      _detailRow(
                        'Giá trung bình',
                        AppFormatters.formatPricePerKg(avgPrice),
                      ),
                    if (amount > 0)
                      _detailRow(
                        'Tổng thành tiền',
                        AppFormatters.formatFullCurrency(amount),
                        strong: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ReceiptSectionTitle(
                'Danh sách ${boatReceipts.length} chuyến của ghe $boatNumber',
              ),
              const SizedBox(height: 10),
              if (boatReceipts.isEmpty)
                const ReceiptEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Không có chuyến nào',
                  message: 'Ghe này chưa có phiếu nhập trong kỳ.',
                )
              else
                ...boatReceipts.map(
                  (receipt) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _receiptTile(receipt),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: ReceiptUi.secondaryText(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: strong ? 19 : 17,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                  color: strong ? ReceiptColors.green : null,
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _showStatsSheet(String title, List<Widget> children) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ReceiptUi.line(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );

  void _showOptionsBottomSheet(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> boats,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ReceiptUi.line(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Tùy chọn xem thống kê',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: ReceiptUi.ink(context),
                ),
              ),
              const SizedBox(height: 18),
              _actionCard(
                Icons.receipt_long_outlined,
                'Xem chi tiết thống kê',
                'So sánh và thông tin chuyên sâu',
                () {
                  Navigator.pop(sheetContext);
                  _showDetails(data, boats);
                },
              ),
              const SizedBox(height: 12),
              _actionCard(
                Icons.directions_boat_outlined,
                'Xem theo từng ghe',
                '${boats.length} ghe trong kỳ đang chọn',
                () {
                  Navigator.pop(sheetContext);
                  _openBoatsScreen(data, boats);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(Map<String, dynamic> data, List<Map<String, dynamic>> boats) {
    final trips = _int(data['trips']);
    final kg = _int(data['totalKg']);
    final amount = _int(data['totalAmount']);
    final avgPrice = _int(data['avgPricePerKg']);
    final avgKg = _int(data['avgKgPerTrip']);

    return ReceiptSurface(
      padding: EdgeInsets.zero,
      onTap: () => _showOptionsBottomSheet(data, boats),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ReceiptColors.blueStrong,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'TỔNG KHỐI LƯỢNG',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFBAE6FD),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Xem thêm',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppFormatters.formatKgToTons(kg),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _metricRow('Số chuyến', '$trips chuyến'),
            _metricRow('Trung bình/chuyến', AppFormatters.formatKg(avgKg)),
            if (avgPrice > 0)
              _metricRow(
                'Giá trung bình',
                AppFormatters.formatPricePerKg(avgPrice),
              ),
            if (amount > 0)
              _metricRow(
                'Tổng thành tiền',
                AppFormatters.formatFullCurrency(amount),
                strong: true,
              ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Bấm vào đây để chọn chế độ xem',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: Color(0xFFBAE6FD),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: strong ? 20 : 17,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _comparison(
    Map<String, dynamic> current,
    Map<String, dynamic> previous,
  ) {
    return ReceiptSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ReceiptSectionTitle('So với kỳ trước'),
          const SizedBox(height: 12),
          _changeRow(
            'Khối lượng',
            _int(current['totalKg']),
            _int(previous['totalKg']),
            AppFormatters.formatKgToTons,
          ),
          _changeRow(
            'Số chuyến',
            _int(current['trips']),
            _int(previous['trips']),
            (value) => '$value chuyến',
          ),
          _changeRow(
            'Thành tiền',
            _int(current['totalAmount']),
            _int(previous['totalAmount']),
            AppFormatters.formatCurrency,
          ),
        ],
      ),
    );
  }

  Widget _changeRow(
    String label,
    int current,
    int previous,
    String Function(int) formatter,
  ) {
    final change = previous == 0 ? null : (current - previous) * 100 / previous;
    final positive = (change ?? 0) >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: ReceiptUi.secondaryText(context),
                  ),
                ),
                Text(
                  formatter(current),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: change == null
                  ? ReceiptUi.line(context)
                  : (positive
                        ? ReceiptColors.greenSoft
                        : const Color(0xFFFEE2E2)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              change == null
                  ? 'Chưa có kỳ trước'
                  : '${positive ? '+' : ''}${change.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: change == null
                    ? ReceiptUi.secondaryText(context)
                    : (positive ? ReceiptColors.green : ReceiptColors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _operatingMetrics(Map<String, dynamic> data) {
    final trips = _int(data['trips']);
    final kg = _int(data['totalKg']);
    final amount = _int(data['totalAmount']);
    final activeDays = _timeRows(
      data,
    ).where((row) => _int(row['trips']) > 0).length;
    final values = <(String, String, IconData)>[
      ('Ngày có chuyến', '$activeDays ngày', Icons.event_available_outlined),
      (
        'TB chuyến/ngày',
        activeDays == 0 ? '0' : (trips / activeDays).toStringAsFixed(1),
        Icons.route_outlined,
      ),
      (
        'TB khối lượng/chuyến',
        AppFormatters.formatKg(trips == 0 ? 0 : kg ~/ trips),
        Icons.scale_outlined,
      ),
      (
        'TB tiền/chuyến',
        AppFormatters.formatCurrency(trips == 0 ? 0 : amount ~/ trips),
        Icons.payments_outlined,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReceiptSectionTitle('Hiệu quả hoạt động'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: values
                  .map(
                    (item) => SizedBox(
                      width: width,
                      child: ReceiptSurface(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.$3, color: ReceiptColors.blue),
                            const SizedBox(height: 8),
                            Text(
                              item.$1,
                              style: TextStyle(
                                fontSize: 13,
                                color: ReceiptUi.secondaryText(context),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.$2,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _highlights(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> boats,
  ) {
    final rows =
        _timeRows(data).where((row) => _int(row['totalKg']) > 0).toList()
          ..sort((a, b) => _int(b['totalKg']).compareTo(_int(a['totalKg'])));
    final topBoat = boats.isEmpty ? null : boats.first;
    return ReceiptSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ReceiptSectionTitle('Điểm nổi bật'),
          const SizedBox(height: 10),
          if (rows.isNotEmpty)
            _insight(
              Icons.emoji_events_outlined,
              'Ngày/tháng cao nhất',
              '${_rowLabel(rows.first)} · ${AppFormatters.formatKgToTons(_int(rows.first['totalKg']))}',
            ),
          if (rows.length > 1)
            _insight(
              Icons.south_outlined,
              'Ngày/tháng thấp nhất có chuyến',
              '${_rowLabel(rows.last)} · ${AppFormatters.formatKgToTons(_int(rows.last['totalKg']))}',
            ),
          if (topBoat != null)
            _insight(
              Icons.directions_boat_outlined,
              'Ghe nhiều hàng nhất',
              '${topBoat['boatNumber']} · ${AppFormatters.formatKgToTons(_int(topBoat['totalKg']))}',
            ),
          if (rows.isEmpty && topBoat == null)
            Text(
              'Chưa có dữ liệu trong kỳ này.',
              style: TextStyle(
                fontSize: 16,
                color: ReceiptUi.secondaryText(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _insight(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 23, color: ReceiptColors.blue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: ReceiptUi.secondaryText(context),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _breakdown(Map<String, dynamic> data) {
    final points = _timeRows(data);
    return ReceiptSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ReceiptSectionTitle('Chi tiết từng kỳ'),
          const SizedBox(height: 8),
          if (points.isEmpty)
            Text(
              'Chưa có dữ liệu.',
              style: TextStyle(
                fontSize: 16,
                color: ReceiptUi.secondaryText(context),
              ),
            )
          else
            ...points.map((row) => _periodRow(row)),
        ],
      ),
    );
  }

  Widget _periodRow(Map<String, dynamic> row) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _rowLabel(row),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '${_int(row['trips'])} chuyến',
          style: TextStyle(
            fontSize: 14,
            color: ReceiptUi.secondaryText(context),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          AppFormatters.formatKgToTons(_int(row['totalKg'])),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: ReceiptColors.blueStrong,
          ),
        ),
      ],
    ),
  );

  Widget _boatHeader(
    List<Map<String, dynamic>> boats,
    Map<String, dynamic> data,
  ) => ReceiptSurface(
    child: Row(
      children: [
        const Icon(
          Icons.directions_boat_rounded,
          size: 34,
          color: ReceiptColors.blue,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thống kê theo ghe',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              Text(
                '${boats.length} ghe · ${_int(data['trips'])} chuyến',
                style: TextStyle(
                  fontSize: 15,
                  color: ReceiptUi.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _boatCard(
    Map<String, dynamic> boat,
    int totalKg, {
    VoidCallback? onTap,
  }) {
    final kg = _int(boat['totalKg']);
    final trips = _int(boat['trips']);
    final amount = _int(boat['totalAmount']);
    final share = totalKg == 0 ? 0.0 : kg / totalKg;
    final isAg = '${boat['boatNumber'] ?? ''}'.toUpperCase().startsWith('AG');
    final accent = isAg ? ReceiptColors.green : ReceiptColors.blueStrong;
    return ReceiptSurface(
      onTap: onTap,
      borderColor: accent.withValues(alpha: 0.6),
      surfaceColor: ReceiptUi.surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${boat['boatNumber'] ?? 'Không rõ'}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
              Text(
                AppFormatters.formatKgToTons(kg),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 28, color: accent),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$trips chuyến · TB ${AppFormatters.formatKgToTons(trips == 0 ? 0 : kg ~/ trips)}/chuyến',
            style: TextStyle(
              fontSize: 15,
              color: ReceiptUi.secondaryText(context),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 9,
              backgroundColor: ReceiptUi.line(context),
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(share * 100).toStringAsFixed(1)}% tổng khối lượng',
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

  List<Map<String, dynamic>> _boats(Map<String, dynamic> data) =>
      List<Map<String, dynamic>>.from(
        (data['byBoat'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
  List<Map<String, dynamic>> _timeRows(Map<String, dynamic> data) =>
      List<Map<String, dynamic>>.from(
        ((data[_period == _Period.year ? 'monthlyTotals' : 'dailyTotals'])
                    as List? ??
                const [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
  String _rowLabel(Map<String, dynamic> row) {
    final raw = '${row[_period == _Period.year ? 'month' : 'date'] ?? ''}';
    if (_period == _Period.year && raw.length >= 7) {
      return 'T${int.tryParse(raw.substring(5)) ?? raw.substring(5)}';
    }
    if (raw.length >= 10) {
      final date = DateTime.tryParse(raw);
      final weekday = date == null ? '' : _shortWeekday(date);
      return '$weekday ${raw.substring(8)}/${raw.substring(5, 7)}'.trim();
    }
    return raw;
  }

  String _periodLabel() {
    if (_period == _Period.month) {
      return 'Tháng ${_anchor.month}/${_anchor.year}';
    }
    if (_period == _Period.year) return 'Năm ${_anchor.year}';
    final monday = _anchor.subtract(Duration(days: _anchor.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return 'Thứ Hai ${monday.day}/${monday.month} – Chủ Nhật ${sunday.day}/${sunday.month}';
  }

  String _shortWeekday(DateTime date) => switch (date.weekday) {
    DateTime.monday => 'T2',
    DateTime.tuesday => 'T3',
    DateTime.wednesday => 'T4',
    DateTime.thursday => 'T5',
    DateTime.friday => 'T6',
    DateTime.saturday => 'T7',
    _ => 'CN',
  };

  String _two(int value) => value.toString().padLeft(2, '0');
  int _int(dynamic value) => (value as num?)?.toInt() ?? 0;
}

// ── Màn thống kê theo ghe – có chọn kỳ và chọn ghe ──────────────────────────

class _BoatStatsScreen extends StatefulWidget {
  const _BoatStatsScreen({
    required this.initialPeriod,
    required this.initialAnchor,
    required this.repository,
  });
  final _Period initialPeriod;
  final DateTime initialAnchor;
  final BoatReceiptRepository repository;

  @override
  State<_BoatStatsScreen> createState() => _BoatStatsScreenState();
}

class _BoatStatsScreenState extends State<_BoatStatsScreen> {
  late _Period _period;
  late DateTime _anchor;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  List<BoatReceiptModel> _periodReceipts = [];

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    _anchor = widget.initialAnchor;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _fetchStats(_anchor),
        _fetchReceipts(_anchor),
      ]);
      if (mounted) {
        setState(() {
          _data = results[0] as Map<String, dynamic>;
          _periodReceipts = results[1] as List<BoatReceiptModel>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>> _fetchStats(DateTime anchor) =>
      switch (_period) {
        _Period.week => widget.repository.getWeeklyStats(
          '${anchor.year}-${_two(anchor.month)}-${_two(anchor.day)}',
        ),
        _Period.month => widget.repository.getMonthlyStats(
          '${anchor.year}-${_two(anchor.month)}',
        ),
        _Period.year => widget.repository.getYearlyStats('${anchor.year}'),
      };

  Future<List<BoatReceiptModel>> _fetchReceipts(DateTime anchor) {
    switch (_period) {
      case _Period.week:
        final start = anchor.subtract(Duration(days: anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return widget.repository.getReceipts(
          from: '${start.year}-${_two(start.month)}-${_two(start.day)}',
          to: '${end.year}-${_two(end.month)}-${_two(end.day)}',
          limit: 200,
        );
      case _Period.month:
        return widget.repository.getReceipts(
          month: '${anchor.year}-${_two(anchor.month)}',
          limit: 200,
        );
      case _Period.year:
        return widget.repository.getReceipts(year: '${anchor.year}', limit: 200);
    }
  }

  void _changePeriod(_Period p) {
    if (_period == p) return;
    setState(() { _period = p; _anchor = DateTime.now(); });
    _load();
  }

  void _move(int step) {
    setState(() {
      _anchor = switch (_period) {
        _Period.week => _anchor.add(Duration(days: step * 7)),
        _Period.month => DateTime(_anchor.year, _anchor.month + step),
        _Period.year => DateTime(_anchor.year + step),
      };
    });
    _load();
  }

  String _periodLabel() {
    if (_period == _Period.month) return 'Tháng ${_anchor.month}/${_anchor.year}';
    if (_period == _Period.year) return 'Năm ${_anchor.year}';
    final monday = _anchor.subtract(Duration(days: _anchor.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${_two(monday.day)}/${_two(monday.month)} – ${_two(sunday.day)}/${_two(sunday.month)}';
  }

  List<Map<String, dynamic>> _boats() => List<Map<String, dynamic>>.from(
    ((_data ?? const {})['byBoat'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map)),
  );

  int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final boats = _boats();
    final data = _data ?? const <String, dynamic>{};
    return Scaffold(
      backgroundColor: ReceiptUi.canvas(context),
      appBar: ReceiptUi.appBar(
        context,
        'Thống kê theo ghe',
        subtitle: _periodLabel(),
      ),
      body: Column(
        children: [
          // ── Bộ chọn kỳ + điều hướng ─────────────────────────────────────
          Container(
            color: ReceiptUi.surface(context),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ReceiptUi.canvas(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _periodBtn('Tuần', _Period.week)),
                      Expanded(child: _periodBtn('Tháng', _Period.month)),
                      Expanded(child: _periodBtn('Năm', _Period.year)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _arrow(Icons.chevron_left_rounded, -1),
                    Expanded(
                      child: Text(
                        _periodLabel(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _arrow(Icons.chevron_right_rounded, 1),
                  ],
                ),
              ],
            ),
          ),
          // ── Nội dung ─────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: ReceiptColors.blue),
                  )
                : _error != null
                ? ReceiptErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      children: [
                        // Tổng kỳ
                        _summaryBanner(data),
                        const SizedBox(height: 14),
                        if (boats.isEmpty)
                          const ReceiptEmptyState(
                            icon: Icons.directions_boat_outlined,
                            title: 'Chưa có chuyến ghe',
                            message: 'Kỳ này chưa có phiếu nhập.',
                          )
                        else ...[
                          ...boats.map(
                            (boat) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _boatCard(boat, _int(data['totalKg']), boats),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _periodBtn(String label, _Period value) {
    final selected = _period == value;
    return InkWell(
      onTap: () => _changePeriod(value),
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ReceiptColors.blueStrong : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : ReceiptUi.secondaryText(context),
          ),
        ),
      ),
    );
  }

  Widget _arrow(IconData icon, int step) => IconButton.filledTonal(
    onPressed: () => _move(step),
    icon: Icon(icon, size: 28),
  );

  Widget _summaryBanner(Map<String, dynamic> data) {
    final trips = _int(data['trips']);
    final kg = _int(data['totalKg']);
    final amount = _int(data['totalAmount']);
    final boats = _boats();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ReceiptColors.blueStrong, Color(0xFF2A88DC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TỔNG KỲ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFBAE6FD),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppFormatters.formatKgToTons(kg),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (amount > 0)
                  Text(
                    AppFormatters.formatCurrency(amount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF86EFAC),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bannerChip('${boats.length} ghe', Icons.directions_boat_rounded),
              const SizedBox(height: 8),
              _bannerChip('$trips chuyến', Icons.receipt_long_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerChip(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _boatCard(
    Map<String, dynamic> boat,
    int totalKg,
    List<Map<String, dynamic>> boats,
  ) {
    final kg = _int(boat['totalKg']);
    final trips = _int(boat['trips']);
    final amount = _int(boat['totalAmount']);
    final share = totalKg == 0 ? 0.0 : kg / totalKg;
    final boatNumber = '${boat['boatNumber'] ?? 'Không rõ'}';
    final isAg = boatNumber.toUpperCase().startsWith('AG');
    final accent = isAg ? ReceiptColors.green : ReceiptColors.blueStrong;
    final avgKg = trips == 0 ? 0 : kg ~/ trips;

    return ReceiptSurface(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _BoatDetailScreen(
            boatNumber: boatNumber,
            boat: boat,
            totalKg: totalKg,
            periodLabel: _periodLabel(),
            receipts: _periodReceipts
                .where(
                  (r) =>
                      r.boatNumber.trim().toUpperCase() ==
                      boatNumber.trim().toUpperCase(),
                )
                .toList(),
            allBoats: boats,
            onBoatSelected: (other) => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => _BoatDetailScreen(
                  boatNumber: '${other['boatNumber']}',
                  boat: other,
                  totalKg: totalKg,
                  periodLabel: _periodLabel(),
                  receipts: _periodReceipts
                      .where(
                        (r) =>
                            r.boatNumber.trim().toUpperCase() ==
                            '${other['boatNumber']}'.trim().toUpperCase(),
                      )
                      .toList(),
                  allBoats: boats,
                  onBoatSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
      borderColor: accent.withValues(alpha: 0.5),
      surfaceColor: ReceiptUi.surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BoatAvatarBadge(boatNumber: boatNumber, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      boatNumber,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                    Text(
                      '$trips chuyến · TB ${AppFormatters.formatKgToTons(avgKg)}/chuyến',
                      style: TextStyle(
                        fontSize: 14,
                        color: ReceiptUi.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.formatKgToTons(kg),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                  if (amount > 0)
                    Text(
                      AppFormatters.formatCurrency(amount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ReceiptColors.green,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 26, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              backgroundColor: ReceiptUi.line(context),
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(share * 100).toStringAsFixed(1)}% tổng khối lượng kỳ này',
            style: TextStyle(
              fontSize: 13,
              color: ReceiptUi.secondaryText(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chi tiết 1 ghe – có nút chọn ghe khác ────────────────────────────────────

class _BoatDetailScreen extends StatelessWidget {
  const _BoatDetailScreen({
    required this.boatNumber,
    required this.boat,
    required this.totalKg,
    required this.periodLabel,
    required this.receipts,
    required this.allBoats,
    required this.onBoatSelected,
  });

  final String boatNumber;
  final Map<String, dynamic> boat;
  final int totalKg;
  final String periodLabel;
  final List<BoatReceiptModel> receipts;
  final List<Map<String, dynamic>> allBoats;
  final void Function(Map<String, dynamic> boat) onBoatSelected;

  int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final kg = _int(boat['totalKg']);
    final trips = _int(boat['trips']);
    final amount = _int(boat['totalAmount']);
    final avgKg = trips == 0 ? 0 : kg ~/ trips;
    final avgPrice = kg == 0 ? 0 : amount ~/ kg;
    final share = totalKg == 0 ? 0.0 : kg / totalKg;
    final isAg = boatNumber.toUpperCase().startsWith('AG');
    final accent = isAg ? ReceiptColors.green : ReceiptColors.blueStrong;

    return Scaffold(
      backgroundColor: ReceiptUi.canvas(context),
      appBar: ReceiptUi.appBar(
        context,
        'Ghe $boatNumber',
        subtitle: periodLabel,
        actions: [
          if (allBoats.length > 1)
            IconButton(
              tooltip: 'Chọn ghe khác',
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: () => _pickBoat(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          // Banner tổng
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAg
                    ? [ReceiptColors.green, const Color(0xFF059669)]
                    : [ReceiptColors.blueStrong, const Color(0xFF2A88DC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BoatAvatarBadge(boatNumber: boatNumber, size: 50),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            boatNumber,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            periodLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFBAE6FD),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  AppFormatters.formatKgToTons(kg),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _chip('$trips chuyến', Icons.receipt_long_rounded),
                    _chip(
                      'TB ${AppFormatters.formatKgToTons(avgKg)}/chuyến',
                      Icons.scale_outlined,
                    ),
                    if (avgPrice > 0)
                      _chip(
                        AppFormatters.formatPricePerKg(avgPrice),
                        Icons.payments_outlined,
                      ),
                    if (amount > 0)
                      _chip(
                        AppFormatters.formatCurrency(amount),
                        Icons.attach_money_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(share * 100).toStringAsFixed(1)}% tổng khối lượng kỳ này',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFBAE6FD),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // Danh sách chuyến
          Text(
            '${receipts.length} chuyến trong kỳ',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (receipts.isEmpty)
            const ReceiptEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Không có chuyến nào',
              message: 'Ghe này chưa có phiếu nhập trong kỳ.',
            )
          else
            ...receipts.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _receiptTile(context, r, accent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  void _pickBoat(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ReceiptColors.line,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Chọn ghe để xem',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              ...allBoats.map((b) {
                final bn = '${b['boatNumber']}';
                final isSelected =
                    bn.trim().toUpperCase() == boatNumber.trim().toUpperCase();
                final isAgB = bn.toUpperCase().startsWith('AG');
                final accentB =
                    isAgB ? ReceiptColors.green : ReceiptColors.blueStrong;
                return ListTile(
                  leading: BoatAvatarBadge(boatNumber: bn, size: 40),
                  title: Text(
                    bn,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? accentB : null,
                    ),
                  ),
                  subtitle: Text(
                    '${_int(b['trips'])} chuyến · ${AppFormatters.formatKgToTons(_int(b['totalKg']))}',
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: accentB)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!isSelected) onBoatSelected(b);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptTile(BuildContext context, BoatReceiptModel r, Color accent) {
    final totalAmount = r.weightKg * r.pricePerKg;
    return ReceiptSurface(
      borderColor: accent.withValues(alpha: 0.35),
      surfaceColor: ReceiptUi.surface(context),
      onTap: () => Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ReceiptDetailScreen(receiptId: r.id)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppFormatters.formatDate(r.receiptDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (r.note?.isNotEmpty == true)
                  Text(
                    r.note!,
                    style: TextStyle(
                      fontSize: 14,
                      color: ReceiptUi.secondaryText(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.formatKgToTons(r.weightKg),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              if (totalAmount > 0)
                Text(
                  AppFormatters.formatCurrency(totalAmount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ReceiptColors.green,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: ReceiptUi.secondaryText(context)),
        ],
      ),
    );
  }
}

