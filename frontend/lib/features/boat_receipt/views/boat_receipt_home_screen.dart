import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/services/auth_repository.dart';
import '../../settings/views/app_settings_screen.dart';
import '../models/boat_receipt_model.dart';
import '../models/statistics_model.dart';
import '../services/boat_receipt_repository.dart';
import '../services/receipt_cache.dart';
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
  final _cache = ReceiptCache();
  int _currentNavIndex = 0;
  int _statsInitialTab = 0;
  HomeSummaryModel? _summary;
  Map<String, dynamic>? _weeklySummary;
  List<BoatReceiptModel> _recentReceipts = [];
  bool _isLoading = true;
  bool _usingCachedData = false;
  DateTime? _cacheSavedAt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await _cache.loadHome();
    if (cached != null && mounted) {
      setState(() {
        _summary = cached.summary;
        _weeklySummary = cached.weeklySummary;
        _recentReceipts = cached.recentReceipts;
        _cacheSavedAt = cached.savedAt;
        _usingCachedData = true;
        _isLoading = false;
      });
    }
    await _loadData(showSpinner: cached == null);
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    setState(() {
      _isLoading = showSpinner;
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
        _usingCachedData = false;
      });
      await _cache.saveHome(
        summary: _summary!,
        weeklySummary: _weeklySummary!,
        recentReceipts: _recentReceipts,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          if (_summary == null) {
            _errorMessage = error.toString();
          } else {
            _usingCachedData = true;
          }
        });
      }
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
      subtitle: 'Quản lý nhập trấu mỗi ngày',
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
                _welcomeCard(),
                if (_usingCachedData) ...[
                  const SizedBox(height: 10),
                  _cachedDataNotice(),
                ],
                const SizedBox(height: 14),
                _primaryAction(),
                const SizedBox(height: 22),
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

  Widget _cachedDataNotice() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF2D38A)),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: Color(0xFF9A6500)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            _cacheSavedAt == null
                ? 'Đang hiển thị dữ liệu gần nhất'
                : 'Dữ liệu gần nhất lúc ${_two(_cacheSavedAt!.hour)}:${_two(_cacheSavedAt!.minute)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF704B00),
            ),
          ),
        ),
        TextButton(onPressed: () => _loadData(), child: const Text('Thử lại')),
      ],
    ),
  );

  String _two(int value) => value.toString().padLeft(2, '0');

  Widget _welcomeCard() {
    final displayName = widget.authRepository?.currentUser?.displayName;
    final name = displayName == null || displayName.trim().isEmpty
        ? 'chị Mười'
        : displayName.trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6542B5), Color(0xFF9A7BE1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ReceiptColors.blue.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.directions_boat_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hôm nay mình nhập phiếu mới nhé!',
                  style: TextStyle(
                    color: Color(0xFFF2ECFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.add_a_photo_outlined, size: 27),
      label: const Text(
        'Tạo phiếu mới',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: ReceiptColors.blueSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                trips,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: ReceiptColors.blueStrong,
                ),
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
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Xem thống kê',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ReceiptColors.blueStrong,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, color: ReceiptColors.blueStrong),
          ],
        ),
      ],
    ),
  );

  Widget _receiptCard(BoatReceiptModel receipt) {
    return ReceiptSurface(
      borderColor: ReceiptColors.line,
      surfaceColor: ReceiptUi.surface(context),
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
              color: ReceiptColors.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_boat_outlined,
              color: ReceiptColors.blueStrong,
            ),
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
              if (receipt.computedTotalAmount > 0)
                Text(
                  AppFormatters.formatCurrency(receipt.computedTotalAmount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ReceiptColors.green,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: ReceiptColors.blueStrong,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
