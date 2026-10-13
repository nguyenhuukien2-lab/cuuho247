# Rescuer App V2 — Thu tiền mặt

## Cách mở

Lịch sử → chuyến hoàn tất → **Xem thanh toán**. Sau khi hoàn tất chuyến,
app hiện có chuyển về Lịch sử; nút thanh toán được đặt trên từng chuyến hoàn tất.
Giữ nguyên năm tab Trang chủ, Đơn mới, Đang xử lý, Lịch sử, Tài khoản.
Nút **Xem chi tiết chuyến** ở màn đã nhận tiền quay về lịch sử và tải chi tiết
đúng assignment.

## Giao diện

Dùng Material 3 và tokens hiện tại: navy `#0B2E4F`, cam `#FD761A`, nền
`#F9F9FF`, surface trắng, typography Plus Jakarta Sans / Inter.
Header navy có nút quay lại, card thanh toán trắng, số tiền lớn 32px,
badge chờ màu vàng nhạt, CTA cam toàn chiều ngang, cao tối thiểu 56px.
Success có biểu tượng check xanh 56px trong nền tròn xanh nhạt.

Màn hình và bottom sheet cuộn được, SafeArea bảo vệ nút cuối, chiều cao nút
tăng theo nội dung. Dòng thông tin chuyển sang dạng dọc khi hẹp hoặc chữ lớn;
không đặt maxLines hoặc cắt bớt số tiền/mã. Tham chiếu 390px, hỗ trợ 320px.

| Trạng thái | Nội dung / thao tác |
| --- | --- |
| Loading | Spinner, đang tải thanh toán; chưa hiển thị số tiền |
| Awaiting cash | Số tiền cần thu, mã chuyến/mã thanh toán thật, Tiền mặt, Chờ xác nhận, lời nhắc nhận đủ tiền |
| Confirm dialog | Bottom sheet hiển thị lại snapshot đã xem, lời xác nhận, cảnh báo, Hủy / Xác nhận đã nhận đủ |
| Submitting | Spinner, khóa xác nhận/Hủy/back, chặn gửi lặp |
| Paid | Đã nhận tiền mặt; số tiền đã nhận và thời gian xác nhận lấy từ backend; Xem chi tiết chuyến |
| Error | Phân biệt timeout, version conflict, giao dịch đã xử lý và lỗi khác; Thử lại |
| Offline | Cảnh báo kết nối bị gián đoạn; Thử lại tải trạng thái |
| Unavailable | Thanh toán chưa sẵn sàng/không có quyền; Thử lại, không có nút xác nhận |
| Bank reference | Với `bank_transfer`, chỉ xem trạng thái và tải lại; thông báo hệ thống đang xác minh khi đang chờ |

## Dữ liệu và xác nhận

- `CashPaymentController` sở hữu `PaymentWatcher` riêng theo user/request;
  không bị thay đổi khi watcher của danh sách lịch sử chuyển chuyến.
- Chỉ mở thao tác xác nhận cho assignment hoàn tất, tài khoản được duyệt,
  payment cash/awaiting_payment, VND, amount dương, dữ liệu đã tải và kết nối
  realtime không stale. Backend vẫn là nơi quyết định quyền và trạng thái.
- Gọi `rescuer_confirm_cash_received` bằng Supabase client của người dùng.
  Amount/version gửi dạng decimal string; không đưa status, actor hoặc thời gian
  từ UI vào RPC. Amount bằng đúng `amount_expected` của snapshot backend.
- UUID operation được giữ cùng payload cho retry khi kết quả chưa xác định.
  **Thử lại** chỉ đọc dữ liệu; thao tác ghi tiếp theo luôn cần xác nhận lại.
- Sau RPC, getter `rescuer_get_job_payment` phải trả `paid` mới hiển thị thành công.
  Lỗi RPC không được diễn giải thành đã thanh toán.
- Snapshot thay đổi khi dialog đang mở sẽ vô hiệu hóa nút xác nhận.
- Logout/xóa scope xóa dữ liệu; phản hồi của user trước không được áp vào user mới.
- Không có input amount, partial, tip, giảm giá, status override, QR hoặc xác nhận bank.
  Mã chuyến, mã thanh toán, amount và paid time không sinh giả/fallback từ quote
  hoặc thời gian máy. Thiếu dữ liệu hiển thị thông báo chưa có.

## Kiểm thử và giới hạn

`frontend/rescuer_app/test/cash_payment_test.dart` kiểm tra điều kiện xác nhận,
chống double tap, payload bigint, idempotency sau mất phản hồi, refetch sau commit,
version conflict, trạng thái không còn hợp lệ, logout, loading, lỗi/offline,
bank chỉ xem, dữ liệu thiếu và layout 320/390px ở text scale 1/2.
Dữ liệu mẫu chỉ nằm trong test fixture.

Kết quả kiểm tra ngày 2026-10-11:

- `flutter test --no-pub test/cash_payment_test.dart test/payment_realtime_test.dart test/job_finance_test.dart --timeout 30s`: **62/62 đạt**.
- `flutter analyze --no-pub` cho controller, màn thanh toán, payment service,
  history panel và test mới: **No issues found**.
- `git diff --check`: không có lỗi whitespace.

Các test dùng fake source và HTTP mock; không thực hiện giao dịch thật.
Luồng vận hành cần các migration payment hiện có được áp dụng trên backend đích
và quyền realtime phù hợp. Thay đổi này không triển khai migration hoặc backend.
