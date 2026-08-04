import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../services/boat_receipt_repository.dart';
import '../services/ocr_service.dart';
import 'receipt_image_viewer_screen.dart';

class ReceiptConfirmationScreen extends StatefulWidget {
  final File? imageFile;
  final OcrResult? ocrResult;
  final String inputMethod;

  const ReceiptConfirmationScreen({
    super.key,
    this.imageFile,
    this.ocrResult,
    this.inputMethod = 'manual',
  });

  @override
  State<ReceiptConfirmationScreen> createState() => _ReceiptConfirmationScreenState();
}

class _ReceiptConfirmationScreenState extends State<ReceiptConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final BoatReceiptRepository _repository = BoatReceiptRepository();

  late TextEditingController _boatController;
  late TextEditingController _weightController;
  late TextEditingController _priceController;
  late TextEditingController _noteController;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;
  int _calculatedKg = 0;
  int _calculatedPrice = 0;
  bool _wasEdited = false;
  final List<String> _editedFields = [];

  @override
  void initState() {
    super.initState();

    String boatStr = widget.ocrResult?.extractedBoatNumber ?? '';
    String weightStr = widget.ocrResult?.extractedWeightKg ?? '';
    String? dateStr = widget.ocrResult?.extractedDate;

    if (dateStr != null && dateStr.contains('/')) {
      try {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          _selectedDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (_) {}
    }

    _boatController = TextEditingController(text: boatStr);
    _weightController = TextEditingController(text: weightStr);
    _priceController = TextEditingController(text: '7500');
    _noteController = TextEditingController();

    if (weightStr.isNotEmpty) {
      _calculatedKg = int.tryParse(weightStr) ?? 0;
    }
    _calculatedPrice = 7500;

    _weightController.addListener(_onFormValueChanged);
    _priceController.addListener(_onFormValueChanged);
  }

  void _onFormValueChanged() {
    final kg = int.tryParse(_weightController.text.trim()) ?? 0;
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    if (_calculatedKg != kg || _calculatedPrice != price) {
      setState(() {
        _calculatedKg = kg;
        _calculatedPrice = price;
      });
    }
  }

  @override
  void dispose() {
    _weightController.removeListener(_onFormValueChanged);
    _priceController.removeListener(_onFormValueChanged);
    _boatController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              onPrimary: Color(0xFF0F172A),
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        if (!_editedFields.contains('receiptDate')) _editedFields.add('receiptDate');
        _wasEdited = true;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clientId = _repository.generateClientId();
      final dateIso = _selectedDate.toIso8601String();
      final boatNum = _boatController.text.trim().toUpperCase();
      final weightKg = int.parse(_weightController.text.trim());
      final pricePerKg = int.tryParse(_priceController.text.trim()) ?? 0;
      final note = _noteController.text.trim();

      await _repository.createReceipt(
        clientId: clientId,
        receiptDate: dateIso,
        boatNumber: boatNum,
        weightKg: weightKg,
        pricePerKg: pricePerKg,
        note: note,
        imageFile: widget.imageFile,
        inputMethod: widget.inputMethod,
        ocrRawText: widget.ocrResult?.rawText,
        ocrDate: widget.ocrResult?.extractedDate,
        ocrBoat: widget.ocrResult?.extractedBoatNumber,
        ocrWeight: widget.ocrResult?.extractedWeightKg,
        wasEdited: _wasEdited,
        editedFields: _editedFields,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lưu phiếu thành công!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
        title: Text(
          'XÁC NHẬN PHIẾU',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Preview Banner
                if (widget.imageFile != null) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReceiptImageViewerScreen(localFile: widget.imageFile),
                        ),
                      );
                    },
                    child: Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF0284C7), width: 2),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: kIsWeb
                                ? const Text('Preview')
                                : Image.file(widget.imageFile!, fit: BoxFit.cover, width: double.infinity),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in_rounded, color: Colors.white, size: 24),
                                SizedBox(width: 6),
                                Text(
                                  'Chạm để phóng to ảnh',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF991B1B).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF43F5E), width: 2),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 18, color: Color(0xFFFECDD3), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Form Container Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Date Field
                      Text(
                        'Ngày nhập phiếu',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppFormatters.formatDate(_selectedDate),
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              const Icon(Icons.calendar_today_rounded, size: 28, color: Color(0xFF0284C7)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Boat Number Field
                      Text(
                        'Số ghe',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _boatController,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: AG 0204',
                          hintStyle: TextStyle(color: isDark ? Colors.grey : const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.directions_boat_rounded, size: 28, color: Color(0xFF0284C7)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        onChanged: (val) {
                          if (!_editedFields.contains('boatNumber')) _editedFields.add('boatNumber');
                          _wasEdited = true;
                        },
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập số ghe';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Weight Field
                      Text(
                        'Khối lượng (kg)',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: 80956',
                          hintStyle: TextStyle(color: isDark ? Colors.grey : const Color(0xFF94A3B8)),
                          suffixText: 'kg',
                          suffixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          prefixIcon: const Icon(Icons.scale_rounded, size: 28, color: Color(0xFF0284C7)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        onChanged: (val) {
                          if (!_editedFields.contains('weightKg')) _editedFields.add('weightKg');
                          _wasEdited = true;
                        },
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập khối lượng (kg)';
                          }
                          final n = int.tryParse(val.trim());
                          if (n == null || n <= 0) {
                            return 'Khối lượng phải là số nguyên lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Price / Kg Field
                      Text(
                        'Giá trấu (đ/kg)',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFFDE047) : const Color(0xFFD97706)),
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: 7500',
                          hintStyle: TextStyle(color: isDark ? Colors.grey : const Color(0xFF94A3B8)),
                          suffixText: 'đ/kg',
                          suffixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          prefixIcon: Icon(Icons.payments_rounded, size: 28, color: isDark ? const Color(0xFFFDE047) : const Color(0xFFD97706)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        onChanged: (val) {
                          if (!_editedFields.contains('pricePerKg')) _editedFields.add('pricePerKg');
                          _wasEdited = true;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Converted Tons & Total Money Display Box
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF065F46), Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF047857).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calculate_rounded, size: 32, color: Color(0xFFA7F3D0)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TỔNG QUY ĐỔI KHỐI LƯỢNG',
                                        style: TextStyle(fontSize: 14, color: Color(0xFFA7F3D0), fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        AppFormatters.formatKgToTons(_calculatedKg),
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_calculatedPrice > 0 && _calculatedKg > 0) ...[
                              const Divider(color: Color(0xFF34D399), height: 24, thickness: 1),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TỔNG THÀNH TIỀN:',
                                    style: TextStyle(fontSize: 16, color: Color(0xFFFDE047), fontWeight: FontWeight.bold),
                                  ),
                                  FittedBox(
                                    child: Text(
                                      AppFormatters.formatFullCurrency(_calculatedKg * _calculatedPrice),
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFFDE047),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Note Field
                      const Text(
                        'Ghi chú (Không bắt buộc)',
                        style: TextStyle(fontSize: 17, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nhập ghi chú thêm nếu có...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Action Buttons
                Row(
                  children: [
                    if (widget.imageFile != null) ...[
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.camera_alt_rounded, size: 26),
                            label: const Text(
                              'Chụp lại',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF97316),
                              side: const BorderSide(color: Color(0xFFEA580C), width: 2.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleSave,
                          icon: _isLoading
                              ? const SizedBox.shrink()
                              : const Icon(Icons.check_circle_rounded, size: 28),
                          label: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              : const Text(
                                  'XÁC NHẬN LƯU',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 6,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
      ),
    );
  }
}
