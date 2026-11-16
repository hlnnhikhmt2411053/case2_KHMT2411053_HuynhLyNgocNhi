# CASE STUDY 2 – TASK MANAGER

## ỨNG DỤNG QUẢN LÝ VÀ GIAO CÔNG VIỆC NHÓM

**MSSV:** KHMT2411053  
**Họ và tên:** Huỳnh Lý Ngọc Nhi  
**Repository:** `case2_KHMT2411053_HuynhLyNgocNhi`  
**Công nghệ:** Flutter, Node.js, Express REST API, MongoDB, Nodemailer (SMTP)

**GitHub:** https://github.com/hlnnhikhmt2411053/case2_KHMT2411053_HuynhLyNgocNhi

## 1. Mục tiêu và phạm vi

Phát triển ứng dụng giúp người dùng quản lý công việc cá nhân và công việc nhóm; giao việc cho một hoặc nhiều người, chọn người phụ trách chính, chia sẻ quyền xem/chỉnh sửa, theo dõi trạng thái và nhận thông báo trong ứng dụng hoặc qua email. Backend kiểm tra quyền truy cập của người dùng, không chỉ dựa vào việc ẩn nút trên giao diện Flutter.

## 2. Chức năng theo đề Case Study 2

### A. Quản lý tài khoản và xác thực

- Đăng ký bằng họ tên, email, mật khẩu; đăng nhập, đăng xuất.
- Xem và cập nhật thông tin cá nhân; đổi mật khẩu.
- Xác thực API bằng JWT; mật khẩu được lưu dưới dạng băm, không lưu mật khẩu rõ.

### B. Quản lý công việc

- Xem danh sách công việc liên quan và chi tiết công việc.
- Tạo, cập nhật, xóa công việc (CRUD).
- Cập nhật trạng thái: `todo`, `in_progress`, `completed`.
- Mức ưu tiên: `low`, `medium`, `high`; ngày bắt đầu và hạn hoàn thành.
- Tìm kiếm theo tên; lọc theo trạng thái, ưu tiên, người phụ trách/vai trò; sắp xếp theo thời hạn, ưu tiên hoặc thời gian tạo.

### C. Giao việc và chia sẻ

- Giao công việc cho một hoặc nhiều tài khoản qua email; chỉ định người phụ trách chính.
- Xem danh sách người được giao và người được chia sẻ.
- Chia sẻ theo quyền `viewer` (chỉ xem) và `editor` (có thể chỉnh sửa); cập nhật hoặc thu hồi quyền.
- Kiểm tra phân quyền tại backend: `viewer` không được sửa, `editor` không mặc nhiên được xóa hoặc quản lý chia sẻ.
- Theo dõi trạng thái công việc và vai trò người tạo, người phụ trách, người được chia sẻ.

### D. Thông báo qua email và trong ứng dụng

- Thông báo khi được giao việc, chia sẻ công việc hoặc cập nhật công việc.
- Xem thông báo, số thông báo chưa đọc và đánh dấu đã đọc; mở công việc liên quan khi được hỗ trợ.
- Gửi email từ backend qua SMTP khi giao/chia sẻ công việc và các sự kiện cập nhật được hỗ trợ.
- Lưu lịch sử gửi email vào collection `email_logs`, với trạng thái `pending`, `sent` hoặc `failed`.
- Nhắc trước hạn là tính năng cấu hình tùy chọn (`ENABLE_REMINDERS`); cần thử riêng trước khi bật.

### E. Thống kê và tiện ích

- Thống kê số công việc theo trạng thái, được giao và đang phụ trách.
- Hiển thị công việc sắp đến hạn và quá hạn.
- Xem lịch sử hoạt động công việc (ví dụ: tạo, giao, chia sẻ, đổi trạng thái).
- Hiển thị trạng thái đang tải, thông báo lỗi và phản hồi kết quả thao tác.

## 3. Phân bổ thực hiện theo 3 buổi

| Buổi | Nội dung |
| --- | --- |
| **Buổi 1** | Xác thực, đăng ký/đăng nhập, lấy danh sách và chi tiết công việc từ MongoDB. |
| **Buổi 2** | CRUD, giao việc nhiều người, chia sẻ `viewer/editor`, kiểm tra phân quyền backend. |
| **Buổi 3** | Thông báo trong ứng dụng, SMTP và lịch sử email; tìm kiếm, lọc, thống kê, lịch sử hoạt động và kiểm thử tích hợp. |

## 4. Cấu trúc dự án

