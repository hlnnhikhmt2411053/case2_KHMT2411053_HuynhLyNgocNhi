# CASE STUDY 2 - TASK MANAGER (BUỔI 1)

**MSSV:** KHMT2411053  
**Họ và tên:** Huỳnh Lý Ngọc Nhi  
**Repository yêu cầu:** `case2_KHMT2411053_HuynhLyNgocNhi`

## Đúng phạm vi Buổi 1 theo đề
- Đăng ký / Đăng nhập Flutter ↔ Node.js/Express ↔ MongoDB.
- Xác thực bằng JWT, mật khẩu băm bcrypt.
- GET danh sách công việc và GET chi tiết công việc, chỉ trả về công việc của người dùng.
- Khi đăng ký, backend tự tạo **1 công việc mẫu** cho tài khoản mới để thử GET.
- CRUD / giao việc / chia sẻ / email để Buổi 2 và 3.

## 1. Điều kiện cần
- Flutter SDK + Android Studio, Node.js, MongoDB Community Server đang chạy (`mongodb://127.0.0.1:27017`).
- Flutter Android emulator (Pixel 6), Internet cho lần tải thư viện đầu.

## 2. Tạo đầy đủ platform Flutter
Thư mục `TaskManager` trong ZIP chứa nguồn Flutter nhưng chưa có các platform do môi trường tạo gói không có Flutter SDK. Chạy trong thư mục **TaskManager**:

```powershell
flutter create --project-name task_manager --platforms android .
flutter pub get
```

Lệnh tạo platform Android mà vẫn giữ các file nguồn Dart (nếu hiện thông báo file trùng, sao lưu file trước).

## 3. Cho phép kết nối API HTTP cục bộ (Android emulator)
Trong `TaskManager/android/app/src/main/AndroidManifest.xml`:
- Thêm `<uses-permission android:name="android.permission.INTERNET" />` ngay dưới `<manifest ...>`.
- Trong thẻ `<application>` thêm `android:usesCleartextTraffic="true"` (chỉ dùng khi phát triển local).

Ứng dụng dùng `http://10.0.2.2:3000/api` trên Android emulator. `localhost` ở emulator **không phải** máy tính.

## 4. Chạy Node.js và MongoDB
Mở Terminal thứ nhất:

```powershell
cd api
npm install
Copy-Item .env.example .env
```

Mở `api/.env`, thay JWT_SECRET bằng chuỗi ngẫu nhiên dài ít nhất 32 ký tự. Đảm bảo MongoDB chạy, rồi:

```powershell
npm start
```

Kiểm tra trên máy tính: http://localhost:3000/ trả về `Task Manager API đang hoạt động`.

## 5. Chạy Flutter
Mở Terminal thứ hai:

```powershell
cd TaskManager
flutter pub get
flutter devices
flutter run -d emulator-5554
```

Thay `emulator-5554` bằng thiết bị Android hiện có. Đăng ký với email hợp lệ và mật khẩu >= 8 ký tự; sau đó xem danh sách có một công việc mẫu; nhấn vào để xem chi tiết. Đăng xuất và đăng nhập lại để kiểm tra.

## 6. GitHub (không thể tự tạo repository trên tài khoản của bạn từ bản ZIP)
1. Tạo repository mới trên GitHub tên `case2_KHMT2411053_HuynhLyNgocNhi` (không tick README vì đã có).
2. Trong thư mục gốc Case Study 2 chạy:

```powershell
git init
git add .
git commit -m "Initial commit - Case Study 2"
git branch -M main
git remote add origin https://github.com/<USERNAME>/case2_KHMT2411053_HuynhLyNgocNhi.git
git push -u origin main
```

3. Với từng chức năng lớn tạo nhánh riêng (ví dụ `feature/auth`, `feature/tasks`) rồi commit/push **sau mỗi chức năng hoàn thành**. Đừng commit `.env`, `node_modules`, thư mục build.

## Lưu ý
- Mã nguồn là bản dựng để triển khai Buổi 1, chưa chạy thử trên Android Studio/MongoDB của bạn.
- Dùng MongoDB theo đúng tài liệu, không thay bằng SQLite của Case Study 1.
- Nếu lệnh `flutter create` thay `pubspec.yaml`, chạy lại `flutter pub add http flutter_secure_storage`.
