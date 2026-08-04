import 'package:intl/intl.dart';

class AppFormatters {
  static String formatKgToTons(int weightKg) {
    double tons = weightKg / 1000.0;
    NumberFormat formatter = NumberFormat('#,##0.000', 'vi_VN');
    // Format double to Vietnamese locale string
    String formatted = formatter.format(tons);
    // Trim trailing zeroes after decimal point if present
    if (formatted.contains(',')) {
      formatted = formatted
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r',+$'), '');
    }
    return '$formatted tấn';
  }

  static String formatKg(int weightKg) {
    NumberFormat formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(weightKg)} kg';
  }

  static String formatDate(DateTime date) {
    return '${formatWeekday(date)}, ${DateFormat('dd/MM/yyyy').format(date)}';
  }

  static String formatDateTime(DateTime date) {
    return '${formatWeekday(date)}, ${DateFormat('dd/MM/yyyy HH:mm').format(date)}';
  }

  static String formatWeekday(DateTime date) => switch (date.weekday) {
    DateTime.monday => 'Thứ Hai',
    DateTime.tuesday => 'Thứ Ba',
    DateTime.wednesday => 'Thứ Tư',
    DateTime.thursday => 'Thứ Năm',
    DateTime.friday => 'Thứ Sáu',
    DateTime.saturday => 'Thứ Bảy',
    _ => 'Chủ Nhật',
  };

  static String formatMonthYear(DateTime date) {
    return DateFormat('MM/yyyy').format(date);
  }

  static String formatCurrency(num amount) {
    if (amount <= 0) return '0 đ';
    if (amount >= 1000000000) {
      double ty = amount / 1000000000.0;
      return '${NumberFormat('#,##0.00', 'vi_VN').format(ty)} tỷ đ';
    } else if (amount >= 1000000) {
      double trieu = amount / 1000000.0;
      return '${NumberFormat('#,##0.00', 'vi_VN').format(trieu)} tr đ';
    }
    NumberFormat formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }

  static String formatFullCurrency(num amount) {
    NumberFormat formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }

  static String formatPricePerKg(num price) {
    NumberFormat formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(price)} đ/kg';
  }
}
