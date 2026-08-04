import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/services/auth_repository.dart';
import '../../settings/views/app_settings_screen.dart';
import '../models/boat_receipt_model.dart';
import '../models/statistics_model.dart';
import '../services/boat_receipt_repository.dart';
import 'add_boat_receipt_screen.dart';
import 'receipt_detail_screen.dart';
import 'receipt_history_screen.dart';
import 'receipt_statistics_screen.dart';
import 'receipt_ui.dart';

class BoatReceiptHomeScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeChanged;
  final AuthRepository? authRepository;

  const BoatReceiptHomeScreen({
    super.key,
    this.onThemeChanged,
    this.authRepository,
  });

  @override
  State<BoatReceiptHomeScreen> createState() => _BoatReceiptHomeScreenState();
}

class _BoatReceiptHomeScreenState extends State<BoatReceiptHomeScreen> {
  final _repository = BoatReceiptRepository();
  int _currentNavIndex = 0;
  int _statsInitialTab = 0;
  HomeSummaryModel? _summary;
  Map<String, dynamic>? _weeklySummary;
  List<BoatReceiptModel> _recentReceipts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _repository.getHomeSummary(),
        _repository.getWeeklyStats(null),
        _repository.getReceipts(limit: 5, sortBy: 'createdAt'),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as HomeSummaryModel;
        _weeklySummary = results[1] as Map<String, dynamic>;
        _recentReceipts = [...results[2] as List<BoatReceiptModel>]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _home(),
      const ReceiptHistoryScreen(),
      ReceiptStatisticsScreen(initialTabIndex: _statsInitialTab),
      AppSettingsScreen(
        currentModule: 'boat_receipts',
        onThemeChanged: widget.onThemeChanged ?? (_) {},
        authRepository: widget.authRepository,
      ),
    ];
    return Scaffold(
      backgroundColor: ReceiptUi.canvas(context),
      body: IndexedStack(index: _currentNavIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentNavIndex,
        height: 72,
        backgroundColor: ReceiptUi.surface(context),
        indicatorColor: ReceiptColors.blueSoft,
        onDestinationSelected: (index) {
          setState(() => _currentNavIndex = index);
          if (index == 0) _loadData();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: ReceiptColors.blue),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(
              Icons.receipt_long_rounded,
              color: ReceiptColors.blue,
            ),
            label: 'Phiếu',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(
              Icons.bar_chart_rounded,
              color: ReceiptColors.blue,
            ),
            label: 'Thống kê',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(
              Icons.settings_rounded,
              color: ReceiptColors.blue,
            ),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  Widget _home() => Scaffold(
    backgroundColor: ReceiptUi.canvas(context),
    appBar: ReceiptUi.appBar(
      context,
      'Sổ ghe',
      subtitle: 'Quản lý phiếu nhập trấu',
    ),
    body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: ReceiptColors.blue),
          )
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (_errorMessage != null) ...[
                  ReceiptErrorState(
                    message: _errorMessage!,
                    onRetry: _loadData,
                  ),
                  const SizedBox(height: 16),
                ],
                _primaryAction(),
                const SizedBox(height: 24),
                const ReceiptSectionTitle('Tổng quan'),
                const SizedBox(height: 10),
                _summaryCards(),
                const SizedBox(height: 24),
                ReceiptSectionTitle(
                  'Phiếu gần đây',
                  action: 'Xem tất cả',
                  onAction: () => setState(() => _currentNavIndex = 1),
                ),
                const SizedBox(height: 8),
                if (_recentReceipts.isEmpty)
                  const ReceiptEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Chưa có phiếu nào',
                    message: 'Chụp phiếu mới hoặc nhập thủ công để bắt đầu.',
                  )
                else
                  ..._recentReceipts.map(
                    (receipt) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _receiptCard(receipt),
                    ),
                  ),
              ],
            ),
          ),
  );

  Widget _primaryAction() => SizedBox(
    height: 64,
    child: FilledButton.icon(
      onPressed: () async {
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const AddBoatReceiptScreen()),
        );
        if (saved == true) _loadData();
      },
      style: FilledButton.styleFrom(
        backgroundColor: ReceiptColors.blueStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.document_scanner_outlined, size: 28),
      label: const Text(
        'Chụp phiếu mới',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
    ),
  );

  Widget _summaryCards() {
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _metricCard(
            'Tuần này',
            '${(_weeklySummary?['trips'] as num?)?.toInt() ?? 0} chuyến',
            (_weeklySummary?['totalKg'] as num?)?.toInt() ?? 0,
            (_weeklySummary?['totalAmount'] as num?)?.toInt() ?? 0,
            Icons.view_week_outlined,
            0,
          ),
          _metricCard(
            'Tháng ${AppFormatters.formatMonthYear(now)}',
            '${_summary?.month.trips ?? 0} chuyến',
            _summary?.month.weightKg ?? 0,
            _summary?.month.totalAmount ?? 0,
            Icons.calendar_month_outlined,
            1,
          ),
        ];
        if (constraints.maxWidth < 520) {
          return Column(
            children: [cards[0], const SizedBox(height: 10), cards[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }

  Widget _metricCard(
    String title,
    String trips,
    int kg,
    int amount,
    IconData icon,
    int tab,
  ) => ReceiptSurface(
    onTap: () => setState(() {
      _statsInitialTab = tab;
      _currentNavIndex = 2;
    }),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: ReceiptColors.blueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: ReceiptColors.blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              trips,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: ReceiptColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          AppFormatters.formatKgToTons(kg),
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: ReceiptColors.blueStrong,
          ),
        ),
        const SizedBox(height: 4),
        if (amount > 0) ...[
          const SizedBox(height: 6),
          Text(
            AppFormatters.formatCurrency(amount),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: ReceiptColors.green,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _receiptCard(BoatReceiptModel receipt) {
    final isAg = receipt.boatNumber.toUpperCase().startsWith('AG');
    final accent = isAg ? ReceiptColors.green : ReceiptColors.blue;
    final soft = isAg ? const Color(0xFFDCFCE7) : ReceiptColors.blueSoft;
    return ReceiptSurface(
      borderColor: accent.withValues(alpha: 0.55),
      surfaceColor: soft,
      onTap: () async {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptDetailScreen(receiptId: receipt.id),
          ),
        );
        if (updated == true) _loadData();
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_boat_outlined, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.boatNumber,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppFormatters.formatDate(receipt.receiptDate),
                  style: TextStyle(
                    fontSize: 15,
                    color: ReceiptUi.secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.formatKgToTons(receipt.weightKg),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ReceiptColors.blueStrong,
                ),
              ),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded, size: 22),
            ],
          ),
        ],
      ),
    );
  }
}
