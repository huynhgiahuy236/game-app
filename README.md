# Chị Mười Application Project (GameApp + Sổ Ghe)

Dự án ứng dụng di động Flutter và dịch vụ backend Node.js TypeScript phục vụ quản lý phiếu ghe nhập lúa ("Sổ ghe") và các trò chơi giải trí dành riêng cho mẹ.

## Cấu trúc thư mục dự án

```text
gameapp/
├── backend/                  # Dịch vụ Backend Node.js TypeScript (Express, MongoDB Atlas, Cloudinary)
│   ├── src/
│   │   ├── config/           # Cấu hình môi trường, Database, Cloudinary
│   │   ├── middleware/       # Auth JWT, Upload Multer, Error Handler
│   │   ├── modules/          # Auth, Users, Receipts, Uploads
│   │   ├── utils/            # Standard Response, Errors, AsyncHandler
│   │   ├── app.ts
│   │   └── server.ts
│   ├── scripts/              # Seed tài khoản developer (seedUser.ts)
│   ├── tests/                # Bộ kiểm thử tự động Jest & Supertest
│   ├── .env.example          # Mẫu biến môi trường backend
│   └── package.json
├── frontend/                 # Ứng dụng di động Flutter (iOS, Android, Web)
│   ├── android/              # Cấu hình Android & Quyền Camera/Bộ nhớ
│   ├── assets/               # Hình ảnh & Logo các trò chơi
│   ├── lib/
│   │   ├── core/             # Network ApiClient, Formatters, EnvConfig
│   │   ├── features/
│   │   │   ├── auth/         # Đăng nhập & Tự động phục hồi phiên JWT
│   │   │   ├── home/         # Màn hình chính chọn module (Sổ ghe & Trò chơi)
│   │   │   ├── boat_receipt/ # Module Sổ ghe (Chụp ảnh, OCR, Quy đổi kg->tấn, Thống kê)
│   │   │   └── [games]/      # Các trò chơi sẵn có (Caro, Đổ mìn, 2048, Sudoku, Cờ tỷ phú)
│   │   └── app.dart
│   ├── test/                 # Kiểm thử Flutter Widget & Unit tests
│   ├── .env.example          # Mẫu cấu hình API Base URL client
│   └── pubspec.yaml
└── README.md
```

---

## 1. Yêu cầu phần mềm
- **Node.js**: v18+ và `npm`
- **Flutter SDK**: v3.12+ (Dart SDK 3.x)
- **MongoDB**: Tài khoản MongoDB Atlas (hoặc MongoDB local)
- **Cloudinary**: Tài khoản Cloudinary để lưu trữ ảnh chụp phiếu ghe

---

## 2. Hướng dẫn khởi chạy Backend (Local)

1. Mở terminal tại thư mục `backend`:
   ```bash
   cd backend
   ```
2. Cài đặt các gói phụ thuộc (nếu chưa cài):
   ```bash
   npm install
   ```
3. Tạo file `.env` từ file `.env.example` và điền thông tin:
   ```env
   NODE_ENV=development
   PORT=4000
   API_PREFIX=/api/v1
   TIMEZONE=Asia/Ho_Chi_Minh

   MONGODB_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/chi_muoi_db?retryWrites=true&w=majority

   JWT_ACCESS_SECRET=your_jwt_access_secret_key_here_32_chars
   JWT_ACCESS_EXPIRES_IN=15m
   JWT_REFRESH_SECRET=your_jwt_refresh_secret_key_here_32_chars
   JWT_REFRESH_EXPIRES_IN=90d

   CLOUDINARY_CLOUD_NAME=your_cloudinary_cloud_name
   CLOUDINARY_API_KEY=your_cloudinary_api_key
   CLOUDINARY_API_SECRET=your_cloudinary_api_secret
   CLOUDINARY_FOLDER=chi-muoi/boat-receipts

   CORS_ORIGINS=http://localhost:3000,http://localhost:5173

   MAX_UPLOAD_SIZE_MB=10
   ALLOWED_IMAGE_TYPES=image/jpeg,image/png,image/webp

   SEED_USER_USERNAME=admin
   SEED_USER_PASSWORD=chimuoi@123
   SEED_USER_DISPLAY_NAME=Mẹ
   ```
4. Khởi tạo tài khoản đăng nhập mặc định cho Mẹ:
   ```bash
   npm run seed:user
   ```
5. Chạy backend local:
   ```bash
   npm run dev
   ```
   Máy chủ backend sẽ lắng nghe tại: `http://localhost:4000/api/v1`

6. Chạy bộ kiểm thử backend:
   ```bash
   npm test
   ```

---

## 3. Hướng dẫn khởi chạy Flutter (Frontend)

1. Mở terminal tại thư mục `frontend`:
   ```bash
   cd frontend
   ```
2. Cấu hình địa chỉ API máy chủ:
   - **Android Emulator**: Sử dụng `http://10.0.2.2:4000/api/v1` (mặc định trong `lib/core/config/env_config.dart`).
   - **Thật trên cùng Wi-Fi**: Thay thành `http://<IP_MAY_TINH>:4000/api/v1` (Ví dụ: `http://192.168.1.15:4000/api/v1`).
3. Lệnh chạy ứng dụng:
   ```bash
   flutter run
   ```
4. Lệnh kiểm thử Flutter:
   ```bash
   flutter analyze
   flutter test
   ```

---

## 4. Danh sách các API Endpoints

### Authentication
- `POST /api/v1/auth/login` - Đăng nhập tài khoản
- `POST /api/v1/auth/refresh` - Làm mới JWT Access Token tự động
- `POST /api/v1/auth/logout` - Đăng xuất & thu hồi phiên làm việc
- `GET  /api/v1/auth/me` - Lấy thông tin tài khoản & cài đặt

### Sổ Ghe (Boat Receipts)
- `POST   /api/v1/receipts` - Lưu phiếu nhập mới (hỗ trợ multipart upload ảnh & idempotency `clientId`)
- `GET    /api/v1/receipts` - Danh sách phiếu (lọc theo date, month, year, boatNumber, from, to, phân trang)
- `GET    /api/v1/receipts/:id` - Xem chi tiết phiếu nhập
- `PATCH  /api/v1/receipts/:id` - Chỉnh sửa thông tin phiếu
- `DELETE /api/v1/receipts/:id` - Xóa phiếu (Soft delete / Hard delete)

### Thống Kê (Statistics)
- `GET /api/v1/receipts/statistics/summary` - Tổng quan hôm nay & tháng hiện tại
- `GET /api/v1/receipts/statistics/daily` - Thống kê chi tiết theo ngày
- `GET /api/v1/receipts/statistics/monthly` - Thống kê chi tiết theo tháng
- `GET /api/v1/receipts/statistics/yearly` - Thống kê chi tiết theo năm
- `GET /api/v1/receipts/statistics/by-boat` - Tổng khối lượng theo số ghe
