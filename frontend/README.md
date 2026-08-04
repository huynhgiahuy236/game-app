# Frontend Ứng Dụng Di Động Chị Mười (Flutter)

Ứng dụng di động Flutter thiết kế giao diện chữ lớn (18sp-28sp), tương phản cao, nút bấm to (52-60px) dành riêng cho người lớn tuổi.

## Các module chính
1. **Đăng nhập & Phục hồi phiên**: Sử dụng `flutter_secure_storage` lưu JWT token. Tự động phục hồi phiên làm việc khi mở ứng dụng.
2. **Trang chủ chọn module**:
   - `Trò chơi`: Bảo tồn 100% các game sẵn có (Caro, 2048, Sudoku, Đổ mìn, Cờ tỷ phú, Block Puzzle).
   - `Sổ ghe`: Quản lý phiếu nhập lúa, chụp ảnh OCR trợ lý, quy đổi kg ra tấn.
3. **Thống kê & Lịch sử**: Xem biểu đồ số liệu dạng con số lớn dễ nhìn theo Ngày, Tháng, Năm, Số ghe.

## Chạy ứng dụng
```bash
flutter pub get
flutter run
```

## Chạy kiểm thử
```bash
flutter analyze
flutter test
```
