# GD6C — Bank Transaction Verification

Ngày 11/10/2026. **BLOCKED ON REAL PROVIDER INTEGRATION.** Đã triển khai
provider-neutral engine, normalized model, adapter interface, endpoint skeleton
đóng mặc định và tests. **Production auto-paid DISABLED. KHÔNG DEPLOY. KHÔNG COMMIT.**

## Provider truth check

Đã đọc các migration GD1, GD2A, GD2B, GD3, GD4, GD6A, GD6B, tài liệu foundation,
bank QR, cash UI và customer DTO/service/controller/realtime. Tìm trong backend,
tools, docs, frontend/config, tên biến `.env` và environment process hiện có:
không tìm thấy tích hợp SePay, Casso, PayOS, bank Open API, payment gateway,
webhook authentication hoặc API query transaction thật. Không chọn provider.

Đây là kết luận về source/config local kiểm tra được, **không xác nhận rằng
Supabase production không có secret**: không truy cập database/live secrets.
VietQR GD6B là chỉ dẫn chuyển khoản, không phải bằng chứng ngân hàng nhận tiền.
Không tạo webhook/signature/provider fixture giả. Dữ liệu synthetic trong tests
là normalized observations nội bộ trên disposable DB, không phải bank callback.

Blocker syntax GD6B đã được sửa theo yêu cầu riêng của user: dòng 13 đổi duy nhất
`thencc` thành `then` ở preflight `private.payment_bank_config`. Không đổi business
logic/schema/RPC. Chain nguyên source đã PASS ở cả shared-only và shared+admin;
runner không còn sửa SQL trong RAM. Không sửa database production.

## Files mới

- `backend/supabase/migrations/202610110003_payment_bank_verification.sql`.
- `backend/supabase/tests/payment_bank_verification_regression.sql`.
- `backend/supabase/functions/bank-webhook/index.ts`.
- `backend/supabase/functions/bank-webhook/handler.ts`.
- `backend/supabase/functions/bank-webhook/adapter.ts`.
- `backend/supabase/functions/bank-webhook/normalized.ts`.
- `backend/supabase/functions/bank-webhook/boundary_test.ts`.
- `backend/supabase/functions/bank-webhook/README.md`.
- `tools/check_payment_bank_verification.mjs`.
- `tools/check_payment_bank_verification_concurrency.mjs`.
- Tài liệu này.

Không sửa source cũ, customer/rescuer app, Admin UI hoặc migration/test cũ.
Cache/log và script hỗ trợ tạo file nằm trong ignored `tools/.work`, không thuộc
artifact triển khai. Repo đã có nhiều thay đổi trước tác vụ; không dùng toàn bộ
`git status` làm danh sách thay đổi của GD6C.
Đối chiếu SHA256 cuối tác vụ: **586 file baseline hiện có không đổi**; artifact
GD6C gồm 11 file mới bên trên. `git diff --check` không có whitespace error.

## Architecture và endpoint

Luồng mục tiêu khi tích hợp provider thật:

```text
provider raw bytes + headers
  -> body limit + authentication theo contract thật
  -> final credit event + account/scope verification
  -> normalized transaction + SHA256 exact raw bytes
  -> private.process_verified_bank_transaction(jsonb)
  -> receipt + transaction + match + paid + event + audit COMMIT
  -> acknowledgement theo contract provider

public.payments UPDATE -> customer realtime invalidation
  -> customer_get_payment -> authoritative paid DTO
```

`BankProviderAdapter.authenticateAndNormalize` định nghĩa boundary cho raw body,
headers, server receive time và normalized output. `BankVerificationStore` định
nghĩa boundary processor/auth-failure audit. **Không có implementation adapter
hoặc DB transport production; installedAdapter=null.** Không có env toggle để
bật endpoint hiện tại, không có nhánh parse request JSON thành trusted model.

Supabase Edge Function shell tại `bank-webhook/`: POST only (405 cho method khác),
64 KiB tối đa cả Content-Length và stream thực, timeout đọc 5 giây, JSON media
type tạm thời, từ chối content encoding. Generic response, no-store, không log
body/header/internal error. POST trong giới hạn trả **503 verification_unavailable**,
kể cả payload tự khai `authentication_verified=true`. Không ACK success giả và
không ghi giao dịch incoming từ endpoint. Không deploy function/config, không
tắt JWT gateway mặc định; ingress contract sẽ phải được review khi có provider.

