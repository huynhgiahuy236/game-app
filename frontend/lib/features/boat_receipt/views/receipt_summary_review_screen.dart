import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gameapp/core/utils/formatters.dart';
import 'receipt_ui.dart';

class ReceiptSummaryReviewScreen extends StatelessWidget {
  final String boatNumber;
  final DateTime date;
  final int weightKg;
  final int pricePerKg;
  final String note;
  final File? imageFile;

  const ReceiptSummaryReviewScreen({
    super.key,
    required this.boatNumber,
    required this.date,
    required this.weightKg,
    required this.pricePerKg,
    this.note = '',
    this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final weightTons = AppFormatters.formatKgToTons(weightKg);
    final weightKgFormatted = AppFormatters.formatKg(weightKg);
    final priceStr = AppFormatters.formatPricePerKg(pricePerKg);
    final totalAmount = weightKg * pricePerKg;
    final totalStr = weightKg > 0 && pricePerKg > 0
        ? AppFormatters.formatFullCurrency(totalAmount)
        : '0 đ';

    return Scaffold(
      backgroundColor: ReceiptUi.canvas(context),
      appBar: AppBar(
        title: const Text(
          'Xác nhận thông tin phiếu',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Boat Header Badge
            ReceiptSurface(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  BoatAvatarBadge(boatNumber: boatNumber, size: 54),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ghe $boatNumber',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: ReceiptUi.ink(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppFormatters.formatDate(date),
                          style: TextStyle(
                            fontSize: 16,
                            color: ReceiptUi.secondaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Detailed Data Card
            ReceiptSurface(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  _reviewRow(
                    context,
                    label: 'Số ghe',
                    value: 'Ghe $boatNumber',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1),
                  ),
                  _reviewRow(
                    context,
                    label: 'Ngày cân',
                    value: AppFormatters.formatDate(date),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1),
                  ),
                  _reviewRow(
                    context,
                    label: 'Khối lượng',
                    value: '$weightTons ($weightKgFormatted)',
                    valueColor: ReceiptColors.green,
                    isHighlight: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1),
                  ),
                  _reviewRow(
                    context,
                    label: 'Đơn giá trấu',
                    value: priceStr,
                  ),
                  if (note.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1),
                    ),
                    _reviewRow(
                      context,
                      label: 'Ghi chú',
                      value: note,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Total Amount Large Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF0D3329) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dark ? const Color(0xFF176A52) : const Color(0xFFA7F3D0),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TỔNG THÀNH TIỀN',
                    style: TextStyle(
                      fontSize: 15,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: dark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    totalStr,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: dark ? const Color(0xFFFDE047) : const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: ReceiptUi.surface(context),
            border: Border(top: BorderSide(color: ReceiptUi.line(context))),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: ReceiptUi.line(context), width: 1.5),
                    ),
                    child: Text(
                      'Sửa lại',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ReceiptUi.ink(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: ReceiptColors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 24),
                    label: const Text(
                      'Xác nhận lưu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: ReceiptUi.secondaryText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isHighlight ? 18 : 17,
              fontWeight: FontWeight.w800,
              color: valueColor ?? ReceiptUi.ink(context),
            ),
          ),
        ),
      ],
    );
  }
}
