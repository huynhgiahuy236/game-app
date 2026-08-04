import 'dart:io';

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
      setState(() => _isProcessing = true);
      final imageFile = File(pickedFile.path);
      final result = await _ocrService.processImage(imageFile);
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
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.error_outline_rounded,
            color: ReceiptColors.red,
            size: 40,
          ),
          title: const Text('Không thể xử lý ảnh', textAlign: TextAlign.center),
          content: Text(
            'Kiểm tra quyền Camera/Thư viện rồi thử lại.\n\n$error',
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đã hiểu', style: TextStyle(fontSize: 17)),
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ReceiptUi.canvas(context),
    appBar: ReceiptUi.appBar(
      context,
      'Thêm phiếu mới',
      subtitle: 'Chọn cách nhập phù hợp',
    ),
    body: SafeArea(
      child: _isProcessing
          ? _processing()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF102A43)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
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
                            fontSize: 16,
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
            ),
    ),
  );

  Widget _processing() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 52,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              color: ReceiptColors.blue,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Đang đọc phiếu...',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Quá trình thường mất vài giây',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
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
  }) => ReceiptSurface(
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
                        fontSize: 19,
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
                  fontSize: 15,
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
