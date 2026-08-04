import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../services/boat_receipt_repository.dart';

class EditReceiptScreen extends StatefulWidget {
  final BoatReceiptModel receipt;

  const EditReceiptScreen({super.key, required this.receipt});

  @override
  State<EditReceiptScreen> createState() => _EditReceiptScreenState();
}

class _EditReceiptScreenState extends State<EditReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final BoatReceiptRepository _repository = BoatReceiptRepository();

  late TextEditingController _boatController;
  late TextEditingController _weightController;
  late TextEditingController _noteController;

  late DateTime _selectedDate;
  bool _isLoading = false;
  String? _errorMessage;
  int _calculatedKg = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.receipt.receiptDate;
    _boatController = TextEditingController(text: widget.receipt.boatNumber);
    _weightController = TextEditingController(text: widget.receipt.weightKg.toString());
    _noteController = TextEditingController(text: widget.receipt.note);
    _calculatedKg = widget.receipt.weightKg;

    _weightController.addListener(() {
      setState(() {
        _calculatedKg = int.tryParse(_weightController.text.trim()) ?? 0;
      });
    });
  }

  @override
  void dispose() {
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
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
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
      await _repository.updateReceipt(
        widget.receipt.id,
        receiptDate: _selectedDate.toIso8601String(),
        boatNumber: _boatController.text.trim().toUpperCase(),
        weightKg: int.parse(_weightController.text.trim()),
        note: _noteController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật thông tin phiếu'), backgroundColor: Colors.green),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('CHỈNH SỬA PHIẾU GHE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(fontSize: 18, color: Colors.red)),
                  ),
                  const SizedBox(height: 20),
                ],

                // Date
                const Text('Ngày nhập', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
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
                        Text(AppFormatters.formatDate(_selectedDate), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Icon(Icons.calendar_today, size: 28, color: Colors.blue.shade800),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Boat number
                const Text('Số ghe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _boatController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.directions_boat, size: 28),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập số ghe' : null,
                ),
                const SizedBox(height: 20),

                // Weight
                const Text('Khối lượng (kg)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  decoration: InputDecoration(
                    suffixText: 'kg',
                    prefixIcon: const Icon(Icons.scale, size: 28),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số kg';
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Số kg phải lớn hơn 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Conversion
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
                          const Text('Quy đổi ra tấn', style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
                          Text(AppFormatters.formatKgToTons(_calculatedKg), style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Note
                const Text('Ghi chú', style: TextStyle(fontSize: 18, color: Color(0xFF444444))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleSave,
                    icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.save, size: 28),
                    label: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('LƯU THAY ĐỔI', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade900,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
