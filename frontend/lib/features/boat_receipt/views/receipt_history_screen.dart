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
        _compactFilters(),
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

  Widget _compactFilters() => Container(
    color: ReceiptUi.surface(context),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        onPressed: _showFilters,
        icon: const Icon(Icons.tune_rounded, size: 28),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lọc phiếu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Text(
                _filterSummary(),
                style: TextStyle(
                  fontSize: 14,
                  color: ReceiptUi.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: ReceiptColors.ink,
          side: BorderSide(color: ReceiptUi.line(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
  );

  String _filterSummary() {
    final boat = _selectedBoat ?? 'Tất cả ghe';
    final time = switch (_filterType) {
      'today' => 'Hôm nay',
      'week' => 'Tuần này',
      'month' => 'Tháng này',
      'date' when _selectedDate != null => AppFormatters.formatDate(
        _selectedDate!,
      ),
      _ => 'Tất cả ngày',
    };
    return '$boat · $time';
  }

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
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
            const Text(
              'Lọc danh sách phiếu',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chọn ghe',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _sheetChoice(
                    sheetContext,
                    'Tất cả',
                    _selectedBoat == null,
                    () => setState(() => _selectedBoat = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _sheetChoice(
                    sheetContext,
                    'DT-2764',
                    _selectedBoat == 'DT-2764',
                    () => setState(() => _selectedBoat = 'DT-2764'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _sheetChoice(
                    sheetContext,
                    'AG-26911',
                    _selectedBoat == 'AG-26911',
                    () => setState(() => _selectedBoat = 'AG-26911'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Thời gian',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _sheetTime(sheetContext, 'Tất cả', 'all'),
                _sheetTime(sheetContext, 'Hôm nay', 'today'),
                _sheetTime(sheetContext, 'Tuần này', 'week'),
                _sheetTime(sheetContext, 'Tháng này', 'month'),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _pickDate();
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _selectedDate == null
                    ? 'Chọn ngày cụ thể'
                    : AppFormatters.formatDate(_selectedDate!),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: ReceiptColors.blueStrong,
              ),
              child: const Text(
                'Xem kết quả',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == true) _fetchHistory();
  }

  Widget _sheetChoice(
    BuildContext sheetContext,
    String label,
    bool selected,
    VoidCallback select,
  ) => OutlinedButton(
    onPressed: () {
      select();
      Navigator.pop(sheetContext, true);
    },
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: selected ? ReceiptColors.blueSoft : null,
    ),
    child: Text(label, maxLines: 1),
  );

  Widget _sheetTime(BuildContext sheetContext, String label, String value) =>
      ChoiceChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        selected: _filterType == value,
        onSelected: (_) {
          setState(() {
            _filterType = value;
            _selectedDate = null;
          });
          Navigator.pop(sheetContext, true);
        },
      );

  // Kept as a private layout reference while the compact filter is in use.
  // ignore: unused_element
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
