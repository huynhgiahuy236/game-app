import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../services/boat_receipt_repository.dart';
import 'edit_receipt_screen.dart';
import 'receipt_image_viewer_screen.dart';
import 'receipt_ui.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final String receiptId;
  const ReceiptDetailScreen({super.key, required this.receiptId});

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  final _repository = BoatReceiptRepository();
  BoatReceiptModel? _receipt;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repository.getReceiptById(widget.receiptId);
      if (mounted) setState(() => _receipt = data);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditReceiptScreen(receipt: _receipt!)),
    );
    if (changed == true) _loadReceipt();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: ReceiptColors.red,
          size: 40,
        ),
        title: const Text(
          'Xóa phiếu này?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Phiếu sẽ bị xóa khỏi danh sách và thống kê.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại', style: TextStyle(fontSize: 17)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: ReceiptColors.red),
            child: const Text('Xóa phiếu', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteReceipt(widget.receiptId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể xóa phiếu: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ReceiptUi.canvas(context),
    appBar: ReceiptUi.appBar(
      context,
      'Chi tiết phiếu',
      subtitle: _receipt == null
          ? 'Đang tải...'
          : AppFormatters.formatDate(_receipt!.receiptDate),
      actions: _receipt == null
          ? null
          : [
              IconButton(
                onPressed: _edit,
                tooltip: 'Chỉnh sửa',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: ReceiptColors.blue,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tùy chọn',
                onSelected: (value) {
                  if (value == 'delete') _delete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: ReceiptColors.red),
                        SizedBox(width: 10),
                        Text(
                          'Xóa phiếu',
                          style: TextStyle(
                            fontSize: 17,
                            color: ReceiptColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
    ),
    body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: ReceiptColors.blue),
          )
        : _errorMessage != null
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: ReceiptErrorState(
              message: _errorMessage!,
              onRetry: _loadReceipt,
            ),
          )
        : _receipt == null
        ? const ReceiptEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Không tìm thấy phiếu',
            message: 'Phiếu có thể đã bị xóa hoặc không còn tồn tại.',
          )
        : RefreshIndicator(
            onRefresh: _loadReceipt,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (_receipt!.image?.secureUrl.isNotEmpty == true) ...[
                  _image(),
                  const SizedBox(height: 14),
                ] else ...[
                  BoatImagePlaceholder(boatNumber: _receipt!.boatNumber),
                  const SizedBox(height: 14),
                ],
                _hero(),
                const SizedBox(height: 14),
                ReceiptSurface(
                  child: Column(
                    children: [
                      _row(
                        'Ngày cân vào',
                        AppFormatters.formatDate(_receipt!.receiptDate),
                      ),
                      _divider(),
                      _row(
                        'Đơn giá',
                        _receipt!.pricePerKg > 0
                            ? AppFormatters.formatPricePerKg(
                                _receipt!.pricePerKg,
                              )
                            : 'Chưa nhập',
                      ),
                      _divider(),
                      _row(
                        'Phương thức nhập',
                        _methodLabel(_receipt!.inputMethod),
                      ),
                      _divider(),
                      _row(
                        'Trạng thái',
                        _receipt!.wasEdited ? 'Đã chỉnh sửa' : 'Phiếu gốc',
                        valueColor: _receipt!.wasEdited
                            ? const Color(0xFFF59E0B)
                            : ReceiptColors.blue,
                      ),
                      _divider(),
                      _row(
                        'Ghi chú',
                        _receipt!.note.isEmpty ? 'Không có' : _receipt!.note,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
  );

  Widget _image() => Semantics(
    button: true,
    label: 'Mở ảnh phiếu toàn màn hình',
    child: ReceiptSurface(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ReceiptImageViewerScreen(imageUrl: _receipt!.image!.secureUrl),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                _receipt!.image!.secureUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 44),
                ),
              ),
            ),
            const Positioned(
              right: 10,
              bottom: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xCC0F172A),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    children: [
                      Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Xem ảnh',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _hero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ReceiptColors.blueStrong,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SỐ GHE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE9E0FF),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _receipt!.boatNumber,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            BoatAvatarBadge(boatNumber: _receipt!.boatNumber, size: 52),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _heroValue(
                'Khối lượng',
                AppFormatters.formatKgToTons(_receipt!.weightKg),
              ),
            ),
            if (_receipt!.computedTotalAmount > 0)
              Expanded(
                child: _heroValue(
                  'Thành tiền',
                  AppFormatters.formatCurrency(_receipt!.computedTotalAmount),
                  alignEnd: true,
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _heroValue(String label, String value, {bool alignEnd = false}) =>
      Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFFBAE6FD)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      );

  Widget _row(String label, String value, {Color? valueColor}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: ReceiptUi.secondaryText(context),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: valueColor ?? ReceiptUi.ink(context),
          ),
        ),
      ),
    ],
  );
  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, color: ReceiptUi.line(context)),
  );
  String _methodLabel(String method) => method == 'camera'
      ? 'Chụp ảnh'
      : method == 'gallery'
      ? 'Thư viện'
      : 'Thủ công';
}
