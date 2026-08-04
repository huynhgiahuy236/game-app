import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../services/boat_receipt_repository.dart';
import 'edit_receipt_screen.dart';
import 'receipt_image_viewer_screen.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final String receiptId;

  const ReceiptDetailScreen({super.key, required this.receiptId});

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  final BoatReceiptRepository _repository = BoatReceiptRepository();

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
      final receipt = await _repository.getReceiptById(widget.receiptId);
      setState(() {
        _receipt = receipt;
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

  Future<void> _deleteReceipt() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Xóa phiếu này?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        content: const Text(
          'Bạn có chắc chắn muốn xóa phiếu nhập lúa này không? Thao tác này không thể hoàn tác.',
          style: TextStyle(fontSize: 18, color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(fontSize: 18, color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Xóa', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteReceipt(widget.receiptId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa phiếu thành công', style: TextStyle(fontSize: 18)),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xóa phiếu: $e', style: const TextStyle(fontSize: 18))),
          );
        }
      }
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
        title: Text('CHI TIẾT PHIẾU GHE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (_receipt != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 28, color: Color(0xFF38BDF8)),
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditReceiptScreen(receipt: _receipt!),
                  ),
                );
                if (updated == true) _loadReceipt();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, size: 28, color: Color(0xFFF43F5E)),
              onPressed: _deleteReceipt,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(fontSize: 18, color: Color(0xFFF43F5E))))
              : _receipt == null
                  ? const Center(child: Text('Không tìm thấy phiếu', style: TextStyle(fontSize: 18, color: Colors.white)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Photo Banner Preview Card
                          if (_receipt!.image != null && _receipt!.image!.secureUrl.isNotEmpty) ...[
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReceiptImageViewerScreen(imageUrl: _receipt!.image!.secureUrl),
                                  ),
                                );
                              },
                              child: Container(
                                height: 260,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: const Color(0xFF0284C7), width: 2),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: kIsWeb
                                          ? Image.network(_receipt!.image!.secureUrl, fit: BoxFit.cover, width: double.infinity)
                                          : Image.network(_receipt!.image!.secureUrl, fit: BoxFit.cover, width: double.infinity),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.zoom_in_rounded, color: Colors.white, size: 26),
                                          SizedBox(width: 8),
                                          Text('Xem toàn màn hình', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Summary Hero Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E293B), Color(0xFF0369A1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('SỐ GHE', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF059669),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text('ĐÃ XÁC NHẬN', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(_receipt!.boatNumber, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('KHỐI LƯỢNG', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(
                                          AppFormatters.formatKgToTons(_receipt!.weightKg),
                                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    if (_receipt!.pricePerKg > 0)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('GIÁ LÚA', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(
                                            AppFormatters.formatPricePerKg(_receipt!.pricePerKg),
                                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFDE047)),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                if (_receipt!.computedTotalAmount > 0) ...[
                                  const Divider(color: Color(0xFF38BDF8), height: 24, thickness: 1),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('THÀNH TIỀN:', style: TextStyle(fontSize: 16, color: Color(0xFFFDE047), fontWeight: FontWeight.bold)),
                                      Text(
                                        AppFormatters.formatFullCurrency(_receipt!.computedTotalAmount),
                                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFFFDE047)),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Details Metadata List
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow('Ngày nhập phiếu', AppFormatters.formatDate(_receipt!.receiptDate)),
                                const Divider(color: Color(0xFF334155), height: 24),
                                _buildDetailRow('Đơn giá lúa', _receipt!.pricePerKg > 0 ? AppFormatters.formatPricePerKg(_receipt!.pricePerKg) : 'Chưa nhập'),
                                const Divider(color: Color(0xFF334155), height: 24),
                                _buildDetailRow('Tổng thành tiền', _receipt!.computedTotalAmount > 0 ? AppFormatters.formatFullCurrency(_receipt!.computedTotalAmount) : '0 đ'),
                                const Divider(color: Color(0xFF334155), height: 24),
                                _buildDetailRow('Phương thức nhập', _receipt!.inputMethod == 'camera' ? 'Chụp ảnh' : _receipt!.inputMethod == 'gallery' ? 'Thư viện' : 'Thủ công'),
                                const Divider(color: Color(0xFF334155), height: 24),
                                _buildDetailRow('Ghi chú', _receipt!.note.isNotEmpty ? _receipt!.note : '(Không có)'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 18, color: Color(0xFF94A3B8))),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
