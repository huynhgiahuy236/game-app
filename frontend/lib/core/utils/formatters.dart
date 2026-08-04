import 'package:intl/intl.dart';

class AppFormatters {
  static String formatKgToTons(int weightKg) {
    double tons = weightKg / 1000.0;
    NumberFormat formatter = NumberFormat('#,##0.000', 'vi_VN');
    // Format double to Vietnamese locale string
    String formatted = formatter.format(tons);
    // Trim trailing zeroes after decimal point if present
    if (formatted.contains(',')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r',+$'), '');
    }
    return '$formatted tấn';
  }

  static String formatKg(int weightKg) {
    NumberFormat formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(weightKg)} kg';
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MM/yyyy').format(date);
  }
}
