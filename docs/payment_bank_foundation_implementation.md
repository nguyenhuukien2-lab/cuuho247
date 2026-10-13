# GD6A — Customer Bank Payment Foundation

Ngày: 2026-10-11. Đã tạo source migration, SQL regression và tài liệu. Đã thực
thi trên PostgreSQL PGlite cô lập trong RAM; **chưa deploy Supabase, không commit**.
Không sửa customer/rescuer/admin UI, các migration hoặc regression GD1–GD4.

## 1. Phạm vi và quyết định

Đã đọc năm migration payment GD1–GD4, tài liệu triển khai từng giai đoạn,
payment backend plan và customer cash UI. Contract hiện có:

- `public.payments.method` đã allow `cash`, `bank_transfer`; không cần sửa CHECK.
- RPC `customer_select_payment_method` chỉ chấp nhận cash, bank tiếp tục trả
  `METHOD_NOT_IMPLEMENTED`. Guard GD3 chỉ mở chọn CASH và xác nhận thu CASH.
- DTO getter giữ nguyên 15 keys; amount/version là decimal strings.
- Realtime vẫn chỉ phát `public.payments`, không phát events/private tables.
- Customer Bank vẫn là lựa chọn disabled **Chưa hỗ trợ**.

GD6A tạo storage và primitive nội bộ cho foundation. **Không tạo public RPC**
`customer_prepare_bank_payment`: chưa có provider/beneficiary config và chưa cần
customer contract cho một phương thức đang disabled. Không trả ready giả,
bank account giả, QR giả hoặc success cho customer.

## 2. Files và migration order

- [Migration](../backend/supabase/migrations/202610110001_payment_bank_foundation.sql).
- [Regression](../backend/supabase/tests/payment_bank_foundation_regression.sql).
- Báo cáo: `docs/payment_bank_foundation_implementation.md`.

Thứ tự: shared customer/rescuer prerequisites →
`202610100001_payment_core_security.sql` →
`202610100002_payment_customer_prepare.sql` →
`202610100003_payment_customer_select_cash.sql` →
`202610100004_payment_rescuer_cash.sql` →
`202610100005_payment_realtime.sql` →
`202610110001_payment_bank_foundation.sql`.

Không phụ thuộc Admin/display codes. Migration additive trong transaction,
lock timeout 5s, statement timeout 60s. Preflight kiểm prerequisites, RLS,
client DML denial, guard và publication. Object đã có sẽ bị từ chối; không
overwrite/merge schema. Không có backfill, seed provider/account hoặc dữ liệu bank.

## 3. Schema

Tất cả bảng mới ở `private`; không thêm cột, bảng, view hoặc function vào `public`.

| Bảng | Nội dung |
| --- | --- |
| `private.payment_bank_intents` | UUID, operation UUID, payment/request binding, reference server cấp, expected amount/currency, provider/scope/provider intent ID nullable, status, expiry, server timestamps, version |
| `private.bank_transactions` | Provider/scope/external transaction ID, receipt tùy chọn, amount/currency/direction, reference, occurred_at của nguồn, matched payment/intent nullable, verification status, server received/updated timestamps, version |
| `private.payment_webhook_receipts` | Provider/scope/delivery ID, event ID nullable, exact-body SHA256, signature_verified, processing status, server timestamps, version |
| `private.payment_bank_audit` | Một resource FK, old/new status, resource version, DB role thực thi, server timestamp; không JSON/raw payload |

Các source identity là provider-agnostic. `provider_scope` là namespace account/
merchant/environment đã được backend xác minh ở tích hợp sau, không phải API key
hoặc số tài khoản người gửi. Không chọn hoặc hardcode nhà cung cấp.

Chưa thêm beneficiary snapshot: chưa có cấu hình authoritative để snapshot.
Phase tích hợp phải thêm cấu hình beneficiary được xác minh, version và snapshot
bất biến **trước** khi mở `ready`/matching/verified.

