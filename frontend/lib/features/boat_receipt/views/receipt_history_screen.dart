import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../services/boat_receipt_repository.dart';
import 'receipt_detail_screen.dart';

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

  String _filterType = 'all';

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
        title: Text('LỊCH SỬ PHIẾU GHE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter & Search Header Card
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Input Field
                TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo số ghe (ví dụ: AG 0204)...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey : const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 28, color: Color(0xFF0284C7)),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear_rounded, color: isDark ? Colors.grey : const Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        _fetchHistory();
                      },
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  onSubmitted: (_) => _fetchHistory(),
                ),
                const SizedBox(height: 14),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả', 'all', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Hôm nay', 'today', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tuần này', 'week', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tháng này', 'month', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Receipts List Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_errorMessage!, style: const TextStyle(fontSize: 18, color: Color(0xFFF43F5E))),
                        ),
                      )
                    : _receipts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 64, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                const SizedBox(height: 16),
                                Text(
                                  'Chưa tìm thấy phiếu nhập nào',
                                  style: TextStyle(fontSize: 22, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchHistory,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _receipts.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final receipt = _receipts[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
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
                                      borderRadius: BorderRadius.circular(18),
                                      child: Padding(
                                        padding: const EdgeInsets.all(18),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: const Icon(Icons.directions_boat_filled_rounded, size: 34, color: Color(0xFF38BDF8)),
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
                                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                                      ),
                                                      Text(
                                                        AppFormatters.formatDate(receipt.receiptDate),
                                                        style: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        AppFormatters.formatKgToTons(receipt.weightKg),
                                                        style: const TextStyle(
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF38BDF8),
                                                        ),
                                                      ),
                                                      if (receipt.computedTotalAmount > 0)
                                                        Text(
                                                          AppFormatters.formatCurrency(receipt.computedTotalAmount),
                                                          style: const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFFFDE047),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  if (receipt.note.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Ghi chú: ${receipt.note}',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 20),
                                          ],
                                        ),
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

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _filterType == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 17,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
