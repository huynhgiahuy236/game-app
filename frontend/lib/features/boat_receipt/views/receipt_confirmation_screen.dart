import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/formatters.dart';
import '../services/boat_receipt_repository.dart';
import '../services/ocr_service.dart';
import 'receipt_image_viewer_screen.dart';
import 'receipt_ui.dart';

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

class _ReceiptConfirmationScreenState
    extends State<ReceiptConfirmationScreen> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReceiptUi.canvas(context),
      appBar: ReceiptUi.appBar(
        context,
        'Kiểm tra phiếu',
        subtitle: 'Xác nhận thông tin trước khi lưu',
      ),
      bottomNavigationBar: _bottomActions(),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth < 380 ? 16 : 20,
              12,
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
                      if (_fromOcr) _reviewNotice(),
                      const SizedBox(height: 14),
                      _imageOrPlaceholderPreview(),
                      if (_fromOcr) ...[
                        const SizedBox(height: 14),
                        _ocrDebugCard(),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        ReceiptErrorState(message: _errorMessage!),
                      ],
                      const SizedBox(height: 16),
                      _formCard(),
                      const SizedBox(height: 16),
                      _summaryCard(),
                      const SizedBox(height: 16),
                      _noteField(),
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

  Widget _reviewNotice() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _ocrFoundAnything
        ? (dark ? const Color(0xFF1E1933) : const Color(0xFFF3E8FF))
        : (dark ? const Color(0xFF332014) : const Color(0xFFFFF7ED));
    final borderColor = _ocrFoundAnything
        ? ReceiptColors.blue
        : ReceiptColors.amber;
    final iconColor = _ocrFoundAnything
        ? ReceiptColors.blue
        : ReceiptColors.amber;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _ocrFoundAnything
                ? Icons.fact_check_outlined
                : Icons.camera_alt_outlined,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _ocrFoundAnything
                  ? 'Đã đọc thông tin từ ảnh. Hãy đối chiếu 3 mục được đánh dấu bên dưới.'
                  : 'Ảnh chưa đủ rõ để đọc tự động. Hãy chụp lại thẳng phiếu, đủ sáng và không bị lóa.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageOrPlaceholderPreview() {
    if (widget.imageFile != null) {
      return Semantics(
        button: true,
        label: 'Mở ảnh phiếu gốc để đối chiếu',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ReceiptImageViewerScreen(localFile: widget.imageFile),
              ),
            ),
            child: Ink(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!kIsWeb)
                      Image.file(widget.imageFile!, fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Color(0xDD000000)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Xem phiếu gốc',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
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
    }

    // Khi không có file ảnh trực tiếp (nhập tay / test data), hiển thị BoatImagePlaceholder giả lập
    return BoatImagePlaceholder(
      boatNumber: _boatController.text.trim().toUpperCase(),
      height: 130,
    );
  }

  Widget _ocrDebugCard() => ReceiptSurface(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(
        Icons.manage_search_rounded,
        color: ReceiptColors.blue,
      ),
      title: const Text(
        'Máy đã đọc được gì?',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Mở mục này khi kết quả nhận diện bị sai',
        style: TextStyle(fontSize: 13, color: ReceiptUi.secondaryText(context)),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _ocrValue('Ngày bóc được', widget.ocrResult?.extractedDate),
        _ocrValue('Ghe dự đoán', widget.ocrResult?.extractedBoatNumber),
        _ocrValue('Khối lượng bóc được', widget.ocrResult?.extractedWeightKg),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Văn bản OCR thô',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ReceiptUi.secondaryText(context),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ReceiptUi.canvas(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              widget.ocrResult?.rawText.trim().isNotEmpty == true
                  ? widget.ocrResult!.rawText
                  : '(ML Kit không đọc được chữ nào từ ảnh)',
              style: const TextStyle(fontSize: 14, height: 1.45),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _formCard() => ReceiptSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Thông tin cần xác nhận',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Ưu tiên dữ liệu viết tay trên phiếu.',
          style: TextStyle(
            fontSize: 14,
            color: ReceiptUi.secondaryText(context),
          ),
        ),
        const SizedBox(height: 18),
        _label('Ngày cân vào', fromScan: _fromOcr),
        const SizedBox(height: 8),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _label('Số xe / Tên ghe (tàu)', fromScan: _fromOcr),
        const SizedBox(height: 8),
        // Bộ chọn nhanh giữa ghe DT-2764 và AG-26911
        Row(
          children: [
            Expanded(child: _quickBoatChip('DT-2764')),
            const SizedBox(width: 10),
            Expanded(child: _quickBoatChip('AG-26911')),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _boatController,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          decoration: ReceiptUi.input(
            context,
            icon: Icons.directions_boat_outlined,
            hint: 'Chọn DT-2764 hoặc AG-26911',
          ).copyWith(
            suffixIcon: PopupMenuButton<String>(
              tooltip: 'Chọn số ghe',
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 28),
              onSelected: (value) {
                _boatController.text = value;
                _markEdited('boatNumber');
                setState(() {});
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'DT-2764',
                  child: Row(
                    children: [
                      BoatAvatarBadge(boatNumber: 'DT-2764', size: 30),
                      SizedBox(width: 10),
                      Text('DT-2764', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'AG-26911',
                  child: Row(
                    children: [
                      BoatAvatarBadge(boatNumber: 'AG-26911', size: 30),
                      SizedBox(width: 10),
                      Text('AG-26911', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ],
                  ),
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
        const SizedBox(height: 18),
        _label('Khối lượng', fromScan: _fromOcr),
        const SizedBox(height: 8),
        TextFormField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          decoration: ReceiptUi.input(
            context,
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
        const SizedBox(height: 18),
        _label('Đơn giá trấu'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          decoration: ReceiptUi.input(
            context,
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

  Widget _quickBoatChip(String boatName) {
    final selected = _boatController.text.trim().toUpperCase() == boatName;
    return ChoiceChip(
      showCheckmark: false,
      avatar: BoatAvatarBadge(boatNumber: boatName, size: 26),
      label: Text(
        boatName,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: selected ? Colors.white : ReceiptColors.ink,
        ),
      ),
      selected: selected,
      selectedColor: boatName.contains('AG') ? const Color(0xFF047857) : const Color(0xFF4338CA),
      backgroundColor: ReceiptUi.canvas(context),
      onSelected: (isSelected) {
        if (isSelected) {
          setState(() {
            _boatController.text = boatName;
            _markEdited('boatNumber');
          });
        }
      },
    );
  }

  Widget _label(String text, {bool fromScan = false}) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      if (fromScan)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ReceiptColors.blueSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Từ ảnh',
            style: TextStyle(
              color: ReceiptColors.blue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
    ],
  );

  Widget _summaryCard() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D3329) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? const Color(0xFF176A52) : const Color(0xFFA7F3D0),
          width: 1.5,
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
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _summaryRow(
            'Thành tiền',
            _weight > 0 && _price > 0
                ? AppFormatters.formatFullCurrency(_weight * _price)
                : '—',
            dark ? const Color(0xFFFDE047) : const Color(0xFF047857),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    ],
  );

  Widget _noteField() => TextFormField(
    controller: _noteController,
    maxLines: 3,
    minLines: 2,
    decoration: ReceiptUi.input(
      context,
      icon: Icons.notes_rounded,
      hint: 'Ghi chú (không bắt buộc)',
    ),
  );

  Widget _bottomActions() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: ReceiptUi.surface(context),
        border: Border(top: BorderSide(color: ReceiptUi.line(context))),
      ),
      child: Row(
        children: [
          if (widget.imageFile != null) ...[
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Chụp lại'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: ReceiptColors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
