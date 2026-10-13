# Kết quả triển khai customer bank intent regeneration

Ngày kiểm tra: 2026-10-13

## Kết quả

Đã triển khai flow tạo QR/bank intent mới cho customer khi intent hiện tại đã hết hạn. Không sửa migration cũ, không cho frontend xác nhận đã thanh toán, không deploy và không commit.

Migration mới:

`backend/supabase/migrations/202610130002_customer_bank_intent_regeneration.sql`

RPC mới:

```sql
public.customer_regenerate_bank_transfer(
  p_request_id uuid,
  p_payment_id uuid,
  p_expected_version bigint,
  p_expected_intent_id uuid,
  p_expected_intent_version bigint,
  p_operation_id uuid
)
```

## Hành vi trước và sau thay đổi

Trước thay đổi, `customer_select_bank_transfer` chỉ nhận payment `pending` với `method is null`. Gọi lại RPC này khi payment đã là `bank_transfer/awaiting_payment` bị `PAYMENT_NOT_ELIGIBLE`; intent `ready` đã quá TTL vẫn chiếm unique active slot. Getter chỉ trả trạng thái hiệu lực là `expired`, còn nút UI “Làm mới” chỉ refetch dữ liệu. Vì vậy customer không thể tạo mã mới.

Sau migration, customer owner có thể gọi RPC regeneration chỉ khi:

- request/payment binding đúng và request đã completed;
- payment chính xác là `bank_transfer/awaiting_payment`;
- payment version và current/latest intent ID/version khớp tuyệt đối;
- intent hiện tại vẫn có trạng thái lưu trữ `ready` nhưng đã hết hạn theo `clock_timestamp()` của server;
- bank config vẫn enabled và không đổi trong lúc lấy lock;
- không có intent active khác;
- không có inbound credit transaction dùng đúng transfer content cũ.

RPC không cho gọi trước hạn, không nhận amount/reference/beneficiary/expiry từ client, và không hỗ trợ cash/verifying/paid/refunded/failed/cancelled. Nếu đã có inbound transaction cho mã cũ, RPC trả `BANK_TRANSFER_RECONCILIATION_REQUIRED` và không tạo mã mới.

## Transaction, idempotency và race safety

Trong một transaction, RPC:

1. Lấy advisory lock cho actor/operation ID và bank-intent operation ID.
2. Lấy cùng provider/scope advisory lock với trusted webhook processor.
3. Lock theo thứ tự request -> assignment -> payment -> config -> latest intent.
4. Kiểm tra receipt replay/conflict và toàn bộ eligibility/version guard.
5. Chuyển intent cũ `ready -> expired`, tăng version; không sửa `expires_at`, reference hay snapshot cũ.
6. Tạo intent mới với UUID/reference mới và TTL server mới.
7. Tạo QR snapshot immutable với transfer content mới, rồi chuyển intent mới `created -> ready`.
8. Chỉ tăng payment version; giữ `bank_transfer/awaiting_payment`, không ghi paid/verifying.
9. Ghi audit transition, event `bank_qr_created` có `metadata.regenerated=true`, và idempotency receipt.

Replay cùng operation ID và cùng payload trả `changed=false` an toàn. Cùng operation ID nhưng payload khác trả `IDEMPOTENCY_CONFLICT`. Lỗi giữa transaction rollback old intent, new intent/snapshot, payment version, event và receipt cùng nhau.

Late webhook của transfer content cũ chỉ match snapshot/intent cũ; không được redirect sang intent mới. Chỉ `private.process_verified_bank_transaction(jsonb)` với trusted normalized bank evidence có thể settle payment.

## Guards và ACL thay đổi

- `private.payment_bank_intent_guard`: giữ nguyên GD6C settlement transitions; cho phép owner tạo `created -> ready` trong nhánh regeneration khi payment đang bank/awaiting và không có active intent khác.
- `private.payment_bank_qr_snapshot_guard`: cho phép snapshot mới trong nhánh bank/awaiting hẹp; snapshot vẫn immutable và toàn bộ beneficiary/content/QR do server tạo.
- `private.payment_core_guard`: thêm duy nhất nhánh tăng version `bank_transfer/awaiting_payment -> bank_transfer/awaiting_payment`, yêu cầu old intent expired, new intent ready/current và config enabled.
- `private.payment_rpc_receipts`: allowlist thêm `customer_regenerate_bank_transfer`.
- RPC chỉ grant execute cho `authenticated`; `public`, `anon` và `service_role` không có quyền execute.
- Getter bank thêm safe field `bank_intent_id` để app gửi exact intent guard.

