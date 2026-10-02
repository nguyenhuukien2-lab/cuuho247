# Cấu trúc ứng dụng: Cứu Hộ 24/7 Đối tác

Ứng dụng Flutter độc lập tại `frontend/rescuer_app`, với application ID Android
`vn.cuuho247.rescuer` và tên hiển thị `Cứu Hộ 24/7 Đối tác`.

```text
lib/
  app/                 Theme, trạng thái UI cục bộ, app shell
  core/                Tiện ích dùng chung
  models/              Kiểu dữ liệu trạng thái và bản xem trước đơn
  screens/
    auth/              Đăng nhập, quên mật khẩu
    onboarding/        Hồ sơ, giấy tờ, phương tiện, dịch vụ
    home/              Bảng điều khiển online/offline
    requests/          Danh sách, bản đồ và nhận đơn
    active_job/        Theo dõi, báo giá, xác nhận hoàn tất
    history/           Danh sách và chi tiết an toàn
    account/           Tài khoản, quyền thiết bị và kết nối
  widgets/             Component và trạng thái giao diện dùng chung
assets/                images/, icons/, logos/
test/                  Widget tests cho shell và quyền riêng tư đơn
```

Giao diện hiện dùng trạng thái cục bộ để kiểm tra điều hướng. Backend và dữ liệu
đơn chưa được kết nối; danh sách đơn ở trạng thái chưa khả dụng, nên không có
thông tin vận hành mẫu hoặc nhận đơn giả. Quyền GPS/thông báo chưa được yêu cầu
từ hệ điều hành. Bản đồ là minh họa khu vực gần đúng, không dùng nhà cung cấp bản đồ.

## Thiết kế backend chưa triển khai

Thiết kế schema, RPC/API, RLS, claim và quyền riêng tư được mô tả trong
[rescuer_backend_plan.md](../../docs/backend/rescuer_backend_plan.md). Chưa có
migration được áp lên Supabase và ứng dụng không chứa Supabase SDK, URL, khóa,
service role hoặc lời gọi backend.
