# Admin Payment Operations V2

Cập nhật: 13/10/2026. Đây là thiết kế và hướng dẫn vận hành cho chức năng đối soát,
late payment và refund. Thay đổi này chưa được deploy và không thay đổi webhook/processor
SePay Live.

## Phạm vi triển khai

Migration additive `202610130003_admin_payment_operations_v2.sql` tạo bốn bảng private:

- `payment_reconciliation_cases`: quyết định cuối cho một bank transaction late;
- `payment_refunds`: refund ledger và state machine độc lập với payment gốc;
- `payment_operations_audit`: timeline append-only cho reconciliation/refund;
- `payment_admin_operation_receipts`: idempotency receipt theo admin + operation UUID.

Không migration cũ nào bị sửa. Không RPC V2 nào cập nhật `public.payments`,
`payment_events`, bank transaction, webhook receipt hay bank intent. GD6C vẫn là đường duy
nhất có thể xác minh và settle bank payment.

## Kế hoạch và trạng thái triển khai

1. Audit schema/RPC/UI hiện hữu và giữ nguyên GD6A/GD6B/GD6C, regeneration và
   `bank-webhook` — hoàn tất.
2. Thêm private ledger, immutable audit, ACL/RLS và RPC read/write có kiểm soát — hoàn tất.
3. Thêm màn hình Admin “Vận hành thanh toán”, report, queue và refund controls — hoàn tất.
4. Thêm SQL/RPC/auth/idempotency/concurrency/UI regression — hoàn tất cục bộ.
5. Deploy migration/UI vào production — chưa thực hiện, ngoài phạm vi thay đổi này.

Thứ tự rollout sau khi được phê duyệt: backup schema/config, apply migration mới, chạy smoke
read RPC bằng finance test account, deploy Admin Web, rồi mới cho phép finance xử lý case.
Migration không phải điều kiện để webhook SePay Live tiếp tục settle; nếu UI rollout lỗi,
rollback Admin Web artifact và để các bảng/RPC mới không được sử dụng. Không rollback bằng
cách xóa audit/refund/reconciliation records.

## Hàng chờ đối soát và late payment

`admin_list_payment_reconciliation` chỉ đọc transaction `rejected` chưa matched, hỗ trợ
lọc ngày, trạng thái và reference/transaction/payment/request. DTO chỉ chứa allowlist:
rejection code, receipt ID/status/result, authentication flags, candidate payment/request và
version; không trả raw body, hash, header, signature, beneficiary account hay secret.

Candidate payment được suy ra server-side từ exact QR `transfer_content`; frontend không gửi
payment candidate. `admin_resolve_late_payment` chỉ chấp nhận `intent_expired` và kiểm tra lại:

- authenticated receipt và normalized evidence cùng transaction;
- credit direction;
- exact amount, currency và reference snapshot;
- exact beneficiary BIN/account snapshot;
- transaction version và chưa có reconciliation case.

Hai resolution V1 là `refund_required` và `dismissed`. Cả hai đều terminal, có server
timestamp và immutable audit. RPC tuyệt đối không mark paid hay gán transaction late vào
payment. Sai evidence, stale version, duplicate resolution hoặc thiếu candidate đều fail
closed.

## Refund state machine

```text
requested -> approved -> processing -> refunded
                                  \-> failed
```

- Refund không xóa payment gốc và không đổi lịch sử/status/amount của payment đã paid.
- Nguồn refund là `paid_payment` hoặc một `late_bank_transaction` đã được phân loại
  `refund_required`.
- Tổng refund đang giữ chỗ (`requested/approved/processing/refunded`) không được vượt amount
  đã nhận hoặc amount của late transaction.
- Người yêu cầu không thể tự approve/process/record result; RPC mutation khóa membership
  Admin và refund row trước khi chuyển trạng thái.
- `refunded` chỉ được ghi từ `processing` và bắt buộc evidence reference; `failed` bắt buộc
  failure code. Version phải exact ở mọi transition.
- V1 là manual operations ledger, chưa gọi API hoàn tiền ngân hàng. Vì vậy `refunded` nghĩa
  là một admin khác đã ghi nhận bằng chứng thao tác ngân hàng, không phải xác nhận tự động từ
  ngân hàng. Khi có payout/refund API, adapter server-side phải thay phần manual attestation;
  frontend không được nhận credential hoặc tự đặt trạng thái.

Mỗi mutation nhận operation UUID. Replay cùng actor + UUID + payload trả lại response cũ;
cùng UUID với payload khác trả `IDEMPOTENCY_CONFLICT`.

## Authorization và audit

- Chỉ Admin `finance` hoặc `super_admin` active được gọi RPC.
- Mutation dùng `private.admin_require_role`, có row lock trên membership để tránh concurrent
  demotion; read RPC dùng readonly guard.
- Tất cả RPC V2 là `SECURITY DEFINER SET search_path=''` và mọi object/function reference
  nhạy cảm đều schema-qualified.
- Bảng private bật RLS và revoke direct access từ `public`, `anon`, `authenticated` và
  `service_role`; frontend chỉ gọi RPC.
- Audit/operation receipt không update/delete/truncate. Timestamp và actor lấy server-side.
- Unified timeline gộp payment events, bank audit và operations audit qua
  `admin_get_payment_operations_timeline`.

## Report

`admin_get_payment_operations_report` dùng khoảng `[from,to)` và server timestamp, tối đa
366 ngày. Báo cáo gồm tổng bank/cash đã paid, số paid/unpaid, rejected transaction, late
payment, tổng refund hoàn tất và số refund đang mở. Các con số là aggregate server-side,
không cộng từ page hiện tại trên frontend.

## Kiểm thử cục bộ

```powershell
node tools/check_admin_payment_readonly.mjs
node --test backend/supabase/functions/bank-webhook/*_test.ts
deno check backend/supabase/functions/bank-webhook/index.ts
node tools/check_payment_bank_verification.mjs

cd admin_web
npm run lint
npm run build
npx playwright test tests/payments.spec.ts
```

SQL fixture chỉ chạy trong disposable database với opt-in `payment.test_mode=local_disposable`.
Không test nào tạo dữ liệu production hoặc gọi ngân hàng thật.

## Incident rules

- Không dùng reconciliation/refund RPC để chữa một lỗi webhook; giữ evidence và sửa adapter.
- Không chuyển late payment sang paid thủ công. Tạo refund case hoặc dismiss với reason code
  sau khi điều tra.
- Khi gặp stale version, tải lại queue/timeline; không sửa version trong DB.
- Khi kết quả hoàn tiền chưa rõ, giữ `processing`; không ghi `refunded` nếu thiếu bằng chứng.
- Không xóa record để retry. Dùng operation UUID cũ khi retry cùng request sau network error.

Live cutover và Test Mode mapping vẫn tuân theo
[`sepay_live_cutover_runbook.md`](sepay_live_cutover_runbook.md) và
[`payment_provider_integration.md`](payment_provider_integration.md). Test mapping không phải
bằng chứng beneficiary Live.
