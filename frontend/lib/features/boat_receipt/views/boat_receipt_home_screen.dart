import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/services/auth_repository.dart';
import '../../settings/views/app_settings_screen.dart';
import '../models/boat_receipt_model.dart';
import '../models/statistics_model.dart';
import '../services/boat_receipt_repository.dart';
import 'add_boat_receipt_screen.dart';
import 'receipt_confirmation_screen.dart';
import 'receipt_history_screen.dart';
import 'receipt_detail_screen.dart';
import 'receipt_statistics_screen.dart';

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
  final BoatReceiptRepository _repository = BoatReceiptRepository();
  int _currentNavIndex = 0;
  int _statsInitialTab = 0;

  HomeSummaryModel? _summary;
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
      final summary = await _repository.getHomeSummary();
      final recent = await _repository.getReceipts(limit: 5);

      setState(() {
        _summary = summary;
        _recentReceipts = recent;
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

    final List<Widget> pages = [
      _buildHomeContent(),
      const ReceiptHistoryScreen(),
      ReceiptStatisticsScreen(initialTabIndex: _statsInitialTab),
      AppSettingsScreen(
        currentModule: 'boat_receipts',
        onThemeChanged: widget.onThemeChanged ?? (_) {},
        authRepository: widget.authRepository,
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: IndexedStack(
        index: _currentNavIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 70,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          indicatorColor: const Color(0xFF0284C7),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 14,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? (isDark ? Colors.white : const Color(0xFF0284C7))
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 26,
              color: states.contains(WidgetState.selected)
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentNavIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentNavIndex = index;
            });
            if (index == 0) _loadData();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.directions_boat_filled_rounded),
              selectedIcon: Icon(Icons.directions_boat_filled_rounded, color: Colors.white),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              selectedIcon: Icon(Icons.history_rounded, color: Colors.white),
              label: 'Phiếu',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: Colors.white),
              label: 'Thống kê',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_rounded),
              selectedIcon: Icon(Icons.settings_rounded, color: Colors.white),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 28),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'SỔ GHE NHẬP trấu',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF991B1B).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF43F5E)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFF43F5E), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(_errorMessage!, style: const TextStyle(fontSize: 16, color: Color(0xFFFECDD3), fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                              onPressed: _loadData,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Summary Stats Cards (Stacked 1 row per card)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _statsInitialTab = 0;
                          _currentNavIndex = 2;
                        });
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0369A1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0369A1).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.today_rounded, size: 22, color: Color(0xFFFDE047)),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'HÔM NAY',
                                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFFDE047)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${_summary?.today.trips ?? 0} chuyến)',
                                        style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    AppFormatters.formatKgToTons(_summary?.today.weightKg ?? 0),
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  if ((_summary?.today.totalAmount ?? 0) > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      AppFormatters.formatCurrency(_summary?.today.totalAmount ?? 0),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFDE047)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Row(
                              children: [
                                Text('Thống kê', style: TextStyle(fontSize: 15, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF38BDF8), size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Month Stats Card (Full Row)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _statsInitialTab = 1;
                          _currentNavIndex = 2;
                        });
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF065F46), Color(0xFF0D9488)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, size: 22, color: Color(0xFFFDE047)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'THÁNG ${AppFormatters.formatMonthYear(now)}',
                                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFFDE047)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${_summary?.month.trips ?? 0} chuyến)',
                                        style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    AppFormatters.formatKgToTons(_summary?.month.weightKg ?? 0),
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  if ((_summary?.month.totalAmount ?? 0) > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      AppFormatters.formatCurrency(_summary?.month.totalAmount ?? 0),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFDE047)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Row(
                              children: [
                                Text('Thống kê', style: TextStyle(fontSize: 15, color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF2DD4BF), size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Primary Action Button: + CHỤP PHIẾU MỚI (Height 64px)
                    SizedBox(
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final saved = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => const AddBoatReceiptScreen()),
                          );
                          if (saved == true) _loadData();
                        },
                        icon: const Icon(Icons.add_a_photo_rounded, size: 30),
                        label: const Text(
                          'CHỤP PHIẾU MỚI',
                          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Secondary Action Button: ✍ NHẬP THỦ CÔNG
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final saved = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => const ReceiptConfirmationScreen(inputMethod: 'manual')),
                          );
                          if (saved == true) _loadData();
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 28),
                        label: const Text(
                          'NHẬP THỦ CÔNG',
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          side: BorderSide(color: isDark ? const Color(0xFF0284C7) : const Color(0xFF0284C7), width: 2.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Recent Receipts Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PHIẾU GẦN ĐÂY',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: 0.5),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _currentNavIndex = 1;
                            });
                          },
                          child: const Text('Xem tất cả', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_recentReceipts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Text(
                            'Chưa có phiếu nhập trấu nào.\nBấm "CHỤP PHIẾU MỚI" để bắt đầu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.5),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentReceipts.length,
                        separatorBuilder: (context, idx) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = _recentReceipts[index];
                          return Material(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.directions_boat_filled_rounded, color: Color(0xFF38BDF8), size: 30),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    AppFormatters.formatDate(item.receiptDate),
                                    style: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
                                  ),
                                  const Text(' · ', style: TextStyle(fontSize: 16, color: Colors.grey)),
                                  Text(
                                    item.boatNumber,
                                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  AppFormatters.formatKgToTons(item.weightKg),
                                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 20, color: Color(0xFF64748B)),
                              onTap: () async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => ReceiptDetailScreen(receiptId: item.id)),
                                );
                                if (updated == true) _loadData();
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
