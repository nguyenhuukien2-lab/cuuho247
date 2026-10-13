# GD6C.1 — Tích hợp SePay webhook

Cập nhật 13/10/2026. Adapter và ingress SePay đã được triển khai local; **chưa
deploy và production auto-paid vẫn DISABLED** cho tới khi hoàn tất cấu hình và
staging E2E.

## Luồng bảo mật

Edge Function đọc nguyên byte body trước khi parse JSON, lấy
`X-SePay-Signature` và `X-SePay-Timestamp`, rồi xác minh:

```text
HMAC-SHA256(SEPAY_WEBHOOK_SECRET, "{timestamp}.{raw_body}")
```

Signature phải có dạng `sha256=<64 ký tự hex>`, được so sánh constant-time và
timestamp chỉ được lệch tối đa 5 phút. Thiếu secret/signature/timestamp,
signature sai hoặc hết hạn trả 401 trước khi ghi transaction hay cập nhật
payment. JSON chỉ được parse sau khi HMAC hợp lệ.

Payload phải có SePay transaction `id`, `transferAmount`, `content`,
`accountNumber`, `transactionDate`, `gateway` và `transferType=in`.
`code` được dùng làm transfer reference nếu có; nếu không, chỉ dùng toàn bộ
`content` khi vừa giới hạn model. Không trim, lowercase, tách substring hoặc
fuzzy-match reference.

Normalized transaction được chuyển tới
`private.process_verified_bank_transaction(jsonb)`. Riêng Test Mode có bước
mapping beneficiary server-side được mô tả bên dưới; private processor hiện có
tiếp tục chịu trách nhiệm duy nhất cho:

- dedupe provider transaction/event và webhook replay;
- exact amount, exact reference, VND và beneficiary;
- payment state hợp lệ;
- transaction record, audit và atomic settlement.

Customer không thể mark paid; rescuer không thể mark bank paid; admin không thể
mark paid. Không cấp quyền API mới cho PUBLIC, anon, authenticated hoặc
service_role, không expose `private.bank_transactions` qua PostgREST, và không
đưa service-role key vào frontend.

## Mapping SePay

| SePay | Normalized model |
| --- | --- |
| `id` | `provider_transaction_id` |
| `transaction:<id>` | `provider_event_id` ổn định cho retry |
| `transferAmount` | integer-string `amount` |
| `code`, fallback exact `content` | `transfer_reference` |
| `transactionDate` (giờ Việt Nam) | ISO-8601 `occurred_at` với `+07:00` |
| `accountNumber` | `beneficiary_account_number` |
| server config | provider scope và beneficiary BIN |

### Beneficiary mapping chỉ dành cho SePay Test Mode

Mapping chỉ được kích hoạt khi `SEPAY_PROVIDER_SCOPE` bằng chính xác
`sepay_test`. Sau khi HMAC hợp lệ, `accountNumber` trong webhook phải bằng chính
xác Function Secret `SEPAY_TEST_ACCOUNT_NUMBER`. Transport sau đó đọc
`bank_bin` và `account_number` từ `private.payment_bank_config` ở phía server và
đưa beneficiary đã map vào GD6C. Không lấy beneficiary từ frontend, không
hardcode account, không log test account hoặc account production.

Thiếu `SEPAY_TEST_ACCOUNT_NUMBER`, account webhook không khớp, config không bật,
scope/provider config không khớp, hoặc `require_beneficiary` không còn `true` đều
fail closed trước processor. Khi scope khác `sepay_test`, transport không đọc
config để map và giữ nguyên `accountNumber` từ webhook; exact beneficiary check
cho Live Mode vì vậy không thay đổi.

Mapping này **không chứng minh beneficiary Live Mode**. Trước production phải
chạy E2E Live Mode bằng tài khoản thật và xác nhận webhook account thật vượt qua
exact beneficiary check. Không đổi production bank account và không đặt
`require_beneficiary=false` để phục vụ Test Mode.

Một webhook đã xác thực nhưng mismatch là kết quả terminal đã được private
processor audit, nên trả 200 `{"success":true}` để tránh retry vô hạn. Duplicate
hoặc replay cũng trả 200 nhưng không settle lần hai. Payload sai trả 400; lỗi
processor/DB hoặc receipt chưa hoàn tất trả 500 để SePay retry. Response không
leak stack trace hoặc SQL internals.

Không log secret, signature, headers hoặc raw sensitive payload trong production.
Auth-failure audit là best effort và chỉ lưu SHA-256 của raw body.

## Production setup

Tạo secret mạnh riêng cho webhook và cấu hình cùng secret trong SePay:

```powershell
supabase secrets set SEPAY_WEBHOOK_SECRET="..."
supabase secrets set SEPAY_PROVIDER_SCOPE="production:merchant-id"
supabase secrets set SEPAY_BENEFICIARY_BANK_BIN="970xxx"
supabase secrets set BANK_DATABASE_URL="<SERVER_ONLY_POSTGRES_CONNECTION_URL>"
supabase functions deploy bank-webhook --no-verify-jwt
```

Chỉ cho E2E SePay Test Mode, đặt scope và secret test riêng:

```powershell
supabase secrets set SEPAY_PROVIDER_SCOPE="sepay_test"
supabase secrets set SEPAY_TEST_ACCOUNT_NUMBER="<SEPAY_TEST_MODE_ACCOUNT>"
```

`SEPAY_TEST_ACCOUNT_NUMBER` là secret mới duy nhất cho mapping và chỉ chứa account
Test Mode do SePay cấp. Không đặt account production vào secret này. Khi chuyển
sang Live Mode, đổi `SEPAY_PROVIDER_SCOPE` sang scope production; mapping bị tắt
tuyệt đối dù test secret còn tồn tại hay không.

`BANK_DATABASE_URL` là PostgreSQL connection URL do operator cấu hình trong
Supabase Function Secrets. Role kết nối phải có quyền gọi private processor.
Không đưa URL chứa credentials vào frontend, source hoặc log. Transport dùng
một kết nối PostgreSQL lazy để gọi private owner function; không dùng
service-role/PostgREST.

`--no-verify-jwt` chỉ tắt Supabase JWT gateway vì SePay không gửi JWT; HMAC SePay
bắt buộc vẫn fail-closed trong function. Trước khi bật
`verification_enabled`, operator phải:

1. Xác nhận scope, beneficiary BIN/account và currency khớp tài khoản SePay.
2. Cấu hình `private.payment_bank_config` bằng owner-controlled migration/runbook,
   không sửa migration production đã chạy.
3. Chỉ đăng ký event chuyển tiền vào và bật HMAC webhook ở SePay.
4. Chạy staging E2E gồm valid, invalid signature, mismatch, duplicate và replay.
5. Thiết lập monitoring chỉ dùng metadata/digest không nhạy cảm.

## Validation

```text
node --test backend/supabase/functions/bank-webhook/*_test.ts
deno check backend/supabase/functions/bank-webhook/index.ts
```

SQL regression của payment verification vẫn là nguồn xác nhận authoritative cho
exact matching, ACL, idempotency, concurrency và atomic settlement. Test handler
dùng fixture local, không phải live bank call.

Tài liệu chính thức: [SePay webhook authentication](https://developer.sepay.vn/vi/sepay-webhooks/xac-thuc),
[SePay webhook payload](https://developer.sepay.vn/vi/sepay-webhooks/tich-hop-webhook),
[Supabase direct Postgres from Edge Functions](https://supabase.com/docs/guides/functions/connect-to-postgres).

Không deploy hoặc commit trong thay đổi này.
