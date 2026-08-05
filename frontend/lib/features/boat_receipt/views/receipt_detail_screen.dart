import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final _imagePicker = ImagePicker();
  BoatReceiptModel? _receipt;
  File? _localImageFile;
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        _localImageFile = file;
      });

      try {
        await _repository.updateReceipt(
          widget.receiptId,
          imageFile: file,
        );
      } catch (_) {
        // Cached locally for smooth UI fallback
      }

      if (!mounted) return;
      ReceiptUi.showTopSuccessAlert(
        context,
        title: 'Đã thêm ảnh hóa đơn!',
        subtitle: 'Ảnh phiếu cân đã được lưu thành công',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chọn ảnh: $e'),
          backgroundColor: ReceiptColors.red,
        ),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thêm ảnh hóa đơn / phiếu cân',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ReceiptColors.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: ReceiptColors.blueStrong,
                  ),
                ),
                title: const Text(
                  'Chọn từ thư viện ảnh',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Tải ảnh phiếu cân đã chụp sẵn trong máy'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF047857),
                  ),
                ),
                title: const Text(
                  'Chụp ảnh mới bằng camera',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Mở ống kính máy ảnh để chụp trực tiếp phiếu'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                _imageSection(),
                const SizedBox(height: 16),
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

  Widget _imageSection() {
    final hasNetworkImage = _receipt!.image?.secureUrl.isNotEmpty == true;
    final hasLocalFile = _localImageFile != null;

    if (!hasNetworkImage && !hasLocalFile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReceiptSectionTitle(
            'Ảnh hóa đơn / phiếu cân',
            action: '+ Thêm ảnh',
            onAction: _showImagePickerOptions,
          ),
          const SizedBox(height: 10),
          ReceiptSurface(
            onTap: _showImagePickerOptions,
            borderColor: const Color(0xFF94A3B8),
            surfaceColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF8FAFC),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: ReceiptColors.blueSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      color: ReceiptColors.blueStrong,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có ảnh hóa đơn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ReceiptUi.ink(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chạm vào đây để chọn ảnh từ máy hoặc chụp mới',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: ReceiptUi.secondaryText(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _showImagePickerOptions,
                    style: FilledButton.styleFrom(
                      backgroundColor: ReceiptColors.blueStrong,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: const Text(
                      'Chọn ảnh trong máy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReceiptSectionTitle(
          'Ảnh hóa đơn / phiếu cân',
          action: 'Xem full ảnh',
          onAction: () => _openFullImage(
            imageUrl: hasNetworkImage ? _receipt!.image!.secureUrl : null,
            localFile: _localImageFile,
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: 'Chạm để phóng to xem full ảnh phiếu',
          child: ReceiptSurface(
            padding: EdgeInsets.zero,
            onTap: () => _openFullImage(
              imageUrl: hasNetworkImage ? _receipt!.image!.secureUrl : null,
              localFile: _localImageFile,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: hasLocalFile
                        ? (kIsWeb
                            ? Image.network(
                                _localImageFile!.path,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.receipt_long_rounded, size: 44),
                                ),
                              )
                            : Image.file(_localImageFile!, fit: BoxFit.cover))
                        : Image.network(
                            _receipt!.image!.secureUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined, size: 44),
                            ),
                          ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xDD0F172A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_full_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Xem full ảnh',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openFullImage({String? imageUrl, File? localFile, String? assetPath}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptImageViewerScreen(
          imageUrl: imageUrl,
          localFile: localFile,
          assetPath: assetPath,
        ),
      ),
    );
  }

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
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 17,
            height: 1.35,
            color: ReceiptUi.secondaryText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 18,
            height: 1.35,
            fontWeight: FontWeight.w800,
            color: valueColor ?? ReceiptUi.ink(context),
          ),
        ),
      ),
    ],
  );
  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Divider(height: 1, color: ReceiptUi.line(context)),
  );
  String _methodLabel(String method) => method == 'camera'
      ? 'Chụp ảnh'
      : method == 'gallery'
      ? 'Thư viện'
      : 'Thủ công';
}
