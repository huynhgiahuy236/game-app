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
  late TextEditingController _noteController;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;
  int _calculatedKg = 0;
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
    _noteController = TextEditingController();

    if (weightStr.isNotEmpty) {
      _calculatedKg = int.tryParse(weightStr) ?? 0;
    }

    _weightController.addListener(_onWeightChanged);
  }

  void _onWeightChanged() {
    final val = int.tryParse(_weightController.text.trim()) ?? 0;
    setState(() {
      _calculatedKg = val;
    });
  }

  @override
  void dispose() {
    _weightController.removeListener(_onWeightChanged);
    _boatController.dispose();
    _weightController.dispose();
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
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue.shade800),
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
      final note = _noteController.text.trim();

      await _repository.createReceipt(
        clientId: clientId,
        receiptDate: dateIso,
        boatNumber: boatNum,
        weightKg: weightKg,
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
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // Return to home & refresh
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'XÁC NHẬN PHIẾU',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image preview with tap to zoom
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
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade300, width: 2),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: kIsWeb
                                ? const Text('Preview')
                                : Image.file(widget.imageFile!, fit: BoxFit.cover, width: double.infinity),
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
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Receipt Date
                const Text(
                  'Ngày nhập',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade400, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppFormatters.formatDate(_selectedDate),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        Icon(Icons.calendar_today, size: 28, color: Colors.blue.shade800),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Boat Number
                const Text(
                  'Số ghe',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _boatController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: AG 0204',
                    prefixIcon: const Icon(Icons.directions_boat, size: 28),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.5),
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

                // Weight in Kg
                const Text(
                  'Khối lượng (kg)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 80956',
                    suffixText: 'kg',
                    suffixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    prefixIcon: const Icon(Icons.scale, size: 28),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.5),
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
                const SizedBox(height: 12),

                // Converted Tons Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, size: 32, color: Colors.blue.shade900),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tương đương quy đổi',
                            style: TextStyle(fontSize: 16, color: Color(0xFF555555)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.formatKgToTons(_calculatedKg),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Optional Note
                const Text(
                  'Ghi chú (Không bắt buộc)',
                  style: TextStyle(fontSize: 18, color: Color(0xFF444444)),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Nhập ghi chú thêm nếu có...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    if (widget.imageFile != null) ...[
                      Expanded(
                        child: SizedBox(
                          height: 58,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.camera_alt, size: 26),
                            label: const Text(
                              'Chụp lại',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade900,
                              side: BorderSide(color: Colors.orange.shade800, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleSave,
                          icon: _isLoading
                              ? const SizedBox.shrink()
                              : const Icon(Icons.check_circle, size: 28),
                          label: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'XÁC NHẬN LƯU',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade800,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