Transaction lưu direction bắt buộc `credit`/`debit` và currency ISO dạng ba chữ
in hoa; có thể ghi nhận observation ngoại tệ/debit để từ chối/đối soát sau này.
Điều này không mở thanh toán đa tiền tệ: intent chỉ VND, mọi transaction vẫn
unverified/unmatched. Không lưu sender name, transfer free text, account người
gửi, raw JSON, headers, metadata tùy ý hoặc secret trong GD6A.

## 4. Constraints và reference

- Composite FK intent `(payment_id,request_id)` → payments `(id,request_id)`.
- Guard lấy snapshot trực tiếp từ `payments.amount_expected/currency`; không
  tính lại quote. Input snapshot NULL được điền từ payment, input khác nguồn
  authoritative bị từ chối. Amount >0, currency VND.
- Request và assignment phải completed, đúng customer/rescuer/provider và
  completion quote. Payment phải pending/method NULL. CASH hoặc terminal payment
  không được tạo reservation mới.
- `reference` UNIQUE, server-generated `BK-` + UUID ngẫu nhiên uppercase không
  dấu gạch. Cùng operation retry giữ nguyên reference. Không chứa PII/secret;
  reference không phải credential hoặc bằng chứng đã nhận tiền.
- Đây là namespace **nội bộ chưa phát hành cho ngân hàng**, không cam kết format/
  độ dài tương thích provider nào. Adapter sau phải xác minh round-trip và giới
  hạn ngân hàng trước khi phát hành. Không được sửa/reuse reference đã có.
- Binding payment/request/amount/currency/reference/expiry và operation bất biến.
- Partial unique index: tối đa một intent `created/ready/matched/verified` cho
  một payment. Verified giữ slot để tránh lần thu tiếp theo. Expiry trôi qua
  không tự giải phóng slot; phải chuyển trạng thái và ghi audit trước.
- UNIQUE provider/scope/provider_intent_id khi được cấu hình ở phase sau.
- Receipt UNIQUE `(provider,provider_scope,delivery_id)` và
  `(provider,provider_scope,event_id)`; event ID NULL được phép cho contract
  không có event identity riêng. Delivery identity vẫn bắt buộc.
- Transaction UNIQUE `(provider,provider_scope,external_transaction_id)`:
  không giả định ID globally unique giữa các account/provider.
- Receipt FK gồm provider/scope; không gắn receipt của nguồn khác vào transaction.
- Matched IDs phải cùng NULL hoặc cùng có giá trị; composite FK ràng buộc
  intent/payment. Partial UNIQUE payment khi transaction verified dự phòng
  chống phân bổ hai giao dịch cho cùng nghĩa vụ. Phase này chưa cho match.
- Timestamp finite, version >0, amount nguyên bigint >0, IDs text giới hạn độ dài.
- FK tài chính `ON DELETE RESTRICT`; không CASCADE xóa lịch sử.

Không có partial payment, cộng dồn, overpayment allocation hoặc tip.

## 5. Private backend primitive và quyền

```sql
private.payment_bank_create_intent(
  p_payment_id uuid,
  p_operation_id uuid,
  p_expires_at timestamptz
) returns uuid
```

Đây là **SECURITY INVOKER owner-only**, không phải PostgREST/customer RPC.
Không nhận amount/request/customer/provider từ client. Caller là trusted DB
owner/administration, chọn expiry theo server policy; GD6A không tự đặt TTL
provider giả. Expiry phải hữu hạn và ở tương lai khi tạo mới.

Tất cả năm private functions có `SET search_path=''`, schema-qualified objects,
không dynamic SQL trong production functions. Không tạo SECURITY DEFINER mới.
Không có đường user-facing nên không dùng `auth.uid()` để giả làm server quyền cao;
quyền owner có sẵn mới được dùng primitive này. JWT user, kể cả participant,
không có quyền gọi. Không có bypass qua JWT metadata hoặc custom GUC.

RLS bật cho cả bốn bảng, không policy. Revoke ALL trên bảng và functions khỏi
PUBLIC, anon, authenticated và service_role nếu tồn tại, kể cả default grants.
Không grant USAGE mới cho private schema. Không thay default privileges của app.
**service_role chưa được mở backend API writer trong GD6A.** BYPASSRLS không
thay được table/function ACL bị revoke. Backend path đã test là database owner
trong RAM, không phải Edge Function/service credential.

