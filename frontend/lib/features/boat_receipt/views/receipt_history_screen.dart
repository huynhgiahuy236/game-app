import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../services/boat_receipt_repository.dart';
import 'receipt_detail_screen.dart';
import 'edit_receipt_screen.dart';

class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});

  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  final BoatReceiptRepository _repository = BoatReceiptRepository();
  final TextEditingController _searchController = TextEditingController();

  List<BoatReceiptModel> _receipts = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _filterType = 'all'; // 'all', 'today', 'week', 'month'

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? date;
      String? month;
      String? from;
      String? to;

      final now = DateTime.now();

      if (_filterType == 'today') {
        date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      } else if (_filterType == 'month') {
        month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      } else if (_filterType == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        from = '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';
        to = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      }

      final boatNumber = _searchController.text.trim();

      final list = await _repository.getReceipts(
        date: date,
        month: month,
        from: from,
        to: to,
        boatNumber: boatNumber.isNotEmpty ? boatNumber : null,
        limit: 100,
      );

      setState(() {
        _receipts = list;
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
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('LỊCH SỬ PHIẾU GHE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Filter & Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo số ghe (ví dụ: AG 0204)...',
                    prefixIcon: const Icon(Icons.search, size: 28),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _fetchHistory();
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _fetchHistory(),
                ),
                const SizedBox(height: 12),

                // Filter Buttons Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Hôm nay', 'today'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tuần này', 'week'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tháng này', 'month'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_errorMessage!, style: const TextStyle(fontSize: 18, color: Colors.red)),
                        ),
                      )
                    : _receipts.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'Chưa có phiếu nhập nào',
                                  style: TextStyle(fontSize: 22, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchHistory,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _receipts.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final receipt = _receipts[index];
                                return Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: InkWell(
                                    onTap: () async {
                                      final updated = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ReceiptDetailScreen(receiptId: receipt.id),
                                        ),
                                      );
                                      if (updated == true) _fetchHistory();
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Icon(Icons.directions_boat, size: 36, color: Colors.blue.shade900),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      receipt.boatNumber,
                                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                                                    ),
                                                    Text(
                                                      AppFormatters.formatDate(receipt.receiptDate),
                                                      style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  AppFormatters.formatKgToTons(receipt.weightKg),
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade900,
                                                  ),
                                                ),
                                                if (receipt.note.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Ghi chú: ${receipt.note}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.blue.shade800,
      backgroundColor: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filterType = value;
          });
          _fetchHistory();
        }
      },
    );
  }
}
