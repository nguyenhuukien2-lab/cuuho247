# GD6D — Customer bank UI final implementation

Cập nhật 11/10/2026. **GD6D complete trong phạm vi implementation UI và kiểm thử Flutter local.** Bank Verifying, Bank Paid, expired/error/offline đã implement. **GD6C.1 provider thật BLOCKED; GD6C.2 real E2E BLOCKED; production auto-paid DISABLED.** Không deploy, không commit.

## Trạng thái hiển thị

| Trạng thái | Hành vi đã implement |
| --- | --- |
| Pending, chưa chọn phương thức | Bank chỉ khả dụng theo backend capability và dữ liệu fresh; giữ command/idempotency guards |
| Bank awaiting + intent ready | QR render từ payload backend; amount, beneficiary, reference từ snapshot đúng payment; copy có xử lý thành công/lỗi |
| Bank verifying | `BankPaymentVerifyingSection`: chỉ xuất hiện khi authoritative payment getter trả `bank_transfer/verifying`; không QR, không customer confirm-paid |
| Bank paid | `BankPaymentPaidSection`: số tiền đã nhận từ `amountReceived`, thời gian từ `paidAt`; thiếu dữ liệu thì báo thiếu, không suy từ amount expected/giờ thiết bị |
| Expired | Ẩn QR/copy, cho làm mới; countdown chỉ refetch, không tự đặt verifying/paid hoặc tạo intent mới |
| Failed/cancelled/refunded | `BankPaymentOutcomeSection` phân biệt trạng thái nghiệp vụ từ backend, không dùng lỗi mạng để suy ra failed |
| Loading/error/offline/stale | Thông báo trạng thái và retry; QR không dùng khi stale/lỗi/loading; paid đã đọc hợp lệ được giữ cùng cảnh báo stale khi refresh lỗi |
| Cash Awaiting/Cash Paid | Giữ nhánh cash riêng, không dùng bank receipt hoặc thay quyền xác nhận cash |

Bank Paid có điều hướng tới chi tiết đơn cứu hộ. Bank receipt enrichment chỉ hiển thị khi DTO khớp payment/request/code/amount/currency/method/status/version; reference là mã intent/payment, không tự gọi là provider transaction ID.

## Authority và realtime

`PaymentScreen` chọn section theo `PaymentWatcher.payment`, lấy từ `customer_get_payment`. Subscription `public.payments` chỉ invalidation; raw realtime `status=paid` không được dùng để xác nhận thanh toán. Watcher công bố snapshot payment hợp lệ trước khi đợi optional bank getter, nên bank getter chậm/lỗi không chặn màn Paid.

Getter response cũ hơn hoặc equal version không ghi đè snapshot đã chấp nhận. Guard auth/request/generation loại response đến muộn và dọn dữ liệu khi đổi user/request. Resume/reconnect/refresh đọc lại authoritative getter; không có timer, nút “đã chuyển khoản”, QR hoặc callback local nào tự tạo paid/verifying.

GD6C engine hiện chuyển `awaiting_payment` → `paid` nguyên tử khi có evidence hợp lệ, không cần intermediate verifying. UI vẫn hỗ trợ verifying nếu getter thực sự trả trạng thái đó; không giả định provider thật đã tạo ra trạng thái này.

## Source implementation đã có khi tiếp tục

- `frontend/customer_app/lib/widgets/bank_payment_ui.dart`: QR, verifying, paid, business outcomes và safe receipt fields.
- `frontend/customer_app/lib/screens/payment_screen.dart`: chọn section, stale/error/retry và điều hướng chi tiết.
- `frontend/customer_app/lib/app/payment_watcher.dart`: authoritative getter, invalidation và optional bank enrichment.
- `frontend/customer_app/test/payment_bank_test.dart`: controller/HTTP/widget và GD6D regression cases.

Đây là source đã có từ công việc trước; lượt tiếp tục này chạy kiểm tra và bổ sung 4 docs, không sửa lại implementation.

## Validation

- Bank/cash/realtime targeted: **133 PASS**, log kế thừa `tools/.work/payment_final_targeted.log`.
- Full suite chạy mới bằng `flutter test` tại `frontend/customer_app`: **601 PASS, 0 failed, exit 0**, reporter 01:04; log `tools/.work/payment_final_flutter_full.log`.
- `flutter analyze`: **0 errors, 4 warnings cũ, exit 1**; log `tools/.work/payment_final_flutter_analyze.log`. Giữ nguyên `login_screen.dart` tại 73:11, 86:13, 507:7, 524:7.
- Coverage hiện có: backend-only verifying/paid, missing received amount/time, optional bank getter failure/delay, resume, offline recovery, auth/request switch, timer/refresh không manufacture paid, distinct terminal outcomes; width 320/390/480 với text scale 1 và 2.
- Cash regression SQL kế thừa PASS; GD6B **84**, GD6C **141**, GD4 sau GD6C **27 assertions PASS**, chain nguyên source không workaround.

Widget/layout tests không phải screenshot golden comparison hoặc live bank E2E. UI đã hoàn tất nhưng provider adapter/authentication/signature, credentials, native concurrency và real E2E vẫn chưa hoàn tất. Webhook skeleton tiếp tục trả 503 cho POST hợp lệ.

Xem [E2E validation](payment_bank_e2e_validation.md), [provider integration](payment_provider_integration.md), [trạng thái cuối](customer_payment_final_status.md).
