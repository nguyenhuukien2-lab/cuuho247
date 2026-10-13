# Customer bank payment expiry review

Ngày kiểm tra: 2026-10-13  
Phạm vi: customer app, payment RPC, bank intent/QR schema, GD6B/GD6C, SePay webhook và trạng thái hiển thị trên rescuer app.

## Kết luận

Hiện tại customer **không thể tạo QR/bank intent mới cho cùng payment** sau khi intent hết hạn.

| Câu hỏi | Kết quả |
|---|---|
| Có RPC regenerate/retry intent hiện hữu? | Không |
| Gọi lại `customer_select_bank_transfer` với operation ID mới? | Bị `PAYMENT_NOT_ELIGIBLE` |
| Gọi lại với operation ID cũ? | Chỉ replay receipt cũ, không tạo intent mới |
| Có one-payment-per-request? | Có, nhưng không phải blocker chính |
| UI có regenerate? | Không. Nút `Làm mới` chỉ refetch getter |
| Có cần migration mới? | Có |

## Exact current behavior

### 1. Lần chọn bank đầu tiên

`customer_select_bank_transfer` thực hiện trong một transaction:

1. Tạo hoặc reuse reservation `created` còn hạn.
2. Tạo immutable QR snapshot.
3. Chuyển intent sang `ready`.
4. Chuyển payment từ `pending/null` sang `awaiting_payment/bank_transfer` và tăng payment version.
5. Ghi `bank_qr_created` event và idempotency receipt.

Customer app bỏ command DTO và refetch `customer_get_payment`, sau đó gọi `customer_get_bank_payment` để lấy snapshot authoritative.

### 2. Khi QR/intent hết TTL

`customer_get_bank_payment` tính effective status thành `expired` khi intent vẫn là `created` hoặc `ready` nhưng `expires_at <= statement_timestamp()`.

Getter này:

- không update trạng thái intent trong database;
- không giải phóng active-intent slot;
- không tạo QR mới;
- không đổi payment sang `failed`, `verifying` hoặc `paid`;
- trả `qr_payload = null` vì intent không còn usable.

Payment vẫn là `bank_transfer/awaiting_payment`.

### 3. Hành vi UI customer

`BankPaymentSection` ẩn QR khi expired. Nút cuối màn hình đổi label thành `Làm mới`, nhưng callback vẫn là `onRefresh`.

`onRefresh` chỉ đọc lại:

- `customer_get_payment`;
- `customer_get_bank_payment`.

Nó không gọi mutation và không tạo intent mới. Vì vậy đây là nút refresh trạng thái, không phải retry/regenerate.

### 4. Hành vi UI rescuer

Rescuer app đọc payment public. Với `bank_transfer/awaiting_payment`, app hiển thị `Đang chờ hệ thống xác minh` và không cho rescuer tự xác nhận bank payment.

## Exact blockers

### `customer_select_bank_transfer` không hỗ trợ renewal

RPC hiện yêu cầu:

```sql
p.status = 'pending'
p.method is null
```

Sau lần chọn bank đầu, payment đã là:

```text
status = awaiting_payment
method = bank_transfer
```

Do đó:

- operation ID mới trả `PAYMENT_NOT_ELIGIBLE`;
- operation ID cũ tìm thấy receipt và chỉ replay response cũ với `changed=false`.

### Intent hết TTL vẫn chiếm active slot

Partial unique index `bank_intent_one_active_payment` coi các trạng thái sau là active:

```text
created, ready, matched, verified
```

TTL hết không tự loại intent `ready` khỏi index. Intent phải được explicit transition sang `expired`, có version increment và audit, trước khi tạo intent mới.

### Trigger guards cũng chặn renewal

Chỉ thêm một public RPC là chưa đủ. Các guards hiện tại chỉ cho phép tạo snapshot và chuyển `created -> ready` khi payment còn `pending/method null`.

Một migration renewal cần cập nhật đồng bộ:

- `private.payment_bank_intent_guard`;
- `private.payment_bank_qr_snapshot_guard`;
- `private.payment_core_guard` nếu renewal tăng payment version;
- allowlist của `private.payment_rpc_receipts`.

### One-payment-per-request

`public.payments.request_id` là unique và `customer_prepare_payment` trả payment hiện có nếu request đã có payment.

Guard này không ngăn nhiều intent lịch sử cho cùng payment. Nó chỉ yêu cầu flow renewal phải reuse đúng payment hiện hữu, không được tạo payment thứ hai cho cùng request.