Migration tương lai phải cung cấp narrowly scoped server entrypoints, fixed
search_path và grant cụ thể; không cấp broad DML cho worker/frontend để né audit.
Private schema phải tiếp tục nằm ngoài exposed schemas. DB owner/DDL/superuser
có thể thay trigger, vẫn là trust boundary quản trị.

## 6. Intent state machine

CHECK dự trữ `created`, `ready`, `expired`, `cancelled`, `matched`, `verified`,
`failed`, nhưng trigger chỉ mở:

| Transition GD6A | Rule |
| --- | --- |
| absent → created | Private owner primitive hoặc owner insert có guard; pending payment hợp lệ, snapshot và reference do server cấp |
| created → expired | Server clock đã đến expiry, version +1 |
| created → cancelled | Explicit trusted internal cancellation, version +1 |
| created → failed | Explicit internal preparation failure, version +1; không đổi public payment failed |
| same status → same status | No-op: version/timestamps giữ nguyên, không audit lặp |
| ready/matched/verified/reopen | Bị chặn `BANK_INTENT_TRANSITION_NOT_ENABLED` |

Không update provider/provider_intent_id ở phase này; chỉ có cấu trúc dự trữ.
Created có nghĩa reservation nội bộ, **không có nghĩa customer đã chọn bank,
có thể chuyển tiền hoặc hệ thống đã cấu hình nhận tiền**.

Reservation created không khóa CASH. Nếu customer chọn/hoàn tất CASH sau khi
reservation nội bộ tồn tại, CASH vẫn chạy nguyên contract; reservation đó không
thể tự tiến sang ready/matched/verified. Future bank flow phải kiểm tra lại public
payment trước mọi bước và có quy tắc đóng/reconcile intent khi đổi phương thức.
GD6A không thêm trigger trên bảng public để tự sửa reservation theo CASH.

Receipt: insert `received`; cho `received → failed/rejected`, `failed → received`
để thể hiện retry xử lý nội bộ, version +1 và audit. `processed` bị chặn tới khi
có processor được review. Transaction: insert `unverified`, chỉ chuyển sang
`rejected`; matched/verified và gán matched IDs đều bị chặn.

## 7. Idempotency, locking và audit

Primitive khóa advisory theo operation UUID rồi kiểm immutable operation tuple
`payment_id + expires_at`. Same key/same tuple trả đúng intent đã có, kể cả
terminal hoặc expiry đã qua; không gia hạn, reset, insert/audit thêm. Same key
khác tuple → `IDEMPOTENCY_CONFLICT`. New key khi còn active intent →
`BANK_INTENT_ALREADY_ACTIVE`, không âm thầm trả success cho operation khác.
Sau explicit close, operation mới có thể tạo reference mới; reference cũ là tombstone.

Thứ tự tạo mới: operation advisory → request FOR UPDATE → assignment FOR SHARE
→ payment FOR UPDATE → intent/audit. Trigger owner insert độc lập cũng khóa
request → assignment → payment. Giữ thứ tự tương thích với CASH; không lấy
rescuer profile/quote lock sau payment. Unique operation/reference/active slot
bảo vệ bổ sung cho writer cạnh tranh. Không gọi HTTP trong transaction.

Audit append tự động cùng transaction với INSERT/status transition cho cả ba
resource types. Mỗi resource/version có tối đa một audit row. No-op và replay
không tạo audit mới. Audit insert thất bại rollback toàn bộ mutation; test ép
lỗi xác nhận không còn intent mồ côi. DB role lấy từ `current_user`, thời gian
từ server; không nhận actor tùy ý. Guard chặn direct append ngoài trigger và
UPDATE/DELETE/TRUNCATE audit. Các bảng nghiệp vụ cũng không DELETE/TRUNCATE;
identity, amount, reference, source data, signature flag và body hash bất biến.

