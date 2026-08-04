# Backend Dịch Vụ API Sổ Ghe & Chị Mười App

Hệ thống API RESTful xây dựng bằng Node.js, TypeScript, Express, MongoDB Atlas, Cloudinary và JWT Authentication.

## Tính năng chính
- **Xác thực JWT bảo mật**: Access token (15 phút), Refresh token (90 ngày) lưu hash trong collection `auth_sessions`.
- **Seed User Command**: Lệnh `npm run seed:user` để khởi tạo tài khoản đăng nhập mà không mở đăng ký công khai.
- **Quản lý phiếu ghe**: Nhập số kg, quy đổi tự động ra tấn, lọc danh sách theo ngày/tháng/năm/số ghe.
- **Idempotency clientId**: Chống ghi trùng dữ liệu khi bị rớt mạng hoặc bấm lưu nhiều lần.
- **Cloudinary Storage**: Tự động tải ảnh phiếu lên Cloudinary và cơ chế hoàn tác (Rollback) xóa ảnh trên Cloudinary nếu lưu MongoDB thất bại.
- **Thống kê nâng cao**: Sử dụng MongoDB Aggregation để tổng hợp chuyến, tổng kg, tổng tấn, ngày/tháng cao nhất.

## Hướng dẫn chạy
```bash
npm install
npm run seed:user
npm run dev
```

## Chạy kiểm thử tự động
```bash
npm test
```