### Controller customer chặn gọi lại select bank

`AppController.selectBankPayment` chỉ tạo command khi:

- payment `pending`;
- method `null`;
- bank capability available;
- dữ liệu không stale/loading/error.

Do đó frontend hiện không có đường gọi bank mutation cho payment `awaiting_payment`.

## Vì sao SePay webhook 200 nhưng payment chưa paid

HTTP 200 của webhook chỉ có nghĩa provider không cần retry request đó. Handler trả 200 cho cả:

- `paid`;
- `intent_expired`;
- `amount_mismatch`;
- `reference_unmatched`;
- `beneficiary_mismatch`;
- và các terminal rejection khác.

GD6C trả `intent_expired` nếu intent đã hết hạn tại thời điểm processor chạy. Nhánh này:

1. ghi bank transaction là `rejected`;
2. ghi receipt là `processed`;
3. lưu `result_code/rejection_code`;
4. trả terminal result cho handler;
5. handler trả HTTP 200;
6. payment vẫn `awaiting_payment`.

HTTP 200 một mình không cho biết live transaction được `paid` hay bị terminal reject. Cần kiểm tra:

- `private.payment_webhook_receipts.result_code`;
- `private.bank_transactions.rejection_code`.

Với UI customer đang báo expired và payment chưa paid, `intent_expired` là khả năng phù hợp nhất, nhưng phải đọc hai trường trên mới xác nhận được exact rejection của transaction live.

## Additive migration/RPC đề xuất

Không sửa GD6B/GD6C cũ. Tạo migration mới, ví dụ:

```text
backend/supabase/migrations/202610130002_customer_bank_intent_regeneration.sql
```

### RPC đề xuất

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

### Preconditions

- Caller phải là authenticated customer owner.
- Request/payment binding phải khớp và không làm lộ foreign IDs.
- Payment phải là `bank_transfer/awaiting_payment`.
- Không cho renewal khi payment là `verifying`, `paid`, `refunded`, `failed`, `cancelled` hoặc cash.
- Current intent phải đúng ID/version, là current/latest intent và đang `ready`.
- `expires_at <= server clock`; không dùng giờ thiết bị và không cho expire sớm.
- Bank configuration vẫn enabled và amount/currency còn hợp lệ.
- Không có intent khác đang active.

### Transaction an toàn

Trong cùng transaction:

1. Áp dụng operation idempotency lock và lock order tương thích webhook.
2. Lock owned request, assignment, payment, config và current intent.
3. Recheck toàn bộ eligibility sau khi có lock.
4. Nếu đã có normalized inbound bank transaction mang đúng `transfer_content` cũ, trả `BANK_TRANSFER_RECONCILIATION_REQUIRED` để tránh khách trả hai lần.
5. Chuyển intent cũ `ready -> expired`, tăng intent version và ghi audit.
6. Tạo intent mới với operation ID mới và server TTL mới.
7. Tạo immutable QR snapshot mới với reference/transfer content mới.
8. Chuyển intent mới `created -> ready`.
9. Tăng payment version nhưng giữ nguyên `bank_transfer/awaiting_payment`, để phát authoritative invalidation và loại cached snapshot cũ.
10. Ghi `bank_qr_created` event và immutable idempotency receipt.

### Security invariants

- Không gia hạn `expires_at` của intent cũ.
- Không reuse old reference/transfer content.
- Không gắn late webhook của intent cũ sang intent mới.
- Không cho frontend set `paid`, `verified_at`, `paid_at` hoặc `amount_received`.
- Chỉ GD6C trusted verification processor được settle payment.
- RPC replay cùng payload trả cùng kết quả; cùng key khác payload trả `IDEMPOTENCY_CONFLICT`.
- Failure phải rollback intent, snapshot, payment version, event và receipt cùng nhau.

## UI tối thiểu sau khi backend có RPC

Khi authoritative bank DTO có `bank_intent_status == expired`:

- đổi nút `Làm mới` thành `Tạo mã mới`;
- gọi `customer_regenerate_bank_transfer` bằng operation ID mới;
- disable khi loading, stale, offline hoặc command đang chạy;
- double tap chỉ gửi một command;
- timeout/ambiguous retry phải dùng lại đúng operation ID và payload;
- sau success hoặc ambiguous result, refetch cả payment getter và bank getter;
- không dùng response command để tự cập nhật payment state;
- không có nút `Tôi đã chuyển khoản` hoặc frontend mark paid.

