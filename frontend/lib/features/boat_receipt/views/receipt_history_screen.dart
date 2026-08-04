import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../services/boat_receipt_repository.dart';
import 'receipt_detail_screen.dart';
import 'receipt_ui.dart';

class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});

  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  final _repository = BoatReceiptRepository();
  final _searchController = TextEditingController();
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
      final now = DateTime.now();
      String? date;
      String? month;
      String? from;
      String? to;
      if (_filterType == 'today') {
        date = _iso(now);
      } else if (_filterType == 'month') {
        month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      } else if (_filterType == 'week') {
        from = _iso(now.subtract(Duration(days: now.weekday - 1)));
        to = _iso(now);
      }
      final query = _searchController.text.trim();
      final data = await _repository.getReceipts(
        date: date,
        month: month,
        from: from,
        to: to,
        boatNumber: query.isEmpty ? null : query,
        limit: 100,
      );
      if (mounted) setState(() => _receipts = data);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _iso(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ReceiptUi.canvas(context),
    appBar: ReceiptUi.appBar(
      context,
      'Danh sách phiếu',
      subtitle: '${_receipts.length} phiếu được tìm thấy',
    ),
    body: Column(
      children: [
        _filters(),
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
                    onRetry: _fetchHistory,
                  ),
                )
              : _receipts.isEmpty
              ? const ReceiptEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Không tìm thấy phiếu',
                  message: 'Thử đổi khoảng thời gian hoặc số ghe cần tìm.',
                )
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    itemCount: _receipts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _receiptCard(_receipts[index]),
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _filters() => Container(
    color: ReceiptUi.surface(context),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    child: Column(
      children: [
        TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration:
              ReceiptUi.input(
                context,
                hint: 'Tìm DT-2764 hoặc AG-26911',
                icon: Icons.search_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: () {
                    _searchController.clear();
                    _fetchHistory();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
          onSubmitted: (_) => _fetchHistory(),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip('Tất cả', 'all'),
              _chip('Hôm nay', 'today'),
              _chip('Tuần này', 'week'),
              _chip('Tháng này', 'month'),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chip(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      selected: _filterType == value,
      selectedColor: ReceiptColors.blueSoft,
      side: BorderSide(
        color: _filterType == value
            ? ReceiptColors.blue
            : ReceiptUi.line(context),
      ),
      onSelected: (_) {
        setState(() => _filterType = value);
        _fetchHistory();
      },
    ),
  );

  Widget _receiptCard(BoatReceiptModel receipt) => ReceiptSurface(
    onTap: () async {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptDetailScreen(receiptId: receipt.id),
        ),
      );
      if (changed == true) _fetchHistory();
    },
    child: Column(
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
                    receipt.boatNumber,
                    style: const TextStyle(
                      fontSize: 20,
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
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        const SizedBox(height: 12),
        Divider(color: ReceiptUi.line(context), height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _value(
                'Khối lượng',
                AppFormatters.formatKgToTons(receipt.weightKg),
                ReceiptColors.blueStrong,
              ),
            ),
            if (receipt.computedTotalAmount > 0)
              Expanded(
                child: _value(
                  'Thành tiền',
                  AppFormatters.formatCurrency(receipt.computedTotalAmount),
                  ReceiptColors.green,
                  alignEnd: true,
                ),
              ),
          ],
        ),
        if (receipt.note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              receipt.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: ReceiptUi.secondaryText(context),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _value(
    String label,
    String value,
    Color color, {
    bool alignEnd = false,
  }) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 14, color: ReceiptUi.secondaryText(context)),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ],
  );
}