## Authentication và secrets

**Chưa có signature/token verifier thật.** Không tự thiết kế HMAC, không giả định
provider nào hỗ trợ timestamp/signature. SHA256 body chỉ phục vụ integrity/dedupe,
không xác minh nguồn gửi. SQL không thực hiện cryptography/authentication webhook.

Normalized `authentication_verified=true` là assertion từ trusted server adapter
sau verification, không phải input customer. `signature_verified` tách riêng:
token/mTLS không bị ghi thành signed. Method `signature` bắt buộc flag signature
true. Method names mô tả kết quả tương lai, không tuyên bố có verifier tương ứng.

Auth failure: `private.record_bank_auth_failure(provider,scope,body_sha256)` ghi
private audit, **không chiếm event/delivery ID** trong canonical inbox. Provider
và scope của audit phải do server chọn. Primitive cũng owner-only; chưa wired vào
endpoint chưa có provider. Khi tích hợp cần rate limiting ở ingress cho auth failures.

Credentials/contract còn thiếu chính xác theo chức năng:

1. Provider thực tế, API version, tài liệu chính thức và official payload samples;
   event credit/final-settled nào là bằng chứng tiền đã vào tài khoản.
2. Cơ chế auth thật: signature algorithm/canonical bytes/header/key rotation và
   webhook signing secret/public-key material **nếu contract dùng signature**;
   hoặc chính xác token/API key/header/mTLS credentials mà provider hỗ trợ.
3. Event/delivery/transaction ID uniqueness scope, retry semantics, timestamp
   field/timezone/replay window nếu có, acknowledgement/status-code contract.
4. Provider merchant/account/environment identifier liên kết BIN/account nhận
   tiền; xác minh currency/amount unit và reference round-trip không bị sửa.
5. API token/credentials query transaction **chỉ nếu contract cần bước query**;
   không tạo API call hoặc bank credentials không có căn cứ.
6. Trusted database transport và credential server riêng, quyền tối thiểu cho
   processor/audit. Migration hiện **không grant service_role**; service-role key
   đơn lẻ không gọi được processor. Không expose private schema qua PostgREST.

Chưa thể đặt tên secret chính xác của provider khi chưa biết provider/contract.
Lưu secrets thật bằng Supabase function secrets hoặc cơ chế server tương đương,
không SQL seed, Flutter, public table, Vite env, RPC DTO hoặc log. Không tạo secret
production. Không có real secret trong các file mới.

## Normalized transaction và storage

Reuse toàn bộ foundation, không tạo bảng nghiệp vụ trùng:

| Bảng | Bổ sung GD6C |
| --- | --- |
| `private.payment_bank_config` | `verification_enabled=false`, provider/scope nullable, `require_beneficiary=true`; bật verification yêu cầu đủ provider/scope |
| `private.payment_webhook_receipts` | Auth verified/method, normalized digest, result code; giữ delivery/event identity, signature flag, raw body hash, server receive time |
| `private.bank_transactions` | Beneficiary BIN/account nullable, normalized digest, rejection code; giữ amount/currency/direction/reference/provider timestamp/matched IDs |
| `private.payment_bank_audit` | Action/reason/provider/scope/body hash; mở rộng audit attempts, giữ lifecycle audit unique/resource/version |
| `private.payment_bank_intents` | Reuse immutable binding/snapshot; mở narrow ready -> verified với evidence |
| `private.payment_bank_qr_snapshots` | Reuse immutable GD6B beneficiary + bank-facing reference; không sửa cấu trúc/dữ liệu |

Required model: provider, provider_scope, provider_transaction_id, amount decimal
string, currency, credit/debit, occurred_at ISO timezone, auth result/method,
signature result và raw_payload_sha256. Optional delivery/event ID, full transfer
reference, beneficiary BIN/account. DB tự cấp received_at/updated_at. Không nhận
payment ID/request ID để redirect matching. Sender info không cần nên không lưu.