Nút `Kiểm tra thanh toán` vẫn giữ riêng và chỉ làm read-only refresh.

Nếu RPC trả `BANK_TRANSFER_RECONCILIATION_REQUIRED`, UI phải báo giao dịch cũ đang cần hệ thống đối soát, không hiển thị QR mới.

## Files cần sửa khi triển khai

### Backend

- `backend/supabase/migrations/202610130002_customer_bank_intent_regeneration.sql` — file mới.
- `backend/supabase/tests/payment_bank_regeneration_regression.sql` — file mới.
- `tools/check_payment_bank_regeneration.mjs` — file mới, hoặc mở rộng runner verification hiện có.

### Customer app

- `frontend/customer_app/lib/services/payment_service.dart`
  - thêm regeneration selection DTO/source method;
  - gọi RPC mới với exact allowlisted params;
  - allowlist các safe error code mới.
- `frontend/customer_app/lib/app/app_controller.dart`
  - thêm command state/idempotent retry riêng cho regeneration;
  - chỉ cho gọi khi authoritative current payment/intent expired.
- `frontend/customer_app/lib/screens/payment_screen.dart`
  - nối callback regenerate vào bank section.
- `frontend/customer_app/lib/widgets/bank_payment_ui.dart`
  - hiển thị `Tạo mã mới` khi expired;
  - giữ refresh read-only cho các trạng thái khác.
- `frontend/customer_app/test/payment_bank_test.dart`
  - thêm controller, HTTP và widget tests cho renewal.

Nếu payment version không được tăng trong renewal, cần bổ sung stable intent identity vào DTO và sửa `bank_payment_dto.dart`/`payment_watcher.dart`. Phương án khuyến nghị là tăng payment version atomically để cached bank snapshot cũ tự mất hiệu lực.

## Tests cần thêm

### Backend SQL

- Auth missing, owner/non-owner và foreign request/payment.
- Không cho regenerate trước expiry.
- Không cho regenerate `created`, `matched`, `verified` hoặc active `ready` còn hạn.
- Không cho payment cash/verifying/paid/refunded/failed/cancelled.
- Payment version và intent version conflict.
- Exact idempotent replay và changed flag.
- Cùng operation ID với payload khác trả conflict.
- Old intent được audit thành expired.
- New intent/reference/transfer content/QR khác và unique.
- Chỉ một active intent trên payment sau renewal.
- Getter chỉ trả newest ready intent và không trả QR cũ.
- Concurrent regenerate chỉ tạo một new intent.
- Race webhook-vs-regenerate không deadlock và không double settle.
- Có inbound transaction theo mã cũ thì block bằng reconciliation-required.
- Late webhook của mã cũ không settle intent mới.
- Webhook hợp lệ của mã mới settle đúng một lần.
- Rollback không để orphan intent/snapshot/event/receipt.
- ACL chỉ grant RPC mới cho `authenticated`; private tables vẫn inaccessible/unpublished.

### Flutter

- Expired hiển thị `Tạo mã mới`, không hiển thị QR cũ.
- Cancelled/failed/unavailable không tự hiển thị regenerate.
- Stale/offline/loading disable action.
- Exact RPC path và params; không gửi amount, beneficiary, reference hoặc expiry từ client.
- Double tap coalesce thành một command.
- Timeout retry giữ nguyên operation ID.
- Version conflict refetch trước khi tạo payload mới.
- Success refetch và hiển thị QR mới.
- Reconciliation-required hiển thị thông báo an toàn.
- Auth/request switch không restore QR cũ.
- Regenerate không tự tạo `verifying` hoặc `paid`.
- Responsive ở width 320/390/480 và text scale 2.

## Kiểm chứng đã chạy

Đã chạy:

```text
flutter test test/payment_bank_test.dart
```

Kết quả: **63/63 tests pass**.

Các test hiện tại xác nhận:

- expired chỉ ẩn QR;
- timer expiry chỉ refetch getter;
- không gọi bank selection khi expired;
- frontend không tự chuyển payment sang verifying/paid;
- paid chỉ được hiển thị từ authoritative getter.

## Trạng thái thực hiện

- Không sửa migration cũ.
- Không bypass expiry/security.
- Không cho frontend mark paid.
- Không deploy.
- Không commit.
- Audit này không thay đổi các file SePay/webhook đang có thay đổi sẵn trong worktree.
