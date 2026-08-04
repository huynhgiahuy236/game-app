import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/formatters.dart';
import '../models/boat_receipt_model.dart';
import '../services/boat_receipt_repository.dart';
import 'receipt_ui.dart';

class EditReceiptScreen extends StatefulWidget {
  final BoatReceiptModel receipt;
  const EditReceiptScreen({super.key, required this.receipt});

  @override
  State<EditReceiptScreen> createState() => _EditReceiptScreenState();
}

class _EditReceiptScreenState extends State<EditReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = BoatReceiptRepository();
  late final TextEditingController _boatController;
  late final TextEditingController _weightController;
  late final TextEditingController _priceController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  bool _isLoading = false;
  String? _errorMessage;

  int get _kg => int.tryParse(_weightController.text) ?? 0;
  int get _price => int.tryParse(_priceController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.receipt.receiptDate;
    _boatController = TextEditingController(text: widget.receipt.boatNumber);
    _weightController = TextEditingController(
      text: '${widget.receipt.weightKg}',
    );
    _priceController = TextEditingController(
      text:
          '${widget.receipt.pricePerKg > 0 ? widget.receipt.pricePerKg : 7500}',
    );
    _noteController = TextEditingController(text: widget.receipt.note);
    _weightController.addListener(_refresh);
    _priceController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _weightController.removeListener(_refresh);
    _priceController.removeListener(_refresh);
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
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
        weightKg: _kg,
        pricePerKg: _price,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật phiếu'),
          backgroundColor: ReceiptColors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ReceiptUi.canvas(context),
    appBar: ReceiptUi.appBar(
      context,
      'Chỉnh sửa phiếu',
      subtitle: widget.receipt.boatNumber,
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ReceiptUi.surface(context),
          border: Border(top: BorderSide(color: ReceiptUi.line(context))),
        ),
        child: SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: ReceiptColors.blueStrong,
            ),
            icon: _isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _isLoading ? 'Đang lưu...' : 'Lưu thay đổi',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    ),
    body: SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                ReceiptErrorState(message: _errorMessage!),
                const SizedBox(height: 14),
              ],
              ReceiptSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ReceiptSectionTitle('Thông tin phiếu'),
                    const SizedBox(height: 16),
                    _label('Ngày cân vào'),
                    const SizedBox(height: 7),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: ReceiptUi.input(
                          context,
                          icon: Icons.calendar_month_outlined,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppFormatters.formatDate(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Số ghe'),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _boatController,
                      readOnly: true,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration:
                          ReceiptUi.input(
                            context,
                            icon: Icons.directions_boat_outlined,
                          ).copyWith(
                            suffixIcon: PopupMenuButton<String>(
                              icon: const Icon(Icons.arrow_drop_down_rounded),
                              onSelected: (value) =>
                                  setState(() => _boatController.text = value),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'DT-2764',
                                  child: Text(
                                    'DT-2764',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'AG-26911',
                                  child: Text(
                                    'AG-26911',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ),
                    const SizedBox(height: 16),
                    _label('Khối lượng'),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: ReceiptUi.input(
                        context,
                        icon: Icons.scale_outlined,
                        suffix: 'kg',
                      ),
                      validator: (value) =>
                          (int.tryParse(value ?? '') ?? 0) <= 0
                          ? 'Nhập khối lượng lớn hơn 0'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _label('Đơn giá trấu'),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: ReceiptUi.input(
                        context,
                        icon: Icons.payments_outlined,
                        suffix: 'đ/kg',
                      ),
                      validator: (value) =>
                          (int.tryParse(value ?? '') ?? 0) <= 0
                          ? 'Nhập đơn giá hợp lệ'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _summary(),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(fontSize: 17),
                decoration: ReceiptUi.input(
                  context,
                  icon: Icons.notes_rounded,
                  hint: 'Ghi chú (không bắt buộc)',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
  );

  Widget _summary() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0D3329)
          : const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFA7F3D0)),
    ),
    child: Column(
      children: [
        _summaryRow(
          'Quy đổi',
          AppFormatters.formatKgToTons(_kg),
          ReceiptColors.blueStrong,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        _summaryRow(
          'Thành tiền',
          _kg > 0 && _price > 0
              ? AppFormatters.formatFullCurrency(_kg * _price)
              : '—',
          ReceiptColors.green,
        ),
      ],
    ),
  );

  Widget _summaryRow(String label, String value, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    ],
  );
}
