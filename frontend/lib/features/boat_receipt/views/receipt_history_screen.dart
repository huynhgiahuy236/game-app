import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../services/boat_receipt_repository.dart';
import '../services/receipt_cache.dart';
import 'receipt_detail_screen.dart';
import 'receipt_ui.dart';

class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});

  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  final _repository = BoatReceiptRepository();
  final _cache = ReceiptCache();
  List<BoatReceiptModel> _receipts = [];
  List<BoatReceiptModel> _cachedReceipts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterType = 'all';
  DateTime? _selectedDate;
  String? _selectedBoat;
  bool _usingCachedData = false;
  DateTime? _cacheSavedAt;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await _cache.loadReceipts();
    if (cached != null && mounted) {
      setState(() {
        _receipts = cached.$1;
        _cachedReceipts = cached.$1;
        _cacheSavedAt = cached.$2;
        _usingCachedData = true;
        _isLoading = false;
      });
    }
    await _fetchHistory(showSpinner: cached == null);
  }

  Future<void> _fetchHistory({bool showSpinner = true}) async {
    setState(() {
      _isLoading = showSpinner;
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
      if (mounted) {
        setState(() {
          _receipts = data;
          _usingCachedData = false;
        });
      }
      if (_filterType == 'all' && _selectedBoat == null) {
        _cachedReceipts = data;
        await _cache.saveReceipts(data);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (_receipts.isEmpty) {
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
        if (_usingCachedData) _cachedDataNotice(),
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

  Widget _cachedDataNotice() => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF2D38A)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 22,
          color: Color(0xFF9A6500),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            _cacheSavedAt == null
                ? 'Đang xem dữ liệu gần nhất'
                : 'Dữ liệu lúc ${_two(_cacheSavedAt!.hour)}:${_two(_cacheSavedAt!.minute)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF704B00),
            ),
          ),
        ),
        TextButton(
          onPressed: () => _fetchHistory(),
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );

  String _two(int value) => value.toString().padLeft(2, '0');

  Widget _compactFilters() => Container(
    color: ReceiptUi.surface(context),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: _quickBoat('Tất cả', null, ReceiptColors.blue)),
            const SizedBox(width: 8),
            Expanded(
              child: _quickBoat('DT-2764', 'DT-2764', ReceiptColors.blueStrong),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickBoat('AG-26911', 'AG-26911', ReceiptColors.green),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: OutlinedButton.icon(
            onPressed: _showFilterBottomSheet,
            icon: const Icon(Icons.tune_rounded, size: 26),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lọc thêm theo thời gian',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    _filterSummary(),
                    style: TextStyle(
                      fontSize: 13,
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
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _quickBoat(String label, String? boat, Color color) {
    final selected = _selectedBoat == boat;
    return Semantics(
      button: true,
      selected: selected,
      label: boat == null ? 'Xem tất cả ghe' : 'Lọc nhanh ghe $boat',
      child: InkWell(
        onTap: () {
          if (_selectedBoat == boat) return;
          setState(() {
            _selectedBoat = boat;
            if (_cachedReceipts.isNotEmpty) {
              _receipts = boat == null
                  ? _cachedReceipts
                  : _cachedReceipts
                        .where((item) => item.boatNumber == boat)
                        .toList();
              _usingCachedData = true;
            }
          });
          _fetchHistory(showSpinner: _cachedReceipts.isEmpty);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.65)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

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

  Future<void> _showFilterBottomSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ReceiptUi.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ReceiptColors.line,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Lọc danh sách phiếu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: ReceiptColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Theo ghe',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ReceiptUi.secondaryText(context),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _sheetBoatOption(
                      'Tất cả',
                      _selectedBoat == null,
                      ReceiptColors.blueStrong,
                      ReceiptColors.blueSoft,
                      () => setSheetState(() => _selectedBoat = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _sheetBoatOption(
                      'DT-2764',
                      _selectedBoat == 'DT-2764',
                      ReceiptColors.blueStrong,
                      ReceiptColors.blueSoft,
                      () => setSheetState(() => _selectedBoat = 'DT-2764'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _sheetBoatOption(
                      'AG-26911',
                      _selectedBoat == 'AG-26911',
                      ReceiptColors.green,
                      ReceiptColors.greenSoft,
                      () => setSheetState(() => _selectedBoat = 'AG-26911'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Theo thời gian',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ReceiptUi.secondaryText(context),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _sheetTimeChip('Tất cả', 'all', setSheetState),
                  _sheetTimeChip('Hôm nay', 'today', setSheetState),
                  _sheetTimeChip('Tuần này', 'week', setSheetState),
                  _sheetTimeChip('Tháng này', 'month', setSheetState),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    helpText: 'CHỌN NGÀY CÂN',
                  );
                  if (picked != null) {
                    setSheetState(() {
                      _selectedDate = picked;
                      _filterType = 'date';
                    });
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: _filterType == 'date'
                        ? ReceiptColors.blueSoft
                        : ReceiptUi.surface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _filterType == 'date'
                          ? ReceiptColors.blue
                          : ReceiptColors.line,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: _filterType == 'date'
                            ? ReceiptColors.blueStrong
                            : ReceiptUi.secondaryText(context),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _selectedDate == null
                            ? 'Chọn ngày cụ thể...'
                            : AppFormatters.formatDate(_selectedDate!),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _filterType == 'date'
                              ? ReceiptColors.blueStrong
                              : ReceiptColors.ink,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedDate != null && _filterType == 'date')
                        GestureDetector(
                          onTap: () => setSheetState(() {
                            _selectedDate = null;
                            _filterType = 'all';
                          }),
                          child: const Icon(
                            Icons.cancel_rounded,
                            size: 18,
                            color: ReceiptColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  setState(() {});
                  Navigator.pop(sheetContext, true);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: ReceiptColors.blueStrong,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Xem kết quả',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true) _fetchHistory();
  }

  Widget _sheetBoatOption(
    String label,
    bool selected,
    Color activeColor,
    Color activeBg,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? activeBg : ReceiptUi.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? activeColor : ReceiptColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: selected ? activeColor : ReceiptColors.ink,
        ),
      ),
    ),
  );

  Widget _sheetTimeChip(
    String label,
    String value,
    StateSetter setSheetState,
  ) => ChoiceChip(
    label: Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: _filterType == value
            ? ReceiptColors.blueStrong
            : ReceiptColors.ink,
      ),
    ),
    selected: _filterType == value,
    selectedColor: ReceiptColors.blueSoft,
    backgroundColor: ReceiptUi.surface(context),
    showCheckmark: false,
    side: BorderSide(
      color: _filterType == value
          ? ReceiptColors.blue
          : ReceiptColors.line,
    ),
    onSelected: (_) {
      setSheetState(() {
        _filterType = value;
        _selectedDate = null;
      });
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
    Future<void> openDetails() async {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptDetailScreen(receiptId: receipt.id),
        ),
      );
      if (changed == true) _fetchHistory();
    }

    final statusLabel = receipt.wasEdited
        ? 'Đã chỉnh sửa'
        : receipt.inputMethod == 'camera'
        ? 'Chụp phiếu'
        : 'Nhập thủ công';
    final statusColor = receipt.wasEdited
        ? const Color(0xFFF59E0B)
        : ReceiptColors.blue;
    final statusBackground = receipt.wasEdited
        ? const Color(0xFFFFE9B8)
        : ReceiptColors.blueSoft;
    final isAg = receipt.boatNumber.toUpperCase().startsWith('AG');
    final boatColor = isAg ? ReceiptColors.green : ReceiptColors.blueStrong;
    return ReceiptSurface(
      borderColor: boatColor.withValues(alpha: 0.55),
      surfaceColor: ReceiptUi.surface(context),
      onTap: openDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BoatAvatarBadge(boatNumber: receipt.boatNumber, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KHỐI LƯỢNG',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ReceiptUi.secondaryText(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.formatKgToTons(receipt.weightKg),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: ReceiptColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isAg ? ReceiptColors.greenSoft : ReceiptColors.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: boatColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  receipt.boatNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: boatColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
            'Ngày cân',
            AppFormatters.formatDate(receipt.receiptDate),
            fontSize: 18,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: openDetails,
            style: OutlinedButton.styleFrom(
              foregroundColor: boatColor,
              side: BorderSide(color: boatColor),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Xem chi tiết phiếu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    Color? valueColor,
    Widget? leadingValue,
    double fontSize = 17,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: ReceiptUi.secondaryText(context),
            ),
          ),
        ),
        if (leadingValue != null) ...[
          leadingValue,
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: valueColor ?? ReceiptColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}
