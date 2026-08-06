import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_service.dart';
import 'receipt_confirmation_screen.dart';
import 'receipt_ui.dart';

class AddBoatReceiptScreen extends StatefulWidget {
  const AddBoatReceiptScreen({super.key});

  @override
  State<AddBoatReceiptScreen> createState() => _AddBoatReceiptScreenState();
}

class _AddBoatReceiptScreenState extends State<AddBoatReceiptScreen> {
  final _picker = ImagePicker();
  final _ocrService = OcrService();
  bool _isProcessing = false;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (pickedFile == null) return;

      if (!mounted) return;
      setState(() => _isProcessing = true);

      final imageFile = File(pickedFile.path);
      OcrResult? result;

      if (!kIsWeb) {
        try {
          result = await _ocrService.processImage(imageFile);
        } catch (_) {
          result = const OcrResult(rawText: '');
        }
      } else {
        result = const OcrResult(rawText: '');
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptConfirmationScreen(
            imageFile: imageFile,
            ocrResult: result,
            inputMethod: source == ImageSource.camera ? 'camera' : 'gallery',
          ),
        ),
      );

      if (saved == true && mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);

      String userMessage = 'Không thể chọn hoặc xử lý ảnh. Vui lòng thử lại.';
      final errStr = error.toString().toLowerCase();
      if (errStr.contains('camera_access_denied') ||
          errStr.contains('permission_denied') ||
          errStr.contains('permission')) {
        userMessage =
            'Ứng dụng chưa được cấp quyền truy cập Camera hoặc Thư viện ảnh. Vui lòng vào Cài đặt của thiết bị để cấp quyền.';
      } else if (errStr.contains('no_available_camera') ||
          errStr.contains('camera_unavailable')) {
        userMessage = 'Không tìm thấy thiết bị máy ảnh trên thiết bị này.';
      }

      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.error_outline_rounded,
            color: ReceiptColors.red,
            size: 44,
          ),
          title: const Text(
            'Lỗi xử lý ảnh',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            userMessage,
            style: const TextStyle(fontSize: 15, height: 1.45),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(
                backgroundColor: ReceiptColors.blueStrong,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Đã hiểu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _manualEntry() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ReceiptConfirmationScreen(inputMethod: 'manual'),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_isProcessing,
        child: Scaffold(
          backgroundColor: ReceiptUi.canvas(context),
          appBar: ReceiptUi.appBar(
            context,
            'Thêm phiếu mới',
            subtitle: _isProcessing
                ? 'Đang tự động đọc thông tin'
                : 'Chọn cách nhập phù hợp',
            onBackPress: _isProcessing ? () {} : null,
          ),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isProcessing ? _processing() : _buildContent(),
            ),
          ),
        ),
      );

  Widget _buildContent() => ListView(
        key: const ValueKey('options_list'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF102A43)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFFBAE6FD),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: ReceiptColors.blue,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đặt phiếu thẳng, chụp đủ bốn góc và tránh ánh sáng phản chiếu.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _option(
            title: 'Chụp bằng camera',
            subtitle: 'Chụp phiếu mới và tự nhận diện thông tin',
            icon: Icons.camera_alt_outlined,
            color: ReceiptColors.blueStrong,
            onTap: () => _pickImage(ImageSource.camera),
            primary: true,
          ),
          const SizedBox(height: 12),
          _option(
            title: 'Chọn ảnh có sẵn',
            subtitle: 'Dùng ảnh phiếu trong thư viện điện thoại',
            icon: Icons.photo_library_outlined,
            color: ReceiptColors.green,
            onTap: () => _pickImage(ImageSource.gallery),
          ),
          const SizedBox(height: 12),
          _option(
            title: 'Nhập thủ công',
            subtitle: 'Tự nhập ngày, số ghe và khối lượng',
            icon: Icons.edit_note_outlined,
            color: ReceiptColors.amber,
            onTap: _manualEntry,
          ),
        ],
      );

  Widget _processing() => Center(
        key: const ValueKey('processing_view'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ReceiptUi.surface(context),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const SizedBox.square(
                  dimension: 52,
                  child: CircularProgressIndicator(
                    strokeWidth: 4.5,
                    color: ReceiptColors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Đang đọc phiếu...',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Quá trình phân tích OCR thường mất vài giây',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: ReceiptUi.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _option({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool primary = false,
  }) =>
      ReceiptSurface(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (primary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ReceiptColors.blueSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Nên dùng',
                            style: TextStyle(
                              fontSize: 12,
                              color: ReceiptColors.blueStrong,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: ReceiptUi.secondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
}