```text
case2_KHMT2411053_HuynhLyNgocNhi/
├── api/                  # Backend Node.js + Express
│   ├── src/
│   │   ├── models/
│   │   ├── routes/
│   │   ├── middleware/
│   │   ├── services/
│   │   ├── utils/
│   │   └── server.js
│   ├── test/
│   ├── .env.example
│   └── package.json
├── TaskManager/          # Frontend Flutter
│   ├── lib/
│   │   ├── screens/
│   │   ├── services/
│   │   └── main.dart
│   └── pubspec.yaml
└── README.md
```

**Các collection MongoDB:** `users`, `tasks`, `task_shares`, `notifications`, `email_logs`, `task_activities`.

## 5. Hướng dẫn cài đặt và chạy

### 5.1. Yêu cầu

- Node.js và npm; Flutter SDK; Android Studio/Android Emulator.
- MongoDB đang chạy trên máy hoặc kết nối MongoDB hợp lệ.

### 5.2. Backend (`api`)

Tạo `api/.env` từ `api/.env.example`, điền các thông số cần thiết; **không đưa `.env` lên GitHub**.

```powershell
cd api
npm.cmd install
npm.cmd test
npm.cmd start
```

API mặc định: `http://localhost:3000/api`.

Các biến môi trường quan trọng:

```env
PORT=3000
MONGODB_URI=mongodb://127.0.0.1:27017/task_manager_case2
JWT_SECRET=THAY_BANG_CHUOI_NGAU_NHIEN_TOI_THIEU_32_KY_TU
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=EMAIL_GUI_THU
SMTP_PASS=APP_PASSWORD_CUA_TAI_KHOAN_GUI_THU
SMTP_FROM=EMAIL_GUI_THU
ENABLE_REMINDERS=false
```

Để gửi email Gmail, tài khoản gửi phải hỗ trợ SMTP và có App Password hợp lệ. Không dùng mật khẩu Gmail thông thường hoặc đưa thông tin bí mật vào README.

### 5.3. Flutter (`TaskManager`)

Mở một Terminal khác:

```powershell
cd TaskManager
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Thay `emulator-5554` bằng ID thiết bị thực tế nếu khác. Android Emulator gọi backend của máy Windows qua `http://10.0.2.2:3000/api`.

## 6. Kiểm thử chức năng

1. **Tài khoản:** Tạo hai tài khoản thử nghiệm; đăng nhập, đăng xuất, cập nhật hồ sơ và kiểm tra đổi mật khẩu.
2. **Công việc:** Thêm, sửa, xóa, xem chi tiết; chuyển trạng thái; kiểm tra hạn và ưu tiên.
3. **Giao việc:** Giao cho tài khoản khác, chọn người phụ trách chính; kiểm tra danh sách và thông báo người nhận.
4. **Chia sẻ:** Thử quyền `viewer` và `editor` với tài khoản không đồng thời được giao công việc; xác nhận quyền bằng cả giao diện và backend; thử thu hồi.
5. **Thông báo/email:** Đánh dấu thông báo đã đọc; kiểm tra Nhật ký email `sent/failed`, đồng thời xác nhận thư đã đến hộp thư nhận.
6. **Tìm kiếm/thống kê:** Kiểm tra lọc/sắp xếp, số lượng công việc và lịch sử hoạt động.
7. **Trường hợp lỗi:** Kiểm tra thông báo khi backend ngừng hoạt động hoặc phiên đăng nhập hết hạn.

Các tính năng phải được kiểm thử trên máy chạy thật trước khi xác nhận hoàn tất bài nộp; kiểm tra cú pháp hoặc `flutter analyze` không thay thế kiểm thử nghiệp vụ.

## 7. GitHub và yêu cầu nộp bài

- Tên repository: `case2_KHMT2411053_HuynhLyNgocNhi`.
- Các nhánh đã sử dụng: `main`, `feature/auth`, `feature/tasks`, `feature/case2-integration`.
- Nhóm chức năng A–E được yêu cầu có nhánh riêng; cần hoàn thiện và kiểm tra các nhánh `feature/sharing`, `feature/notifications`, `feature/statistics` theo hướng dẫn giảng viên trước khi chốt bài.
- Commit và push sau khi hoàn tất từng chức năng. Bản tích hợp hiện tại lưu tại nhánh `feature/case2-integration`.
- Không commit `api/.env`, mật khẩu SMTP, JWT secret, thư mục `node_modules`, `.dart_tool` hoặc `build`.

## 8. Ghi chú bảo mật

Dữ liệu thật và bí mật cấu hình chỉ được lưu trong `.env` trên máy phát triển. Khi sử dụng tài khoản thử nghiệm, không đưa mật khẩu hay App Password vào báo cáo, ảnh minh họa hoặc lịch sử Git.
