# Backend người cứu hộ: bản local để review

Ngày: 2026-10-03. Chưa áp migration, chưa kết nối Supabase thật, chưa nối backend
vào Flutter và chưa commit. Không sửa `frontend/customer_app`, `frontend/rescuer_app`
hoặc sáu migration khách hàng. Không chạy `db push`, không dùng service_role trong Flutter.

## Trạng thái khi tiếp tục

`git status --short` ban đầu có README backend đã sửa và hai file chưa theo dõi:
kế hoạch rescuer và migration foundation. Foundation đã có 11 bảng, CHECK/FK/index,
RLS owner-read/default-deny và helper, nhưng thiếu RPC nghiệp vụ, hook/consistency,
REVOKE EXECUTE và COMMIT. Kế hoạch/README vẫn ghi chưa tạo migration.

## Đã bổ sung

- Hoàn thiện `202610020001_rescuer_backend_foundation.sql` trong một transaction,
  lock timeout 5 giây, preflight schema và ACL chỉ cho function mới có prefix rescuer.
- Đủ 18 RPC trong bảng endpoint của kế hoạch: hồ sơ, nộp giấy tờ, xe/capability,
  online/session/vị trí, discovery/detail coarse, claim, active job, trạng thái,
  báo giá và history. Mọi function đặt search_path rỗng; helper private không có
  EXECUTE cho PUBLIC/anon/authenticated. Endpoint public chỉ cấp authenticated.
- Mutation khóa theo UID/profile, dùng operation_id/payload hash/receipt và version.
  Claim khóa request, unique request và unique rescuer active để chống nhận trùng.
  Retry trả dữ liệu hiện tại; không cache PII trong receipt.
- Fine status giữ ở assignment; coarse request dùng vocabulary khách cũ.
  Hủy từ RPC khách đồng bộ assignment/event trong cùng transaction. Deferred
  constraints kiểm tra provider/status/quote; đơn legacy không assignment không backfill.
- Quote tính tổng bigint rồi kiểm tra giới hạn integer VND; revision supersede,
  trigger chặn sửa nội dung/xóa quote, completion cần quote và đóng băng tham chiếu.
  Không tạo payment hoặc consent khách giả.
- Discovery chỉ trả DTO 5 field, dùng cell centre cho distance/filter/rank,
  cursor gắn session/sequence. Active-detail kiểm tra approved/own active;
  history và retry quote terminal không trả contact/GPS/địa chỉ/note.
- Bucket `rescuer-documents` private, reserve/complete kiểm tra Storage metadata,
  policies permissive + restrictive theo owner, không UPDATE/DELETE hay anon.
  Ảnh đơn khách vẫn đóng với rescuer; không sửa policies bucket ảnh khách.
- `tests/check_rescuer_sql.py`: parser offline SQL, thân SQL/PLpgSQL, endpoint
  inventory/search_path và cú pháp regression. Không gọi DB/network.
- `tests/rescuer_local_regression.sql`: fixture tổng hợp trong transaction rollback,
  test quyền owner/direct write, GPS replay, discovery privacy, idempotency/version,
  lifecycle, quote overflow/tổng, terminal privacy và customer cancellation.
  Fixture approved chỉ nằm trong test local, không seed hoặc RPC admin.

## Lựa chọn trong bản nháp cần chốt

| Lựa chọn local | Giá trị/hành vi |
|---|---|
| Điện thoại | Dấu `+` tùy chọn, 8–15 chữ số; không tự xác minh |
| Biển số | Client gửi dạng uppercase alphanumeric 1–20 ký tự; unique theo owner |
| Duyệt lại | Sửa profile/xe đưa về draft; không sửa khi busy; xe reset capability về submitted |
| Capability | Bật lại capability đã tắt yêu cầu submitted; không tự giữ approval |
| Submit profile | Có identity, license và registration cho ít nhất một xe active đã upload; chỉ submitted |
| Giấy tờ | JPEG/PNG/PDF tối đa 10 MiB; tối đa 30 bản/UID; chưa có cleanup/retention |
| Discovery | Grid 0.01 độ, bán kính cố định 30 km, distance làm tròn 1 km, limit 1–50 |
| Freshness | Heartbeat/received_at/captured_at trong 120 giây; accuracy ≤100 m |
| GPS upload | Captured trong 5 phút, tương lai ≤30 giây, accuracy lưu tối đa 10000 m |
| Limiter | Theo UID, cửa sổ 1 phút; tối đa 29 lượt thành công cho discovery/detail/claim |