JS không chuyển amount qua Number; SQL bigint kiểm range. SQL và model đều kiểm
shape/allowlist, ID lengths, booleans, finite timestamp và malformed amount.
Unknown fields, kể cả raw payload hoặc caller-supplied received_at, bị từ chối.
SQL tự tính semantic SHA256 từ fixed field tuple; timestamp canonical UTC gồm
microseconds. Delivery/event IDs và envelope body hash không nằm trong semantic
transaction digest để retry khác envelope vẫn kiểm cùng facts. Optional null và
omitted tương đương; không thay đổi currency/reference/amount.

## Exact matching

Tất cả điều kiện sau phải đúng trong transaction đã lock:

1. Caller có DB quyền server tin cậy và normalized auth evidence hợp lệ;
   config verification enabled, provider/account scope chính xác.
2. Full transfer_content bằng đúng unique `payment_bank_qr_snapshots.transfer_content`.
   `bank_sequence_v1` = `BK` + 19 ASCII digits. Không trim, lowercase, bỏ ký tự,
   substring, fuzzy, sender-name/amount/date-only matching.
3. Snapshot -> intent -> payment/request composite bindings đúng; nếu intent có
   provider binding thì nó phải khớp. Request/assignment completed và ownership/
   rescuer/completion quote vẫn khớp immutable payment.
4. Intent `ready`, chưa hết hạn tại lúc xử lý; cancelled/failed/expired không settle.
5. Payment method `bank_transfer`, status `awaiting_payment`, version còn tăng được;
   chưa paid/refunded/cancelled/verifying theo policy atomic V1.
6. Direction credit; **amount = intent.expected_amount = payment.amount_expected**;
   currency khớp cả hai. Thiếu/thừa đều rejected, không partial, tip hoặc cộng dồn.
7. BIN/account snapshot khớp configured authenticated scope hiện tại. Mọi beneficiary
   provider có cung cấp đều phải khớp; default bắt buộc đủ BIN và account. Chỉ DB
   owner có thể bỏ yêu cầu field thiếu khi contract thật chứng minh scope đã bind
   chính xác account. Không bỏ kiểm field hiện diện dù require_beneficiary=false.
8. Provider timestamp không trước intent creation, không tới/sau expiry, không ở
   tương lai. Xử lý muộn sau expiry vẫn từ chối dù occurred_at ở trong thời hạn.
9. Transaction identity chưa sử dụng, payment chưa được transaction verified khác
   phân bổ. Reference của payment khác chỉ lookup payment đó; không redirect
   sang payment caller muốn. Reuse transaction đổi reference/amount -> conflict.

Không sửa reference `BK-UUID` của foundation hoặc content đã in trong QR. Khi
xoay tài khoản, snapshot cũ giữ nguyên nhưng V1 fail closed `config_mismatch` cho
account cũ. Multi-account reconciliation là phần chưa làm, không settle nhầm
vào config mới. QR `enabled` và `verification_enabled` riêng biệt: ẩn QR không
thu hồi lệnh chuyển tiền đã phát hành; verification kill switch mới chặn ingest.

Mismatch lưu transaction `rejected` + immutable reason và receipt `processed`:
processed nghĩa engine đã phân loại, **không có nghĩa paid**. Không đổi public
payment hoặc tự retry settlement của terminal rejected transaction. Manual
review/reconciliation cần quy trình sau, chưa có Admin UI để thực hiện.

## Atomic state transition, events và audit

Trong cùng DB transaction: authenticated receipt -> immutable observation ->
matching -> transaction verified -> intent verified -> payment awaiting_payment
to paid -> safe event -> receipt processed + audits. Trigger kiểm lại evidence.

Payment set server-side `amount_received=transaction.amount`, `status=paid`,
`version=old+1`, `paid_at=verified_at=server clock`; không nhận thời gian paid
từ provider/caller. Cash fields giữ nguyên. Không intermediate verifying trong
V1 vì event đã authenticated và final credit trước engine. QR/refetch/timer không
chuyển verifying hoặc paid. Không tạo customer/rescuer bank-confirm RPC.

Event dùng **`bank_payment_verified` đã có trong contract**, actor system,
old awaiting_payment/new paid, exact amount, metadata `{}`, operation_id là
internal transaction UUID. Unique event/payment, event time = payment.paid_at.
Không thêm event type `payment_paid` ngoài CHECK hiện có. Events vẫn immutable,
không client SELECT/DML, không realtime. Audit failure hoặc event failure rollback
cả receipt/transaction/intent/payment để provider retry an toàn.

