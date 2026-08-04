import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../models/statistics_model.dart';
import '../services/boat_receipt_repository.dart';
import 'add_boat_receipt_screen.dart';
import 'receipt_confirmation_screen.dart';
import 'receipt_history_screen.dart';
import 'receipt_detail_screen.dart';
import 'receipt_statistics_screen.dart';

class BoatReceiptHomeScreen extends StatefulWidget {
  const BoatReceiptHomeScreen({super.key});

  @override
  State<BoatReceiptHomeScreen> createState() => _BoatReceiptHomeScreenState();
}

class _BoatReceiptHomeScreenState extends State<BoatReceiptHomeScreen> {
  final BoatReceiptRepository _repository = BoatReceiptRepository();

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
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('SỔ GHE NHẬP LÚA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, size: 30),
            tooltip: 'Thống kê',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptStatisticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, size: 30),
            tooltip: 'Lịch sử',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(_errorMessage!, style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.red),
                              onPressed: _loadData,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Summary Stats Cards
                    Row(
                      children: [
                        // Today Stats Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade900,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade900.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'HÔM NAY',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_summary?.today.trips ?? 0} chuyến',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppFormatters.formatKgToTons(_summary?.today.weightKg ?? 0),
                                  style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Month Stats Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade800,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.shade800.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'THÁNG ${AppFormatters.formatMonthYear(now)}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_summary?.month.trips ?? 0} chuyến',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppFormatters.formatKgToTons(_summary?.month.weightKg ?? 0),
                                  style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Primary Action Button: + CHỤP PHIẾU (Height 60px min, large text)
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
                        icon: const Icon(Icons.add_a_photo, size: 32),
                        label: const Text(
                          '＋ CHỤP PHIẾU MỚI',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

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
                        icon: const Icon(Icons.edit_document, size: 28),
                        label: const Text(
                          '✍ NHẬP THỦ CÔNG',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade900,
                          side: BorderSide(color: Colors.blue.shade900, width: 2.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Navigation buttons row (Lịch sử & Thống kê)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()),
                              );
                              _loadData();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history, color: Colors.blue.shade900, size: 28),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Lịch sử',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ReceiptStatisticsScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bar_chart, color: Colors.teal.shade800, size: 28),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Thống kê',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Section: Recent Receipts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PHIẾU GẦN ĐÂY',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()),
                            );
                            _loadData();
                          },
                          child: const Text('Xem tất cả', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_recentReceipts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Chưa có phiếu nhập lúa nào.\nBấm "CHỤP PHIẾU MỚI" để bắt đầu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentReceipts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _recentReceipts[index];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.directions_boat, color: Colors.blue.shade900, size: 28),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    AppFormatters.formatDate(item.receiptDate),
                                    style: const TextStyle(fontSize: 16, color: Color(0xFF555555)),
                                  ),
                                  const Text(' · ', style: TextStyle(fontSize: 16, color: Colors.grey)),
                                  Text(
                                    item.boatNumber,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  AppFormatters.formatKgToTons(item.weightKg),
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
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
