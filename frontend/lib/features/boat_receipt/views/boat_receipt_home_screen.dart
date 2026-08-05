import 'dart:async';
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
  bool _isDoubleBackWaiting = false;
  Timer? _doubleBackTimer;
  // 0=Tuần, 1=Tháng, 2=Năm
  int _summaryPeriod = 0;
  Map<String, dynamic>? _yearlySummary;

  @override
  void dispose() {
    _doubleBackTimer?.cancel();
    super.dispose();
  }

  void _handleBackPress() {
    // Tab 0 (Trang chủ / Sổ ghe): cần nhấn 2 lần mới thoát
    if (_currentNavIndex == 0) {
      if (_isDoubleBackWaiting) {
        _doubleBackTimer?.cancel();
        Navigator.of(context).pop();
        return;
      }
      _isDoubleBackWaiting = true;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhấn lần nữa để thoát'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _doubleBackTimer?.cancel();
      _doubleBackTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _isDoubleBackWaiting = false);
      });
      return;
    }
    // Cc tab khác: back theo thứ tự bottom nav (Thống kê→Phếu→Trang chủ, Cài đặt→Trang chủ)
    final previousIndex = switch (_currentNavIndex) {
      1 => 0, // Phếu → Trang chủ
      2 => 1, // Thống kê → Phếu
      3 => 0, // Cài đặt → Trang chủ
      _ => 0,
    };
    setState(() => _currentNavIndex = previousIndex);
    if (previousIndex == 0) _loadData();
  }

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
    if (showSpinner) setState(() => _isLoading = true);
    setState(() => _errorMessage = null);
    try {
      final now = DateTime.now();
      final yearStr = '${now.year}';
      final results = await Future.wait([
        _repository.getHomeSummary(),
        _repository.getWeeklyStats(null),
        _repository.getReceipts(limit: 5, sortBy: 'createdAt'),
        _repository.getYearlyStats(yearStr),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as HomeSummaryModel;
        _weeklySummary = results[1] as Map<String, dynamic>;
        _recentReceipts = [...results[2] as List<BoatReceiptModel>]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _yearlySummary = results[3] as Map<String, dynamic>;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
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
      ),
    );
  }

  Widget _home() => Scaffold(
    backgroundColor: ReceiptUi.canvas(context),
    appBar: ReceiptUi.appBar(
      context,
      'Sổ ghe',
      subtitle: 'Quản lý nhập trấu mỗi ngày',
      onBackPress: _handleBackPress,
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
                _summaryHeader(),
                const SizedBox(height: 10),
                _summaryCard(),
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

  Widget _summaryHeader() => Row(
    children: [
      const Expanded(
        child: Text(
          'Tổng quan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      ...[['Tuần', 0], ['Tháng', 1], ['Năm', 2]].map((item) {
        final label = item[0] as String;
        final idx = item[1] as int;
        final selected = _summaryPeriod == idx;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => setState(() => _summaryPeriod = idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? ReceiptColors.blueStrong
                    : ReceiptColors.blueSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : ReceiptColors.blueStrong,
                ),
              ),
            ),
          ),
        );
      }),
    ],
  );

  Widget _summaryCard() {
    final now = DateTime.now();
    final int trips;
    final int kg;
    final int amount;
    final String periodLabel;
    final IconData icon;
    final int statsTab;

    switch (_summaryPeriod) {
      case 0: // Tuần
        trips = (_weeklySummary?['trips'] as num?)?.toInt() ?? 0;
        kg = (_weeklySummary?['totalKg'] as num?)?.toInt() ?? 0;
        amount = (_weeklySummary?['totalAmount'] as num?)?.toInt() ?? 0;
        periodLabel = 'Tuần này';
        icon = Icons.view_week_outlined;
        statsTab = 0;
      case 1: // Tháng
        trips = _summary?.month.trips ?? 0;
        kg = _summary?.month.weightKg ?? 0;
        amount = _summary?.month.totalAmount ?? 0;
        periodLabel = 'Tháng ${AppFormatters.formatMonthYear(now)}';
        icon = Icons.calendar_month_outlined;
        statsTab = 1;
      case 2: // Năm
        trips = (_yearlySummary?['trips'] as num?)?.toInt() ?? 0;
        kg = (_yearlySummary?['totalKg'] as num?)?.toInt() ?? 0;
        amount = (_yearlySummary?['totalAmount'] as num?)?.toInt() ?? 0;
        periodLabel = 'Năm ${now.year}';
        icon = Icons.calendar_today_outlined;
        statsTab = 2;
      default:
        trips = 0; kg = 0; amount = 0;
        periodLabel = '';
        icon = Icons.bar_chart_outlined;
        statsTab = 0;
    }

    return ReceiptSurface(
      onTap: () => setState(() {
        _statsInitialTab = statsTab;
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
                  periodLabel,
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
                  '$trips chuyến',
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
              Icon(
                Icons.chevron_right_rounded,
                color: ReceiptColors.blueStrong,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receiptCard(BoatReceiptModel receipt) {
    final isAg = receipt.boatNumber.toUpperCase().contains('AG');
    final boatColor = isAg ? ReceiptColors.green : ReceiptColors.blueStrong;

    return ReceiptSurface(
      borderColor: boatColor.withValues(alpha: 0.5),
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
          BoatAvatarBadge(boatNumber: receipt.boatNumber, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.boatNumber,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: boatColor,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: boatColor,
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
                  color: ReceiptColors.muted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