Private audit gồm lifecycle và webhook_received/auth_verified/auth_failed/
duplicate/conflict/transaction_normalized/match_succeeded/match_rejected/
payment_transitioned. Lifecycle giữ partial unique resource/version; duplicate
attempt không tăng payment/transaction version nhưng được ghi audit riêng.
Chỉ enums/reason codes/digests, không raw JSON/header/error/secret plaintext.

## Idempotency và concurrency

Giữ foundation unique `(provider,provider_scope,delivery_id)`, optional event ID
và `(provider,provider_scope,external_transaction_id)`. Không giả định IDs global
giữa account/environment. Processor dùng advisory transaction lock theo
provider/scope để serialize V1, sau đó request -> assignment -> payment -> config
-> intent locks theo thứ tự GD6B. Không HTTP trong transaction. Row locks,
immutable guards, composite FKs, unique verified-payment index và version predicate
bảo vệ bổ sung; trả lỗi retry nếu atomic transition không thể commit.

Canonical delivery key: `delivery:<ID>` nếu có delivery; `event:<ID>` nếu chỉ có
event; **`body:<sha256 exact bytes>` chỉ khi cả hai thiếu**. Policy content hash
không chống giả mạo; auth provider vẫn bắt buộc. ID không được tái sử dụng/purge
để xóa dấu replay. Không fallback hash cho missing transaction ID.

Same delivery/event + same body/semantic tuple -> duplicate_event, không thêm
transaction/settlement. Same event khác delivery vẫn dùng canonical receipt.
Same ID nhưng body/semantic tuple khác -> identity_conflict; không overwrite.
New event cho same transaction -> receipt mới, duplicate_transaction nếu facts
khớp; transaction_conflict nếu khác. Transaction bị rejected trước đó vẫn terminal,
duplicate không hồi sinh nó. Legacy received/failed receipt chưa hoàn tất trả
receipt_incomplete để review, không ACK committed settlement.

Hai transaction cạnh tranh một payment: payment lock + state recheck cho một
settlement; transaction sau bị already_paid. Current processor dùng conservative
provider-scope serialization, không claim throughput scale-out. Native runner
dùng session barrier và hai psql connections để kiểm lock overlap; **chưa chạy
thành công tại môi trường hiện tại**, không coi repeated RAM calls là concurrency.

## Security và customer/realtime

Processor và auth-failure primitive `SECURITY INVOKER SET search_path=''`,
REVOKE PUBLIC/anon/authenticated/service_role. Hiện chỉ DB owner/administration
đã có quyền phù hợp gọi; không public/server REST wrapper. Không có bypass qua
auth.uid/custom GUC. Test opt-in GUC chỉ nằm trong regression, không production
engine. Không table/API grants mới cho client; private RLS và immutable guards
giữ nguyên, kể cả default ACL rộng do harness cố tình thiết lập.

Không public bank raw fields, không publish private tables hoặc payment_events;
preflight từ chối unsafe broad/schema publication. Public payment columns,
participant RLS và getters/select/cash RPC giữ nguyên. Guard cũ được mở rộng trong
**migration mới** cho evidence-backed bank transition, không sửa file deployed.

Customer code không thay đổi. PaymentWatcher vẫn subscription public.payments,
raw realtime chỉ invalidation; getter mới và version/scope/auth guard quyết định
state. Bank getter suppress QR sau paid. UI read-only verifying có sẵn; full Bank
Paid/Verifying visual polish thuộc GD6D. Không có customer mark-paid action.

## Tests và kết quả

