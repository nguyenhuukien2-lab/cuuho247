# GD6C.1 — Tích hợp provider ngân hàng

Cập nhật 11/10/2026. **GD6C.1 provider thật: BLOCKED. Production auto-paid: DISABLED.**
Chưa xác định provider, contract hoặc credentials thật. Không deploy, không commit.

## Implementation hiện có

- Engine verification provider-neutral ở `backend/supabase/migrations/202610110003_payment_bank_verification.sql`: normalized transaction, matching, idempotency, atomic settlement, event và audit.
- `backend/supabase/functions/bank-webhook/adapter.ts` định nghĩa `BankProviderAdapter` và `BankVerificationStore`; `installedAdapter = null`. Chưa có adapter hoặc DB transport production.
- `index.ts` và `handler.ts` là webhook skeleton. POST JSON hợp lệ trong giới hạn trả **503 `verification_unavailable`**; method khác trả 405, body quá giới hạn trả 413, media type không hỗ trợ trả 415. Giới hạn body 64 KiB, thời gian đọc 5 giây.
- **Chưa có authentication/signature verification của provider thật.** Không có đường ingress từ skeleton tới processor, không có toggle môi trường để bật adapter hiện tại.
- `verification_enabled` mặc định false. Processor/audit private không được cấp EXECUTE cho PUBLIC, anon, authenticated hoặc service_role. Có service-role key đơn thuần chưa đủ để gọi processor.
- VietQR là chỉ dẫn chuyển khoản; QR, countdown, nút refresh và dữ liệu realtime thô không chứng minh tiền đã về.

`authentication_verified` trong normalized model là kết quả mà trusted server adapter phải tạo sau xác thực; không nhận cờ này từ request như bằng chứng. SHA256 raw body phục vụ integrity/dedupe, không thay thế auth/signature. Không tự chọn provider hoặc dựng HMAC giả.

## Blockers để hoàn tất GD6C.1

| Còn thiếu | Bằng chứng/implementation cần có |
| --- | --- |
| Provider và contract | Tên provider, API version, tài liệu chính thức, official payload samples, định nghĩa final credit/settled event |
| Auth và credentials | Cơ chế signature/token/mTLS đúng contract; secret/key/certificate thật ở server, rotation và replay policy nếu được hỗ trợ |
| Scope và beneficiary | Merchant/account/environment, BIN/account nhận tiền đã xác minh, currency và đơn vị amount |
| Mapping transaction | Phạm vi uniqueness của delivery/event/transaction ID, timestamp/timezone, full transfer reference, retry và acknowledgement contract |
| Query API nếu cần | Credentials và bước query theo contract thực tế; chưa giả định provider bắt buộc có API này |
| DB transport | Transport server và role/grants tối thiểu đã review cho processor/audit; không expose private schema qua PostgREST |
| Validation và vận hành | Official auth fixtures, failure/replay cases, native concurrency, staging E2E, monitoring và quy trình unmatched/late transfer |

Không đặt tên secret hoặc ghi credentials mẫu khi chưa biết contract. Không đưa secrets vào Flutter, public DTO, SQL seed hoặc log. Kết luận này dựa trên source và trạng thái bàn giao local; không truy cập hay xác nhận cấu hình secrets production.

## Bằng chứng local và giới hạn

Log kế thừa `tools/.work/payment_final_sql_shared.log` và `tools/.work/payment_final_sql_full.log` xác nhận chain migration nguyên source sau sửa `thencc` → `then`, **không workaround**: GD6B **84 assertions PASS**, GD6C **141 assertions PASS**, cash regression PASS và GD4 sau GD6C **27 assertions PASS**. Không dùng các log `gd6c_sql_*` cũ có workaround để kết luận trạng thái cuối.

Đây là SQL regression trên disposable PGlite với normalized observations nội bộ; không phải callback/provider thật. Không chạy lại SQL trong lượt hoàn thiện docs. Full Flutter chạy mới: **601 PASS**; analyze: **0 errors, 4 warnings login cũ, exit 1**. UI/test pass không gỡ blocker provider.

GD6D UI đã implement; **GD6C.2 real E2E vẫn BLOCKED**. Điều kiện mở production chưa được đáp ứng; production auto-paid giữ **DISABLED**. Không triển khai hoặc bật cấu hình trong công việc này.

Chi tiết: [Real E2E validation](payment_bank_e2e_validation.md), [GD6D UI](customer_bank_ui_final_implementation.md), [Trạng thái cuối](customer_payment_final_status.md).
