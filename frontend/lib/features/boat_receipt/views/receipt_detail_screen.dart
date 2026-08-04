import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../services/boat_receipt_repository.dart';
import 'receipt_image_viewer_screen.dart';
import 'edit_receipt_screen.dart';

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
    _loadDetail();
  }

  Future<void> _loadDetail() async {
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

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bạn có chắc chắn muốn xóa phiếu nhập này không?',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa phiếu', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteReceipt(widget.receiptId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa phiếu thành công'), backgroundColor: Colors.orange),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể xóa phiếu: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('CHI TIẾT PHIẾU GHE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (_receipt != null) ...[
            IconButton(
              icon: const Icon(Icons.edit, size: 28),
              tooltip: 'Chỉnh sửa',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => EditReceiptScreen(receipt: _receipt!)),
                );
                if (updated == true) {
                  _loadDetail();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, size: 28),
              tooltip: 'Xóa phiếu',
              onPressed: _handleDelete,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_errorMessage!, style: const TextStyle(fontSize: 20, color: Colors.red)),
                  ),
                )
              : _receipt == null
                  ? const Center(child: Text('Không tìm thấy phiếu', style: TextStyle(fontSize: 20)))
                  : SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Image display
                            if (_receipt!.image != null && _receipt!.image!.secureUrl.isNotEmpty) ...[
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReceiptImageViewerScreen(
                                        imageUrl: _receipt!.image!.secureUrl,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  height: 240,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.blue.shade300, width: 2),
                                    color: Colors.black,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                          _receipt!.image!.secureUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.zoom_in, color: Colors.white, size: 24),
                                            SizedBox(width: 6),
                                            Text('Nhấn để phóng to ảnh', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Card Info Details
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    _buildDetailRow('Ngày nhập phiếu', AppFormatters.formatDate(_receipt!.receiptDate), Icons.calendar_today, Colors.blue.shade900),
                                    const Divider(height: 24),
                                    _buildDetailRow('Số ghe', _receipt!.boatNumber, Icons.directions_boat, Colors.blue.shade900),
                                    const Divider(height: 24),
                                    _buildDetailRow('Khối lượng', AppFormatters.formatKg(_receipt!.weightKg), Icons.scale, Colors.green.shade800),
                                    const Divider(height: 24),
                                    _buildDetailRow('Quy đổi', AppFormatters.formatKgToTons(_receipt!.weightKg), Icons.swap_horiz, Colors.orange.shade900),
                                    if (_receipt!.note.isNotEmpty) ...[
                                      const Divider(height: 24),
                                      _buildDetailRow('Ghi chú', _receipt!.note, Icons.note, Colors.grey.shade800),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Metadata Card
                            Card(
                              elevation: 1,
                              color: Colors.grey.shade100,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Phương thức nhập: ${_receipt!.inputMethod == 'camera' ? 'Chụp ảnh' : _receipt!.inputMethod == 'gallery' ? 'Thư viện' : 'Nhập thủ công'}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text('Thời gian tạo: ${AppFormatters.formatDateTime(_receipt!.createdAt)}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                                    if (_receipt!.wasEdited) ...[
                                      const SizedBox(height: 4),
                                      const Text('Trạng thái: Đã qua chỉnh sửa', style: TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Edit & Delete Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 56,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final updated = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(builder: (_) => EditReceiptScreen(receipt: _receipt!)),
                                        );
                                        if (updated == true) _loadDetail();
                                      },
                                      icon: const Icon(Icons.edit, size: 24),
                                      label: const Text('Chỉnh sửa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue.shade900,
                                        side: BorderSide(color: Colors.blue.shade900, width: 2),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: SizedBox(
                                    height: 56,
                                    child: ElevatedButton.icon(
                                      onPressed: _handleDelete,
                                      icon: const Icon(Icons.delete, size: 24),
                                      label: const Text('Xóa phiếu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade800,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 30, color: color),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 16, color: Color(0xFF666666))),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ],
    );
  }
}
