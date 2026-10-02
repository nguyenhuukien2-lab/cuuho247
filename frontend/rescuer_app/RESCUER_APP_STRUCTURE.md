# Cấu trúc ban đầu: Cứu Hộ 24/7 Đối tác

Flutter project độc lập tại `frontend/rescuer_app`, tạo bằng Flutter 3.47.5.
Application ID Android và bundle ID iOS: `vn.cuuho247.rescuer`.
Tên hiển thị trên Android, iOS và Web: `Cứu Hộ 24/7 Đối tác`.

```text
lib/
  main.dart
  app/                 Khung ứng dụng
  config/              Cấu hình phía ứng dụng
  core/                Thành phần dùng chung
  models/              Kiểu dữ liệu
  services/             Tích hợp dịch vụ
  repositories/         Truy cập dữ liệu
  widgets/              Widget dùng chung
  screens/
    auth/ onboarding/ home/ requests/ active_job/
    history/ account/
assets/
  images/ icons/ logos/
test/                    Kiểm tra widget ban đầu
config/                  Cấu hình cho project
android/ ios/ web/       Nền tảng Flutter
```

Các thư mục dự kiến chưa dùng được giữ bằng `.gitkeep`. `main.dart` chỉ hiển thị
dòng “Cứu Hộ 24/7 Đối tác — đang chuẩn bị”. Ba thư mục assets đã được khai báo
trong `pubspec.yaml`.

Đây là bộ khung khởi đầu; chưa có màn hình sản phẩm, backend hay nghiệp vụ.