GD6A không sửa/xóa/append bank event vào `public.payment_events`. CASH vẫn append
safe event bằng RPC cũ. Phase verified tương lai phải ghi safe event atomically
với payment; không publish raw bank audit.

## 8. Raw body policy và future webhook flow

Receipt chỉ giữ SHA-256 dạng hex 64 ký tự của **exact bytes body**. DB kiểm format,
không có body để tự kiểm digest hoặc cryptographic signature. `signature_verified`
là kết quả mà trusted adapter sẽ cung cấp, không tự chứng minh verification.
Không tạo adapter/endpoint webhook hoặc query bank trong GD6A.

Flow tương lai, chỉ khi provider contract thực sự hỗ trợ:

1. Server xác minh transport/source, signature/auth và replay timestamp theo
   contract; secrets nằm ngoài schema/client. Không mặc định provider có webhook.
2. Dedupe canonical receipt theo provider/scope/delivery/event identity. Với
   conflict, so original hash/source; same identity khác body là conflict cần
   xử lý, không overwrite và không coi mọi unique violation là success.
3. ACK chỉ sau khi receipt đã commit. Retry dùng lại identity, không đổi
   `signature_verified=false` thành true trên receipt cũ. Đường lưu invalid
   delivery phải được thiết kế chống chiếm canonical event ID khi tích hợp.
4. Worker normalize observation và dedupe transaction identity. Linked receipt
   phải cùng provider/scope, signature_verified=true và status received; tuy vậy
   transaction vẫn unverified, signature đúng không tự làm bank/payment verified.
5. Nguồn polling có thể không có receipt (`receipt_id=NULL`); cần verification
   contract riêng. Không tạo webhook giả để phục vụ nguồn không hỗ trợ webhook.
6. Future matching/settlement phải khóa, kiểm state/version/evidence, ghi
   transaction disposition + payment transition + safe public event + private
   audit trong cùng transaction, với idempotency xuyên các delivery khác nhau.

Chưa có worker scheduler, retry lease, rate limit, cryptographic verification,
payload conflict API hoặc server grant cho flow trên. Nếu cần giữ raw body để
điều tra, phải review kho mã hóa/quyền/retention riêng; không thêm JSONB public.
Không tự purge receipt, reference hoặc transaction identity làm mất chống replay.

## 9. Future matching policy

Tối thiểu phải đồng thời thỏa:

- Nguồn và beneficiary/provider scope được xác minh; credit đã được xác nhận
  theo contract thật, không phải debit/pending authorization.
- Reference exact match, chuẩn hóa chỉ theo quy tắc adapter đã kiểm chứng;
  một reference duy nhất gắn đúng intent/payment/request.
- Amount chính xác bằng intent.expected_amount **và** payments.amount_expected;
  currency đúng VND và khớp cả hai snapshot.
- Payment còn hợp lệ, đang ở bank state được phase sau cho phép; chưa CASH-paid,
  bank-paid, cancelled/refunded hoặc đã được một transaction khác phân bổ.
- Intent chưa expired/cancelled/failed, đúng version và beneficiary snapshot.
  Late transfer vào luồng đối soát, không tự hồi sinh intent/payment.
- Transaction identity chưa apply trước đó. Event ID khác nhưng cùng transaction
  không được settlement lần hai.

Không match chỉ theo amount, sender name hoặc thời gian gần nhau. Không fuzzy
auto-paid, không tự cộng partial, không tự phân bổ phần thừa, không tip.
Không có evidence/verification flow → không có bank paid.

## 10. Realtime

Không thêm bất kỳ private table hoặc `public.payment_events` vào publication.
Preflight từ chối **mọi** publication FOR ALL TABLES, private-schema publication
(kể cả chưa có private table), hoặc publication đã chứa private/events.
`public.payments` và các publication members cũ giữ nguyên. Không đổi RLS,
replica identity, DTO, grants hoặc payment guard của GD1–GD4.

## 11. Kiểm thử thực tế

Engine **PGlite 0.5.8 / PostgreSQL 18.3**, database RAM mới, auth/storage schemas
và SQL roles mô phỏng. Không URL database, không kết nối Supabase thật.

