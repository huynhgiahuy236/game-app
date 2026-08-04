import 'package:flutter_test/flutter_test.dart';
import 'package:gameapp/core/utils/formatters.dart';

void main() {
  test('hiển thị ngày kèm đúng thứ tiếng Việt', () {
    expect(
      AppFormatters.formatDate(DateTime(2026, 8, 3)),
      'Thứ Hai, 03/08/2026',
    );
    expect(
      AppFormatters.formatDate(DateTime(2026, 8, 9)),
      'Chủ Nhật, 09/08/2026',
    );
  });
}