## Customer app

Khi getter trả intent `expired`, QR và thao tác copy cũ bị ẩn/disable và UI hiển thị nút **Tạo mã mới**. Nút **Kiểm tra thanh toán** vẫn chỉ gọi getter refresh.

Nút regeneration bị disable khi command đang chạy, watcher đang loading/stale/offline, getter lỗi hoặc bank config unavailable. Double tap dùng chung một Future. Nếu timeout/transport outcome chưa xác định, app giữ nguyên object payload và operation ID cho lần retry. Sau success app refetch `customer_get_payment` rồi `customer_get_bank_payment`; command response không bao giờ được dùng để tự set paid/verifying.

`BANK_TRANSFER_RECONCILIATION_REQUIRED` hiển thị cảnh báo không chuyển thêm tiền và chờ hệ thống đối soát.

## Files thay đổi cho task này

- `backend/supabase/migrations/202610130002_customer_bank_intent_regeneration.sql`
- `backend/supabase/tests/payment_bank_regeneration_regression.sql`
- `backend/supabase/tests/payment_bank_qr_regression.sql`
- `tools/check_payment_bank_verification.mjs`
- `tools/check_payment_bank_verification_concurrency.mjs`
- `frontend/customer_app/lib/services/payment_service.dart`
- `frontend/customer_app/lib/models/bank_payment_dto.dart`
- `frontend/customer_app/lib/app/app_controller.dart`
- `frontend/customer_app/lib/app/payment_watcher.dart`
- `frontend/customer_app/lib/screens/payment_screen.dart`
- `frontend/customer_app/lib/widgets/bank_payment_ui.dart`
- `frontend/customer_app/test/payment_bank_test.dart`
- `docs/customer_bank_intent_regeneration_result.md`

Các file SePay/webhook đang dirty từ trước không bị sửa trong task regeneration này.

## Tests đã chạy

Backend PGlite PostgreSQL 18.3 / PGlite 0.5.8:

- regeneration regression: **34/34 assertions pass**;
- payment bank verification regression sau migration: **141/141 pass**;
- payment bank QR/cash regression sau migration: **84/84 pass**;
- payment realtime regression sau migration: **27/27 pass**;
- tổng nhóm post-regeneration: **286 assertions pass**;
- runner `shared-only` pass;
- runner `shared+admin/display-codes` pass (trước assertion audit cuối; sau đó `shared-only` xác nhận assertion audit mới).

Flutter:

- `flutter test test/payment_bank_test.dart`: **69/69 tests pass**;
- `flutter analyze`: **No issues found**.

Native multi-session concurrency:

- Đã thêm hai race cases vào `tools/check_payment_bank_verification_concurrency.mjs`: webhook-first và regeneration-first.
- Chưa chạy được tại máy hiện tại vì không có `GD6C_NATIVE_TEST_URL` và native `psql`. Harness trả `NOT RUN`, không được tính là pass.

Các scenario backend đã cover trong disposable regression: owner/non-owner, anonymous ACL, pre-expiry block, expired-ready success, payment/intent version conflict, replay, operation conflict, unique intent/reference/content, one active intent, old inbound reconciliation, late old webhook, valid new webhook settle một lần, rollback không orphan và terminal/non-bank states.

## Migration và blocker còn lại

Có cần migration mới: **Có**, chính là file `202610130002_customer_bank_intent_regeneration.sql`. App mới phải được phát hành sau khi migration này đã được review và apply; task này không deploy.

Blocker còn lại duy nhất trong phạm vi kiểm thử local là chưa có PostgreSQL native loopback target để thực thi race test đa connection. Live Supabase/Auth/PostgREST và provider/signature integration cũng chưa được chạy trong task này.

Không deploy. Không commit.
