import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  State<ReceiptConfirmationScreen> createState() =>
      _ReceiptConfirmationScreenState();
}

class _ReceiptConfirmationScreenState extends State<ReceiptConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = BoatReceiptRepository();
  late final TextEditingController _boatController;
  late final TextEditingController _weightController;
  late final TextEditingController _priceController;
  late final TextEditingController _noteController;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _wasEdited = false;
  String? _errorMessage;
  final List<String> _editedFields = [];

  int get _weight => int.tryParse(_weightController.text) ?? 0;
  int get _price => int.tryParse(_priceController.text) ?? 0;
  bool get _fromOcr => widget.ocrResult != null;
  bool get _ocrFoundAnything =>
      widget.ocrResult?.extractedDate != null ||
      widget.ocrResult?.extractedBoatNumber != null ||
      widget.ocrResult?.extractedWeightKg != null;

  @override
  void initState() {
    super.initState();
    final date = widget.ocrResult?.extractedDate?.split('/');
    if (date?.length == 3) {
      _selectedDate =
          DateTime.tryParse(
            '${date![2]}-${date[1].padLeft(2, '0')}-${date[0].padLeft(2, '0')}',
          ) ??
          DateTime.now();
    }
    _boatController = TextEditingController(
      text: widget.ocrResult?.extractedBoatNumber ?? '',
    );
    _weightController = TextEditingController(
      text: widget.ocrResult?.extractedWeightKg ?? '',
    );
    _priceController = TextEditingController(text: '7500');
    _noteController = TextEditingController();
    _weightController.addListener(_refreshTotals);
    _priceController.addListener(_refreshTotals);
  }

  void _refreshTotals() => setState(() {});

  void _markEdited(String field) {
    _wasEdited = true;
    if (!_editedFields.contains(field)) _editedFields.add(field);
  }

  @override
  void dispose() {
    _weightController.removeListener(_refreshTotals);
    _priceController.removeListener(_refreshTotals);
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
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _markEdited('receiptDate');
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _repository.createReceipt(
        clientId: _repository.generateClientId(),
        receiptDate: _selectedDate.toIso8601String(),
        boatNumber: _boatController.text.trim().toUpperCase(),
        weightKg: _weight,
        pricePerKg: _price,
        note: _noteController.text.trim(),
        imageFile: widget.imageFile,
        inputMethod: widget.inputMethod,
        ocrRawText: widget.ocrResult?.rawText,
        ocrDate: widget.ocrResult?.extractedDate,
        ocrBoat: widget.ocrResult?.extractedBoatNumber,
        ocrWeight: widget.ocrResult?.extractedWeightKg,
        wasEdited: _wasEdited,
        editedFields: _editedFields,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu phiếu thành công'),
          backgroundColor: Color(0xFF047857),
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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0B1220) : const Color(0xFFF6F8FB);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kiểm tra phiếu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text(
              'Xác nhận trước khi lưu',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomActions(dark),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth < 380 ? 16 : 20,
              8,
              constraints.maxWidth < 380 ? 16 : 20,
              28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_fromOcr) _reviewNotice(dark),
                      if (widget.imageFile != null) ...[
                        const SizedBox(height: 12),
                        _imagePreview(),
                      ],
                      if (_fromOcr) ...[
                        const SizedBox(height: 12),
                        _ocrDebugCard(dark),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _errorCard(),
                      ],
                      const SizedBox(height: 16),
                      _formCard(dark),
                      const SizedBox(height: 16),
                      _summaryCard(dark),
                      const SizedBox(height: 16),
                      _noteField(dark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewNotice(bool dark) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _ocrFoundAnything
          ? (dark ? const Color(0xFF102A43) : const Color(0xFFEFF6FF))
          : (dark ? const Color(0xFF3B2410) : const Color(0xFFFFF7ED)),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: _ocrFoundAnything
            ? (dark ? const Color(0xFF1D4F70) : const Color(0xFFBFDBFE))
            : const Color(0xFFF59E0B),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _ocrFoundAnything
              ? Icons.fact_check_outlined
              : Icons.camera_alt_outlined,
          color: _ocrFoundAnything
              ? const Color(0xFF0284C7)
              : const Color(0xFFD97706),
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _ocrFoundAnything
                ? 'Đã đọc thông tin từ ảnh. Hãy đối chiếu 3 mục được đánh dấu bên dưới.'
                : 'Ảnh chưa đủ rõ để đọc tự động. Hãy chụp lại thẳng phiếu, đủ sáng và không bị lóa.',
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _imagePreview() => Semantics(
    button: true,
    label: 'Mở ảnh phiếu gốc để đối chiếu',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ReceiptImageViewerScreen(localFile: widget.imageFile),
          ),
        ),
        child: Ink(
          height: 112,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!kIsWeb) Image.file(widget.imageFile!, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0xCC000000)],
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const Positioned(
                  left: 14,
                  right: 14,
                  bottom: 11,
                  child: Row(
                    children: [
                      Icon(Icons.image_outlined, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Xem phiếu gốc',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _ocrDebugCard(bool dark) => Container(
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF151F2E) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: dark ? const Color(0xFF2A3A4F) : const Color(0xFFE2E8F0),
      ),
    ),
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(
        Icons.manage_search_rounded,
        color: Color(0xFF0284C7),
      ),
      title: const Text(
        'Máy đã đọc được gì?',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      subtitle: const Text(
        'Mở mục này khi kết quả nhận diện bị sai',
        style: TextStyle(fontSize: 14),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _ocrValue('Ngày bóc được', widget.ocrResult?.extractedDate),
        _ocrValue('Ghe dự đoán', widget.ocrResult?.extractedBoatNumber),
        _ocrValue('Khối lượng bóc được', widget.ocrResult?.extractedWeightKg),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Văn bản OCR thô',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              widget.ocrResult?.rawText.trim().isNotEmpty == true
                  ? widget.ocrResult!.rawText
                  : '(ML Kit không đọc được chữ nào từ ảnh)',
              style: const TextStyle(fontSize: 15, height: 1.45),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _ocrValue(String label, String? value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value?.isNotEmpty == true ? value! : '(không đọc được)',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _formCard(bool dark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF151F2E) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: dark ? const Color(0xFF2A3A4F) : const Color(0xFFE2E8F0),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Thông tin cần xác nhận',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Ưu tiên dữ liệu viết tay trên phiếu.',
          style: TextStyle(
            fontSize: 15,
            color: dark ? const Color(0xFF9FB0C5) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 18),
        _label('Ngày cân vào', fromScan: _fromOcr),
        const SizedBox(height: 7),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _decoration(dark, icon: Icons.calendar_month_outlined),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppFormatters.formatDate(_selectedDate),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _label('Số xe / Tên ghe (tàu)', fromScan: _fromOcr),
        const SizedBox(height: 7),
        TextFormField(
          controller: _boatController,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          decoration:
              _decoration(
                dark,
                icon: Icons.directions_boat_outlined,
                hint: 'Chọn DT-2764 hoặc AG-26911',
              ).copyWith(
                suffixIcon: PopupMenuButton<String>(
                  tooltip: 'Chọn số ghe',
                  icon: const Icon(Icons.arrow_drop_down_rounded, size: 30),
                  onSelected: (value) {
                    _boatController.text = value;
                    _markEdited('boatNumber');
                    setState(() {});
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'DT-2764',
                      child: Text('DT-2764', style: TextStyle(fontSize: 19)),
                    ),
                    PopupMenuItem(
                      value: 'AG-26911',
                      child: Text('AG-26911', style: TextStyle(fontSize: 19)),
                    ),
                  ],
                ),
              ),
          onChanged: (_) => _markEdited('boatNumber'),
          validator: (value) {
            final boat = value?.trim().toUpperCase();
            return boat == 'DT-2764' || boat == 'AG-26911'
                ? null
                : 'Hãy chọn DT-2764 hoặc AG-26911';
          },
        ),
        const SizedBox(height: 16),
        _label('Khối lượng', fromScan: _fromOcr),
        const SizedBox(height: 7),
        TextFormField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          decoration: _decoration(
            dark,
            icon: Icons.scale_outlined,
            hint: 'Ví dụ: 80956',
            suffix: 'kg',
          ),
          onChanged: (_) => _markEdited('weightKg'),
          validator: (value) {
            final number = int.tryParse(value ?? '');
            return number == null || number <= 0
                ? 'Nhập khối lượng hợp lệ, ví dụ 80956'
                : null;
          },
        ),
        const SizedBox(height: 16),
        _label('Đơn giá trấu'),
        const SizedBox(height: 7),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          decoration: _decoration(
            dark,
            icon: Icons.payments_outlined,
            suffix: 'đ/kg',
          ),
          onChanged: (_) => _markEdited('pricePerKg'),
          validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
              ? 'Vui lòng nhập đơn giá'
              : null,
        ),
      ],
    ),
  );

  Widget _label(String text, {bool fromScan = false}) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      if (fromScan)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Từ ảnh',
            style: TextStyle(
              color: Color(0xFF0369A1),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ],
  );

  InputDecoration _decoration(
    bool dark, {
    required IconData icon,
    String? hint,
    String? suffix,
  }) => InputDecoration(
    hintText: hint,
    suffixText: suffix,
    prefixIcon: Icon(icon, size: 22, color: const Color(0xFF0284C7)),
    filled: true,
    fillColor: dark ? const Color(0xFF0F1825) : const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: dark ? const Color(0xFF34455B) : const Color(0xFFCBD5E1),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF0284C7), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDC2626)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
    ),
  );

  Widget _summaryCard(bool dark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF0D3329) : const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: dark ? const Color(0xFF176A52) : const Color(0xFFA7F3D0),
      ),
    ),
    child: Column(
      children: [
        _summaryRow(
          'Quy đổi',
          AppFormatters.formatKgToTons(_weight),
          const Color(0xFF059669),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        _summaryRow(
          'Thành tiền',
          _weight > 0 && _price > 0
              ? AppFormatters.formatFullCurrency(_weight * _price)
              : '—',
          dark ? const Color(0xFFFDE047) : const Color(0xFF9A6700),
        ),
      ],
    ),
  );

  Widget _summaryRow(String label, String value, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          softWrap: true,
          style: TextStyle(
            fontSize: 22,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    ],
  );

  Widget _noteField(bool dark) => TextFormField(
    controller: _noteController,
    maxLines: 3,
    minLines: 2,
    decoration: _decoration(
      dark,
      icon: Icons.notes_rounded,
      hint: 'Ghi chú (không bắt buộc)',
    ),
  );

  Widget _errorCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Color(0xFF991B1B)),
          ),
        ),
      ],
    ),
  );

  Widget _bottomActions(bool dark) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF101927) : Colors.white,
        border: Border(
          top: BorderSide(
            color: dark ? const Color(0xFF263548) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.imageFile != null) ...[
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Chụp lại'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _isLoading ? 'Đang lưu...' : 'Xác nhận và lưu',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