| Kiểm tra | Kết quả thực tế |
| --- | --- |
| GD1 / GD2A / GD2B / GD3 / GD4 nguyên bản đúng stage | 114 / 72 / 91 / 122 / 27 assertions PASS |
| GD6A trước GD6B | 170 assertions PASS, runner kiểm cả publication/ACL/rollback |
| GD6B nguyên source đã sửa typo | **84 assertions PASS**, trước và sau GD6C |
| GD6C normalized/matching/security SQL | **141 assertions PASS**, cả shared-only và shared+admin schema, không workaround |
| Cash cuối schema | PASS trong GD6B và GD6C; public cash RPC definition/ACL không đổi |
| GD4 sau GD6C | 27 assertions PASS |
| Model/endpoint boundary tests | **27/27 PASS**, Node 24.14.0; không phải provider signature tests |
| TypeScript strict noEmit | PASS cho model/adapter/handler/boundary tests bằng compiler local |
| Flutter customer full suite | **569 PASS**, `flutter test --no-pub --reporter expanded` |
| Flutter analyze | **0 errors, 4 warnings cũ**, exit 1 do warnings |
| Native multi-connection concurrency | **NOT RUN**: chưa có local native PostgreSQL/psql và GD6C_NATIVE_TEST_URL; Docker daemon chưa chạy |
| Real provider signature / official fixtures / bank calls | **NOT RUN**, chưa có integration/contract |
| Supabase Edge/Deno deployment, live JWT/PostgREST/realtime E2E | **NOT RUN**, không deploy hoặc gọi backend live |

4 warnings giữ nguyên tại `lib/screens/login_screen.dart`: password:73,
response:86, _NetworkChip:507, _SocialBtn:524. Không sửa unrelated warning.

SQL regression opt-in privileged `payment.test_mode='local_disposable'`, fixture
namespace kiểm trước, cuối ROLLBACK. Sequence advances không rollback: chỉ chạy
disposable. Engine RAM PGlite 0.5.8/PostgreSQL 18.3, auth/storage/roles giả lập.
Fixture fault injection cho expiry/cash-method khôi phục row guard ngay sau khi
đặt trạng thái để test fail-closed; không nới API quyền. Atomic rollback tests
ép event/audit constraint failure, sau đó verify không có orphan receipt/paid.

Các suite cũ chứa stage assertions nên chạy nguyên bản tại đúng migration stage;
sau GD6C chạy lại GD6B cash/QR và GD4. Không sửa assertion cũ để giả pass.

```powershell
# Chạy nguyên source; không thay SQL trong RAM.
node tools/check_payment_bank_verification.mjs --shared-only
node tools/check_payment_bank_verification.mjs
node --test backend/supabase/functions/bank-webhook/boundary_test.ts

# Native disposable PostgreSQL riêng, psql trên PATH; credentials chỉ env local.
# GD6C_NATIVE_TEST_URL phải loopback /postgres, không URL production.
node tools/check_payment_bank_verification_concurrency.mjs
```

Native runner chỉ tạo database random `gd6c_test_<hex>`, chạy migrations/fixtures
trong database đó và drop đúng database vừa tạo khi xong; không migrate database
được truyền vào. Chỉ dùng cluster disposable: test có thể tạo roles anon/
authenticated/service_role nếu thiếu. Race cases: identical delivery, different
event cùng transaction, hai transaction cùng payment, getter trong lúc commit.
Không cấu hình native URL -> NOT RUN, không tự tìm hoặc dùng credential production.

Log ignored: `tools/.work/gd6c_sql_shared.log`, `gd6c_sql_full.log`,
`gd6c_flutter_test.log`, `gd6c_flutter_analyze.log`.

## Deployment requirements và phần còn lại

Migration GD6C apply sau GD6B và prerequisites đã review. Source GD6B đã được sửa
typo tối thiểu theo yêu cầu user và chạy sạch. Migration không seed provider/account/secrets,
không enable verification, không thay default privileges.

Chưa được mở production auto-paid khi mới có source engine: cần real provider
adapter + official signature/auth fixtures, server secrets, scope/beneficiary
binding, reviewed DB role/transport, real acknowledgement/retry policy, native
concurrency tests và staging E2E. Lỗi auth reject; DB transient rollback trả
provider retry phù hợp; authenticated unmatched lưu outcome để review. Không
tự ACK conflict như đã paid. Hiện endpoint 503 cho mọi POST hợp lệ.

GD6D còn Bank Verifying/Paid visual polish dựa authoritative DTO; không biến UI
thành bằng chứng tiền. Provider integration, late/unmatched reconciliation,
multi-account rotation, operational monitoring/rate limits và manual review
không được coi đã hoàn tất bởi GD6D UI.

**KHÔNG DEPLOY. KHÔNG TẠO SECRET PRODUCTION. KHÔNG GỌI NGÂN HÀNG THẬT.
KHÔNG GỬI TIỀN. KHÔNG COMMIT.**
