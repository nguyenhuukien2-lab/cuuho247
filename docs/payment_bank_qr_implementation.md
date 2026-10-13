# GD6B — Customer Bank QR / Bank Transfer

Ngày 11/10/2026. Source implementation; **không deploy, không commit**. Không sửa rescuer app, Admin UI hoặc các migration GD1–GD6A.

## Quyết định trước triển khai

Đã đọc sáu migration payment được chỉ định, GD6A implementation, Stitch review và cash UI implementation; rà soát customer service/controller/watcher/UI, source backend và tên biến cấu hình `.env` (không xuất giá trị secrets). Không tìm thấy provider API hoặc beneficiary production trong repo/config hiện có. Không suy ra cấu hình database live từ source, không kết nối database live.

Chọn **VietQR chuyển vào tài khoản, backend tạo EMV TLV + CRC16**, Flutter dùng `qr_flutter 4.1.0` để vẽ nguyên payload nhận từ safe getter. Không gọi external QR provider; không key, ảnh placeholder, fake fallback hay account frontend constant. Việc tạo QR chỉ cung cấp chỉ dẫn chuyển khoản, **không xác minh tiền**.

Tham khảo định dạng: [EMVCo QR](https://www.emvco.com/emv-technologies/qr-codes/), [source triển khai VietQR](https://github.com/subiz/vietqr), [QR.Flutter](https://pub.dev/packages/qr_flutter). Đây không phải chứng nhận NAPAS/EMVCo hoặc bằng chứng đã thử quét bằng ứng dụng ngân hàng thật. Không đưa logo/chứng nhận hoặc lời hứa nhận tiền sau 10–30 giây từ Stitch vào app.

## Migration và beneficiary config

Migration mới: `backend/supabase/migrations/202610110002_payment_bank_qr.sql`, áp thủ công **sau** `202610110001_payment_bank_foundation.sql` và prerequisites của nó. Migration chạy trong transaction, có preflight RLS/publication, lock/statement timeout và từ chối chạy lại. Không sửa file migration cũ.

Source of truth: **`private.payment_bank_config`**, singleton, DB owner quản lý qua quy trình server-side. Không cung cấp customer/admin UI config RPC. Không seed bất kỳ beneficiary nào; không có row hoặc `enabled=false` → unavailable. Các trường bắt buộc:

| Field | Policy |
| --- | --- |
| `bank_bin` | 6 chữ số; owner phải đối chiếu BIN ngân hàng nhận tiền thực tế |
| `bank_code`, `bank_name` | Code và tên thật của ngân hàng nhận tiền |
| `account_number` | 6–19 chữ số, bảo toàn leading zeros; giới hạn có chủ đích của adapter GD6B |
| `account_name` | Tên chủ tài khoản thật, 3–120 ký tự; hiển thị theo snapshot, không tự xác minh tên |
| `reference_policy` | Chỉ `bank_sequence_v1`; không có arbitrary template/customer input |
| `expiry_seconds` | 60–86400, mặc định 900 giây, policy cho intent tạo mới |
| `enabled` | Mặc định false; chỉ bật sau khi kiểm tra beneficiary và QR trên bank app phù hợp |
| `version` | Server trigger quản lý, tăng khi cập nhật config |

Không cần provider/API/webhook secret cho chiến lược này. Không thêm service_role hoặc private token vào Flutter. Schema format validation không chứng minh tài khoản có thật; người quản trị phải điền beneficiary đã xác minh trước khi enable. Không cung cấp SQL seed chứa số tài khoản mẫu dễ bị chạy nhầm.

Snapshot beneficiary/QR nằm trong **`private.payment_bank_qr_snapshots`**, FK 1:1 vào intent GD6A. Snapshot chứa config version, BIN/code/name, account number/name, transfer content và QR payload; bất biến sau INSERT, không UPDATE/DELETE/TRUNCATE. Thay config không đổi beneficiary của intent đã phát hành. Khi xoay tài khoản cần tiếp tục xử lý các nghĩa vụ đang gắn tài khoản cũ; `enabled=false` cũng ẩn QR hiện hữu nhưng không hoàn tác một lệnh chuyển tiền ngoài ngân hàng.

## RPC contract

```sql
public.customer_get_bank_capability(p_request_id uuid) returns jsonb
public.customer_select_bank_transfer(
  p_request_id uuid,
  p_payment_id uuid,
  p_expected_version bigint,
  p_operation_id uuid
) returns jsonb
public.customer_get_bank_payment(p_request_id uuid) returns jsonb
```

Capability trả đúng `{available: boolean}` sau auth/ownership check. Chỉ true khi config enabled, request completed, payment pending/method NULL, VND, amount hỗ trợ và không có active intent không thể sử dụng. Missing RPC/network/invalid capability response → frontend bank disabled; cash vẫn dùng contract cũ.

Select trả `{payment: <GD2A safe DTO>, changed: boolean}`. Input không nhận amount, beneficiary, reference, expiry, provider hay status. Check auth.uid, request/payment ownership, positive amount, VND, enabled config, eligibility/version và idempotency. Amount trên 13 chữ số bị từ chối vì giới hạn EMV amount. Không tạo intent cho paid/cancelled/refunded/cash-selected payment.

Select mới khóa operation → helper operation → owned request → assignment → payment → config/intent; tạo/reuse intent, snapshot QR, ready intent, payment method/status/version, safe event và receipt trong cùng transaction. Không network I/O trong transaction. RPC cash hiện tại và getter GD2A giữ nguyên definition/ACL; migration mới mở rộng payment guard đúng nhánh bank pending → awaiting và giữ nguyên cash collection guard.

Receipt dùng chung `private.payment_rpc_receipts` với cash, mở rộng CHECK operation_name trong migration mới. Same actor + operation ID + exact payload trả acknowledgement đã lưu, kể cả sau expiry/config disable; đổi request/payment/version/operation kind cùng key → conflict. Receipt replay không cấp QR cũ: frontend luôn gọi getter hiện tại. New key trên payment đã chọn bank bị từ chối; không tạo nghĩa vụ thứ hai.

Safe bank getter chỉ trả:

```text
payment_id, payment_code, request_id,
payment_status, payment_method, amount_expected, currency,
bank_intent_status, bank_reference,
bank_code, bank_bin, bank_name, account_number, account_name,
transfer_content, expires_at, server_time, available, qr_payload,
version, bank_intent_version
```

Money/version là decimal strings để bảo toàn bigint trên Flutter web. `version` là public payment version; `bank_intent_version` là intent version. Không raw webhook/body, signature, provider metadata/secret, internal audit fields hoặc config version. Getter chỉ dành customer owner; cash/no bank payment trả SQL NULL, không tạo/mutate payment. CH code lấy từ owned request details đúng request ID, không tự dựng.

## Intent, reference và QR

Giữ nguyên GD6A helper `private.payment_bank_create_intent(uuid,uuid,timestamptz)` và reference **`BK-` + 32 hex UUID**. Reservation `created` chưa phát hành có thể reuse nếu còn thời hạn; giữ nguyên reference/expiry của reservation cũ. Intent mới lấy TTL từ config. Không gia hạn hoặc tự thay thế active intent đã expired; fail closed. Partial unique index GD6A tiếp tục bảo đảm một active intent/payment.

Reference GD6A dài 35 ký tự, không đưa trực tiếp vào trường purpose giới hạn 25. `private.payment_bank_transfer_seq` tạo **`BK` + 19 chữ số**, tổng 21 ASCII ký tự, là `transfer_content` duy nhất và bất biến, map 1:1 qua snapshot tới intent/reference/payment. Đây là reference gửi ngân hàng; không chứa secret và không phải credential. GD6C phải exact-match đầy đủ transfer_content, không fuzzy/amount-only match. Không sửa/truncate reference cũ. Retry giữ nguyên snapshot/reference/content.

QR payload backend:

- `00=01`, `01=12` (transaction-specific payload).
- `38.00=A000000727`; `38.01.00=bank_bin`, `38.01.01=account_number`; `38.02=QRIBFTTA`.
- `53=704`, `54=amount_expected` nguyên VND, `58=VN`.
- `62.08=transfer_content`.
- `63`: CRC16/CCITT-FALSE, init `FFFF`, polynomial `1021`, bao gồm `6304` trước checksum.

Không dùng account_name để giả xác minh tài khoản; bank BIN/account xác định đích chuyển. Flutter không lắp ghép các field này thành payload, không có control sửa amount/reference. Ảnh QR thực được `QrImageView` render từ chuỗi server, có white quiet zone và không chèn logo. **QR thật khi có config thật, không có mock runtime.** Fixture giả chỉ nằm trong tests, rollback-only.

QR không phải một token được ngân hàng thu hồi/khóa số tiền. Người dùng ngoài app vẫn có thể sửa giao dịch trong bank app hoặc dùng ảnh QR cũ; GD6C phải đối chiếu amount/reference/beneficiary/expiry và xử lý late transfers. Không claim `01=12` tự ngăn quét lại hoặc tự chứng minh đã trả tiền.

Lifecycle: absent → `created` → `ready` trong transaction chọn bank; public payment `pending` → `bank_transfer/awaiting_payment`, version +1. Bank audit GD6A ghi version changes; public event `bank_qr_created` chỉ metadata phương thức an toàn. Không mở matched/verified/paid. Trusted internal lifecycle có thể close ready → expired/cancelled/failed, version +1; không có customer cancellation/switch RPC.

## Expiry và method switching

Safe getter tính **effective expired** theo `statement_timestamp()` khi expires_at đã qua. Getter không cập nhật payment/intent hoặc phát event; stored ready vẫn giữ active slot cho tới explicit backend lifecycle/reconciliation sau này. Khi expired, cancelled, config disabled hoặc payment không awaiting, getter không trả usable QR. Không có renewal trong GD6B.

UI countdown lấy `expires_at - server_time`, chỉ hiển thị. Hết countdown thì ẩn QR, refetch public getter rồi bank getter và đợi trạng thái server; không gán payment failed/paid/verifying. Không dùng giờ thiết bị để quyết định nghiệp vụ.

**Không chuyển cash → bank hoặc bank → cash.** Chỉ pending/method NULL được chọn một lần. Lựa chọn phương thức không tạo paid. Retry sau network outcome không rõ giữ nguyên operation payload; controller chặn chọn phương thức khác trong lúc outcome còn chưa xác định. Điều này tránh cash + bank cùng được đưa ra như hai nghĩa vụ thanh toán. Reservation GD6A created chưa phát hành vẫn không phá cash cũ.

## Customer UI và realtime

- `PaymentScreen` giữ route requestId/controller/owner pin hiện tại.
- Stitch **Customer Payment Method `83d8804a503246e2bf3e89baf949da16`**: bank card chỉ enable từ backend capability, dữ liệu fresh, không submitting/acknowledged/uncertain-cash. Sheet xác nhận phương thức hiển thị số tiền thật; nút tạo QR không xác nhận thanh toán.
- Stitch **Customer Bank QR `bd756e87ab6a4299876b1ef8d40c649d`**: `BankPaymentSection`, scoped palette/type/card/header của payment, QR tối đa 280, summary amount/TT/CH, beneficiary, copy account/content, server expiry và trạng thái. Không account/amount mẫu Stitch, hotline giả hoặc thông tin webhook kỹ thuật.
- Loading, ready/awaiting, expired, cancelled, unavailable, error, offline/stale được xử lý. Verifying chỉ đọc từ backend; bank-paid full flow giữ fallback cũ, thuộc giai đoạn sau. Cash Awaiting/Cash Paid không đổi logic.
- Copy await `Clipboard.setData`; thành công mới báo “Đã sao chép”, failure báo lỗi thật. QR và copy disabled khi stale/loading/error/expired/unavailable.
- “Kiểm tra thanh toán” và “Cập nhật thanh toán” chỉ refetch getter. Không “Tôi đã chuyển khoản” hoặc customer mark-paid.
- Reuse duy nhất GD4 `PaymentWatcher` và subscription `public.payments`; raw INSERT/UPDATE chỉ invalidation → `customer_get_payment` → bank getter/capability. Không subscription/query trực tiếp private tables hoặc payment_events.
- Bank DTO phải match payment ID/request/code/amount/currency/method/status/version đã đọc. Response lỗi, sai scope, khác version hoặc auth đã đổi không được render QR. Scope/generation cleanup và reconnect/resume reuse watcher cũ. Bank refresh failure không biến cash thành lỗi nghiệp vụ.
- Single-flight commands chống double tap; timeout giữ exact operationId/version/paymentId trong RAM. Definitive version conflict bỏ attempt, refetch, lần chọn mới dùng version mới. Operation IDs không persist qua process restart; sau restart getter/backend locks/idempotency vẫn là authority.

## Kiểm thử

SQL: `backend/supabase/tests/payment_bank_qr_regression.sql`, opt-in `payment.test_mode='local_disposable'`, privileged disposable DB only, cuối file ROLLBACK. Không chạy trên production vì sequence advances không rollback.

Runner versionable: `tools/check_payment_bank_qr.mjs`. Dùng PGlite đã có tại `.cache_rescuer/temp/payment-core-security/node_modules`, PostgreSQL 18.3 / PGlite 0.5.8, database mới trong RAM; auth/storage/roles fixture mô phỏng, không URL DB/network client.

```powershell
node tools/check_payment_bank_qr.mjs
node tools/check_payment_bank_qr.mjs --shared-only
```

GD1–GD6A suites nguyên bản chạy tại đúng migration stage vì có assertions “phase sau chưa tồn tại”. GD6B suite chạy trên schema cuối, gồm cash select/confirm/exact retry và method-switch denial; GD4 suite chạy lại sau GD6B. Runner còn so definition/ACL của cash RPC và getter GD2A, parse QR TLV bằng decoder độc lập, kiểm amount boundary/BIN/account/reference/CRC known vector.

SQL coverage: owner/enabled; absent/disabled config; unrelated/anon/auth missing; request/payment binding; amount từ payment; reference server; exact retry/conflict; single active intent; version conflict; cash regression; paid/cancelled/refunded/zero denial; no auto paid; effective server expiry; immutable snapshot và config rotation; rollback khi event append lỗi; private table permissions/RLS; safe DTO exact allowlist; no private/events publication; no webhook ingest.

Flutter: `test/payment_bank_test.dart` thêm 31 tests controller/HTTP/widget. Existing cash/realtime HTTP mocks nhận diện capability getter mới để không tính nó là mutation; giữ các assertions cash/realtime cũ. Coverage bank card gating, sheet/loading/double tap, exact params, timeout retry, version conflict, payload/amount/bank display, copy/failure, refresh-only, expired/cancelled/failed, countdown refetch, offline/stale, unavailable, auth cleanup/late response, wrong snapshot, raw paid invalidation, read-only verifying, width 320/390/480 với text scale 2.

Kết quả cuối:

| Kiểm tra | Kết quả |
| --- | --- |
| GD1 / GD2A / GD2B / GD3 nguyên bản tại migration stage | 114 / 72 / 91 / 122 assertions PASS, cả hai cấu hình |
| GD6A nguyên bản trước GD6B | 170 assertions PASS, hai lần/cấu hình |
| GD6B trên schema cuối | **84 assertions PASS**, hai lần/cấu hình; có cash select/confirm/retry và switch denial |
| GD4 sau GD6B | 27 assertions PASS, cả hai cấu hình |
| Cash RPC definition/ACL unchanged + decoder QR độc lập | PASS, cả hai cấu hình |
| `flutter test --no-pub --reporter expanded` | **569 passed, 0 failed**; lượt cuối 01:22 |
| `flutter analyze --no-pub` | **0 errors, 4 warnings cũ**, exit 1 do warnings |
| `git diff --check` và hash phạm vi tác vụ | PASS; migration cũ/rescuer/admin không đổi |

4 warnings giữ nguyên ở `lib/screens/login_screen.dart`: `password` dòng 73, `response` dòng 86, `_NetworkChip` dòng 507, `_SocialBtn` dòng 524. Không sửa warning unrelated. Hai dependency thêm là `qr_flutter 4.1.0` và `qr 3.0.2`; lockfile không nâng cấp dependency khác.

Log local ignored: `.cache_rescuer/temp/payment-core-security/gd6b_flutter_full.log`, `gd6b_analyze.log`. Đã chạy `flutter pub get` trước `--no-pub`, bằng cache tạm trong workspace. Không tuyên bố các widget mock tests là kiểm thử live Supabase hoặc quét QR trên bank app.

## Security và phần còn lại

Tất cả public RPC mới `SECURITY DEFINER SET search_path=''`, schema-qualified, auth/ownership checks, revoke PUBLIC/anon/service_role, chỉ grant exact EXECUTE cho authenticated. Private helpers SECURITY INVOKER, không API grants. Hai bảng private mới bật RLS, không policies; table/sequence/function ACL mặc định rộng được revoke. Không thay participant RLS của payments hoặc public columns; private tables và payment_events không publish.

GD6C còn: provider thật/server secrets, webhook endpoint/signature verification, receipt/transaction ingest/deduplication, normalize/match transfer reference + exact amount/beneficiary/currency, late/partial/overpayment policy, verified bank transition và atomic settlement/paid. **Không triển khai bất kỳ phần nào trong số này ở GD6B.** GD6D còn full Bank Verifying/Paid flow.

Chưa chạy native PostgreSQL nhiều connection, Supabase Auth/JWT/PostgREST/Realtime server thật, scan thử bằng ứng dụng ngân hàng hoặc golden pixel comparison Stitch. Cần kiểm concurrency cash-select vs bank-select và same/different operation retries trong môi trường disposable thực; unique constraints/transaction locks đã được kiểm logic và test single-session RAM, không giả là concurrency thực nghiệm.

## Files thuộc tác vụ

- `backend/supabase/migrations/202610110002_payment_bank_qr.sql` — mới.
- `backend/supabase/tests/payment_bank_qr_regression.sql` — mới.
- `tools/check_payment_bank_qr.mjs` — mới.
- `frontend/customer_app/lib/models/bank_payment_dto.dart` — mới.
- `frontend/customer_app/lib/widgets/bank_payment_ui.dart` — mới.
- `frontend/customer_app/lib/services/payment_service.dart`.
- `frontend/customer_app/lib/app/payment_watcher.dart`.
- `frontend/customer_app/lib/app/app_controller.dart`.
- `frontend/customer_app/lib/screens/payment_screen.dart`.
- `frontend/customer_app/lib/widgets/payment_ui.dart`.
- `frontend/customer_app/pubspec.yaml`, `pubspec.lock` — chỉ thêm QR renderer và dependency `qr`, giữ phiên bản dependency khác.
- `frontend/customer_app/test/payment_bank_test.dart` — mới.
- `frontend/customer_app/test/payment_commands_test.dart`.
- `frontend/customer_app/test/payment_realtime_test.dart`.
- `docs/payment_bank_qr_implementation.md` — báo cáo này.

Workspace vốn có nhiều thay đổi trước GD6B. Không dùng toàn bộ git diff làm danh sách tác vụ; đối chiếu hashes trước/sau. Cache/log/build artifacts local ignored dưới `.cache_rescuer` chỉ phục vụ kiểm thử. Cache Pub mặc định bị Windows từ chối ghi; dùng `PUB_CACHE` tạm trong workspace, không nâng cấp Flutter SDK.
