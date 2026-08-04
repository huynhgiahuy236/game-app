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
  List<BoatReceiptModel> _receipts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterType = 'all';
  DateTime? _selectedDate;
  String? _selectedBoat;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
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
      if (_filterType == 'date' && _selectedDate != null) {
        date = _iso(_selectedDate!);
      } else if (_filterType == 'today') {
        date = _iso(now);
      } else if (_filterType == 'month') {
        month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      } else if (_filterType == 'week') {
        from = _iso(now.subtract(Duration(days: now.weekday - 1)));
        to = _iso(now);
      }
      final data = await _repository.getAllReceipts(
        date: date,
        month: month,
        from: from,
        to: to,
        boatNumber: _selectedBoat,
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
        Row(
          children: [
            Expanded(
              child: _boatOption(
                'Tất cả ghe',
                null,
                ReceiptColors.ink,
                ReceiptUi.line(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _boatOption(
                'DT-2764',
                'DT-2764',
                ReceiptColors.blueStrong,
                ReceiptColors.blueSoft,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _boatOption(
                'AG-26911',
                'AG-26911',
                ReceiptColors.green,
                ReceiptColors.greenSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _selectedDate == null
                  ? 'Chọn một ngày cụ thể'
                  : AppFormatters.formatDate(_selectedDate!),
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: _filterType == 'date'
                  ? ReceiptColors.blueStrong
                  : ReceiptColors.ink,
              backgroundColor: _filterType == 'date'
                  ? ReceiptColors.blueSoft
                  : ReceiptUi.surface(context),
              side: BorderSide(
                color: _filterType == 'date'
                    ? ReceiptColors.blue
                    : ReceiptUi.line(context),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        if (_selectedDate != null && _filterType == 'date') ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                  _filterType = 'all';
                });
                _fetchHistory();
              },
              icon: const Icon(Icons.close_rounded, size: 19),
              label: const Text('Bỏ ngày đã chọn'),
            ),
          ),
        ] else
          const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
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

  Widget _chip(String label, String value) => ChoiceChip(
    label: Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _filterType == value
            ? ReceiptColors.blueStrong
            : ReceiptUi.secondaryText(context),
      ),
    ),
    selected: _filterType == value,
    selectedColor: ReceiptColors.blueSoft,
    backgroundColor: ReceiptUi.surface(context),
    showCheckmark: false,
    side: BorderSide(
      color: _filterType == value
          ? ReceiptColors.blue
          : ReceiptUi.line(context),
    ),
    onSelected: (_) {
      setState(() {
        _filterType = value;
        _selectedDate = null;
      });
      _fetchHistory();
    },
  );

  Widget _boatOption(
    String label,
    String? value,
    Color accent,
    Color background,
  ) {
    final selected = _selectedBoat == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedBoat = value);
        _fetchHistory();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? background : ReceiptUi.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : ReceiptUi.line(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: selected ? accent : ReceiptColors.ink,
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'CHỌN NGÀY CÂN VÀO',
      cancelText: 'Hủy',
      confirmText: 'Chọn ngày',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _filterType = 'date';
    });
    _fetchHistory();
  }

  Widget _receiptCard(BoatReceiptModel receipt) {
    final isAg = receipt.boatNumber.toUpperCase().startsWith('AG');
    final accent = isAg ? ReceiptColors.green : ReceiptColors.blue;
    final soft = isAg ? const Color(0xFFDCFCE7) : ReceiptColors.blueSoft;
    return ReceiptSurface(
      borderColor: accent.withValues(alpha: 0.55),
      surfaceColor: soft,
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
  }

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
