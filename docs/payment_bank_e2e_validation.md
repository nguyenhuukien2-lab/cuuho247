# GD6C.2 — Bank E2E validation

Cập nhật 11/10/2026. **Real bank E2E: BLOCKED / NOT RUN.** Chưa có provider/credentials thật, auth/signature adapter hoặc DB transport production. Webhook skeleton còn đóng; production auto-paid **DISABLED**. Không deploy, không chuyển tiền, không commit.

## Kết quả kiểm thử có bằng chứng

| Kiểm tra | Kết quả | Phạm vi/bằng chứng |
| --- | --- | --- |
| Migration GD1 → GD6C sau sửa typo | PASS, không workaround | Kế thừa `tools/.work/payment_final_sql_shared.log` và `payment_final_sql_full.log`; shared-only và shared+admin |
| GD6B SQL | 84 assertions PASS | Log SQL cuối nói trên, có chạy lại sau GD6C |
| GD6C SQL | 141 assertions PASS | Log SQL cuối nói trên; normalized matching/security, disposable PGlite |
| Cash regression | PASS | Cash select/confirm/retry; cash RPC definition/ACL không đổi trong log SQL cuối |
| GD4 sau GD6C | 27 assertions PASS | Log SQL cuối nói trên |
| Customer bank/cash/realtime | 133 PASS | Kế thừa `tools/.work/payment_final_targeted.log` |
| Full Flutter customer suite | **601 PASS, 0 failed; exit 0** | Chạy mới `flutter test` trong `frontend/customer_app`; `tools/.work/payment_final_flutter_full.log`, reporter 01:04 |
| Flutter analyze | **0 errors, 4 warnings; exit 1** | Chạy mới `flutter analyze`; `tools/.work/payment_final_flutter_analyze.log` |
| Provider auth/signature thật | BLOCKED / NOT RUN | Chưa có contract, credentials hoặc adapter |
| Native PostgreSQL nhiều connection | NOT RUN | Chưa có bằng chứng chạy thành công; test RAM không thay thế concurrency thật |
| Live Supabase/Auth/JWT/PostgREST/Realtime + bank | **BLOCKED / NOT RUN** | Không deploy hoặc chạy luồng tiền thật |

4 warnings không liên quan nằm ở `lib/screens/login_screen.dart`: `password` 73:11, `response` 86:13, `_NetworkChip` 507:7, `_SocialBtn` 524:7. Giữ nguyên theo yêu cầu. Analyze không phải clean PASS vì exit 1.

Các test Flutter dùng fake source/HTTP/widget fixtures đã có để kiểm logic UI. SQL tests dùng normalized observations nội bộ. **Không tạo fake provider và không gọi các kết quả này là real E2E PASS.** Kết quả 569 test trong tài liệu GD6B/GD6C là mốc lịch sử; mốc full suite mới sau GD6D là 601.

## Kịch bản real E2E cần chạy sau khi gỡ blocker

Các mục dưới đây là kế hoạch, **chưa thực hiện**, và không cho phép deploy/bật production trong tác vụ hiện tại.

1. Xác định provider/contract và môi trường kiểm thử; cấu hình beneficiary thật, server credentials, auth adapter và DB transport đã review.
2. Customer có request completed chuẩn bị payment, chọn bank bằng RPC và đọc QR/reference/amount từ getter; kiểm tra nội dung trên ứng dụng ngân hàng thực tế.
3. Thực hiện giao dịch được phép trong môi trường đã thống nhất; thu provider event/transaction identity và bằng chứng credit theo contract, không lưu secrets/raw credentials trong báo cáo.
4. Xác thực raw bytes/headers và account scope trước normalization; exact-match reference, amount, currency, beneficiary, intent/payment binding và expiry.
5. Xác nhận transaction/receipt/intent/payment/event/audit commit nguyên tử, chỉ một lần paid; kiểm delivery retry, duplicate transaction và concurrent events trên PostgreSQL thật.
6. Kiểm customer đang foreground nhận realtime invalidation rồi `customer_get_payment` trả paid; reconnect/resume cũng khôi phục từ getter. Bank enrichment chậm/lỗi không được chặn paid hợp lệ.
7. Kiểm auth sai, replay/conflict, sai amount/reference/beneficiary/currency, debit/pending event, expired/late transfer, rollback và provider retry. Không trường hợp chưa đủ evidence nào được paid.
8. Kiểm offline/stale, đổi user/request, Cash Awaiting/Paid và cash regression trong cùng môi trường.

Chỉ chuyển real E2E sang PASS khi có execution evidence của luồng thật và các negative cases theo contract. GD6D UI hoàn tất không phải điều kiện đủ để bật production auto-paid.

## Remaining blockers

GD6C.1 provider thật **BLOCKED**: provider/official contract/credentials, authentication/signature, account scope, DB transport/role và acknowledgement/retry mapping còn thiếu. GD6C.2 **BLOCKED** phụ thuộc những mục này cùng môi trường E2E và native concurrency. Chưa xác nhận scan QR bằng bank app, live realtime hoặc vận hành late/unmatched reconciliation.

Xem [provider integration](payment_provider_integration.md) và [trạng thái cuối](customer_payment_final_status.md).
