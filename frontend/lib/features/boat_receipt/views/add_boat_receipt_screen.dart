import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import 'receipt_confirmation_screen.dart';

class AddBoatReceiptScreen extends StatefulWidget {
  const AddBoatReceiptScreen({super.key});

  @override
  State<AddBoatReceiptScreen> createState() => _AddBoatReceiptScreenState();
}

class _AddBoatReceiptScreenState extends State<AddBoatReceiptScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  bool _isProcessing = false;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isProcessing = true;
      });

      final File imageFile = File(pickedFile.path);
      final OcrResult ocrResult = await _ocrService.processImage(imageFile);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptConfirmationScreen(
            imageFile: imageFile,
            ocrResult: ocrResult,
            inputMethod: source == ImageSource.camera ? 'camera' : 'gallery',
          ),
        ),
      );

      if (saved == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể xử lý ảnh: $e', style: const TextStyle(fontSize: 18)),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _manualEntry() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ReceiptConfirmationScreen(
          inputMethod: 'manual',
        ),
      ),
    );

    if (saved == true && mounted) {
      Navigator.pop(context, true);
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
        title: Text(
          'NHẬP PHIẾU GHE MỚI',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 4),
                  const SizedBox(height: 24),
                  const Text(
                    'Đang đọc chữ trên phiếu...',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vui lòng chờ trong giây lát',
                    style: TextStyle(fontSize: 18, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'VUI LÒNG CHỌN PHƯƠNG THỨC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Camera option card
                    _buildOptionCard(
                      title: 'Chụp ảnh trực tiếp',
                      subtitle: 'Dùng máy ảnh chụp phiếu & tự nhận diện chữ',
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xFF0284C7),
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(height: 20),

                    // Gallery option card
                    _buildOptionCard(
                      title: 'Chọn từ thư viện',
                      subtitle: 'Lấy ảnh phiếu có sẵn trong điện thoại',
                      icon: Icons.photo_library_rounded,
                      color: const Color(0xFF0D9488),
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                    const SizedBox(height: 20),

                    // Manual entry option card
                    _buildOptionCard(
                      title: 'Nhập thủ công',
                      subtitle: 'Tự gõ số ghe và số kg trực tiếp',
                      icon: Icons.edit_note_rounded,
                      color: const Color(0xFFD97706),
                      onTap: _manualEntry,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