Limiter cập nhật cùng transaction: request bị lỗi rollback không tiêu lượt. Không
coi đây là cơ chế chống abuse hoàn chỉnh. GPS có thể bị giả, chưa có phát hiện
dịch chuyển bất thường hoặc limiter độc lập ngoài transaction. Document completion
chỉ xác nhận object/MIME/size do Storage ghi; không xác minh nội dung, scan virus
hay tính thật của giấy tờ. Trusted approval/expiry enforcement và xử lý suspension
giữa job vẫn cần workflow riêng. Không có endpoint admin trong migration.

## Lệnh và kiểm tra

Đã chạy `git status --short`, đọc SQL/docs bằng `Get-Content -Encoding UTF8`,
liệt kê/tìm bằng `rg --files`/`rg -n`, `Get-Command docker,psql,supabase`,
`docker info --format '{{.ServerVersion}}'`, `git diff --check`.
Không tìm thấy AGENTS.md trong repository.

Sandbox chạy shell lỗi `helper_unknown_error: setup refresh had errors`; đọc/kiểm
tra shell sau đó dùng quyền ngoài sandbox được duyệt. Không phải lỗi SQL.

Docker CLI có, daemon không hoạt động: không tìm thấy pipe
`dockerDesktopLinuxEngine`. Không tìm thấy `psql` hoặc Supabase CLI trên PATH.
Vì vậy chưa test DB local, RLS/API/Storage runtime hoặc concurrency.

Đã cài `pglast 8.4` vào `$env:TEMP\rescuer-sql-review-tools` bằng:

```powershell
python -m pip install --target "$env:TEMP\rescuer-sql-review-tools" pglast --no-cache-dir --disable-pip-version-check
python backend/supabase/tests/check_rescuer_sql.py --parser-path "$env:TEMP\rescuer-sql-review-tools"
```

Kết quả cuối: **PASS 108 statement SQL, 29 function PL/pgSQL, 11 thân function SQL,
18 RPC public, search_path rỗng ở mọi function; PASS cú pháp 28 statement trong
regression** (bỏ directives psql để parse). `git diff --check` qua; kiểm tra diff hai
frontend không có thay đổi. Đây không phải kết quả test DB. Lần gọi wrapper
`parse_plpgsql` toàn file lỗi JSONDecodeError trên kết
quả parser; checker dùng parser raw riêng từng function để tránh lỗi decoder.
Một lệnh Python inline cũng lỗi quoting PowerShell và được thay bằng script file.
Pip có warning distribution `-andas` sẵn có trong Python; cài pglast thành công.

## Còn thiếu và bước tiếp theo

1. Khởi động Docker Linux engine và chuẩn bị Supabase DB **local dùng riêng** có Auth,
   Storage, roles, auth.uid và sáu migration cũ. Không dùng PostgreSQL trống để giả
   rằng test Storage/RLS đã đủ; không nối project Supabase thật.
2. Áp các file SQL lên DB local dùng riêng, chạy regression và force deferred
   constraints. Test script yêu cầu `-v rescuer_local_test=1`; guard là xác nhận
   chủ động, không tự nhận biết host. Kiểm tra URL trỏ local trước khi chạy:

   ```powershell
   psql "$env:RESCUER_LOCAL_DB_URL" -X -v ON_ERROR_STOP=1 -v rescuer_local_test=1 -f backend/supabase/tests/rescuer_local_regression.sql
   ```

   Đây là lệnh cho bước sau, **chưa chạy**. Test tạo users/approval tổng hợp rồi
   rollback; không dùng tài khoản thật. Cú pháp parser không giải quyết tên/type
   thực trong catalog; phải kiểm tra DB local trước áp dụng.
3. Bổ sung test hai connection: hai rescuer cùng request, một rescuer hai request,
   customer cancel vs claim/status/quote, lock timeout và profile/capability update.
   Regression một connection chưa chứng minh tính đúng của cạnh tranh transaction.
4. Test Storage API thật local: upload MIME/size sai, pending/completed object,
   cross-owner/anon/direct upsert/delete, policies restrictive của toàn schema.
   Kiểm tra EXPLAIN/load discovery và giới hạn request/statement timeout tại gateway.
5. Chốt nguồn phê duyệt, expiry/retention/account deletion, consent quote, đơn không
   GPS, chống fake GPS/abuse và gateway ảnh trước rollout. Preflight hiện kiểm tra
   những tiền đề quan trọng, chưa thay thế kiểm kê toàn bộ schema/policy/function body.

Không deploy/commit tự động. Review SQL và hoàn thành ma trận ở kế hoạch trước khi
xem xét bất kỳ thay đổi DB thật nào.