| Suite/check | Shared + Admin/display codes | Shared-only |
| --- | --- | --- |
| GD1 nguyên bản | 114/114 PASS | 114/114 PASS |
| GD2A nguyên bản | 72/72 PASS | 72/72 PASS |
| GD2B nguyên bản | 91/91 PASS | 91/91 PASS |
| GD3 nguyên bản | 122/122 PASS | 122/122 PASS |
| GD4 trước GD6A | 27/27 PASS | 27/27 PASS |
| GD6A, hai lần | 170/170 PASS mỗi lần | 170/170 PASS mỗi lần |
| GD4 sau GD6A | 27/27 PASS | 27/27 PASS |
| Catalog public/guards trước và sau GD6A | Không đổi | Không đổi |
| Broad/all-private-schema publication preflight | Từ chối đúng | Từ chối đúng |
| Rerun migration / thiếu test opt-in | Từ chối đúng | Từ chối đúng |
| Fixture/audit rollback, không seed bank | PASS | PASS |
| Hash 469 existing source files | Không đổi | Không đổi |

**Cách chạy regression cũ:** GD1–GD3 chứa assertion “RPC giai đoạn sau chưa tồn
tại”/“payment chưa publish”. Vì vậy chạy nguyên bản từng suite ngay sau migration
tương ứng, trước giai đoạn tiếp theo; không sửa assertion cũ để giả pass sau GD6A.
Sau GD6A, chạy GD4 nguyên bản và các case CASH mới (select, current-version no-op,
amount mismatch, confirm, exact retry, getter, single cash event) trên schema đầy đủ.
Catalog comparison xác nhận definitions/ACL của RPC public và payment guards,
public columns/constraints/policies/publication giữ nguyên.

170 assertions GD6A kiểm effective SELECT/INSERT/UPDATE/DELETE denial cho
anon/authenticated, helper denial kể cả owner customer/unrelated customer,
service_role ACL, backend owner creation, snapshot/uniqueness/idempotency,
reference/expiry immutability, state/version guards, duplicate webhook/transaction,
receipt source/signature binding, no raw-body field, no matched/verified/auto-paid,
atomic audit rollback, audit immutability, public row invariance và CASH compatibility.

Test invalid public states dùng privileged fault injection trong subtransaction,
tạm disable **đúng payment row guard**, restore trước gọi helper rồi rollback;
không nới client quyền. Assertion cuối xác nhận guard được phục hồi. Test audit
failure thêm CHECK synthetic rồi bỏ trong transaction test. File regression kết
thúc ROLLBACK; sequence advances không rollback, nên chỉ chạy disposable DB.

```sql
-- Cùng connection đã xác minh disposable; psql -X -v ON_ERROR_STOP=1.
SET payment.test_mode='local_disposable';
\i backend/supabase/tests/payment_bank_foundation_regression.sql
```

Harness RAM ignored dùng trong phiên:
`.cache_rescuer/temp/payment-core-security/run_payment_bank_foundation.mjs`.
Chạy từ repo root bằng `node <path>` và thêm `--shared-only` cho cấu hình thứ hai;
dùng PGlite đã có trong cache, không thêm dependency ứng dụng.

Chưa chạy Supabase Auth/JWT/PostgREST/Realtime server thật, provider sandbox,
webhook hoặc concurrency hai connection trên cùng database. Hai lần/config RAM
không được tính là concurrency test. Khi mở tích hợp phải kiểm race cùng operation,
khác operation/cùng payment, CASH selection vs bank prepare, worker replay vs
settlement và deadlock/retry với native PostgreSQL.

## 12. Chưa triển khai

Không chọn provider; không account/beneficiary production; không QR, public bank
RPC, customer method activation, webhook endpoint, signature verifier, bank query,
matching processor, ready/verified transition, bank paid, recovery/refund, partial,
tip, Admin UI hoặc Rescuer UI. Không sửa migration/test cũ. Không thay đổi frontend.
Không tự chạy production Supabase. Người dùng review và deploy migration thủ công.
**KHÔNG COMMIT.**
