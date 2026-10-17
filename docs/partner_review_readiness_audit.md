# Kiểm duyệt đối tác và readiness — 2026-10-17

Đã audit Supabase liên kết `mqnnzobfzbtolvmatuwr` bằng truy vấn `BEGIN READ ONLY … ROLLBACK`, đọc source và kiểm thử trên Docker local. **Không deploy, không áp migration lên Supabase thật, không duyệt/từ chối tài khoản thật, không commit/tag, không sửa Customer App.** Các thay đổi có sẵn trong workspace được giữ nguyên.

## Kết quả audit backend thật

| Thành phần hiện có | Vai trò |
| --- | --- |
| `rescuer_profiles` | Hồ sơ; `verification_status`, version, người/thời điểm duyệt |
| `rescuer_documents` | `identity`, `license`, `vehicle_registration`; upload, hạn sử dụng, đường dẫn private |
| `rescuer_vehicles` | Xe, biển số, loại xe, trạng thái, active, version |
| `rescuer_service_capabilities` | Liên kết xe + dịch vụ + loại xe khách; trạng thái và enabled |
| `rescue_services` | Danh mục và công tắc dịch vụ hệ thống |
| `rescuer_online_status`, `rescuer_locations` | Phiên Online, xe đang dùng, heartbeat và GPS |
| `rescue_request_assignments` | Đơn đang làm; ràng buộc mỗi rescuer một đơn active |
| `admin_profiles`, `admin_audit_logs` | Vai trò Admin, lịch sử thao tác và lý do |
| `private.system_config`, `private.system_account_controls` | Công tắc vận hành, khóa tài khoản/thu hồi phiên |
| `admin_rescuers_view` | Hồ sơ tổng hợp đang dùng trong Admin |
| `admin_rescuer_documents_view` | Đã tồn tại, chỉ metadata; dành cho `super_admin`/`partner_reviewer` |
| `admin_approve_rescuer`, `admin_reject_rescuer`, `admin_block_rescuer` | Chỉ đổi trạng thái hồ sơ chính qua `private.admin_change_rescuer` |
| `rescuer_reserve_document`, `rescuer_complete_document` | Giữ chỗ/upload và xác nhận object thật |
| `rescuer_submit_profile` | Gửi duyệt hồ sơ; upload thành công chưa đồng nghĩa approved |
| `rescuer_set_online`, `rescuer_update_location` | Online và cập nhật GPS |
| `rescuer_list_available_requests`, `rescuer_get_available_request`, `rescuer_claim_request` | Tìm/xem trước/nhận đơn |

Trạng thái thực tế của giấy tờ: `submitted / approved / rejected / expired`, không có `pending`. Giấy tờ có `uploaded_at=null` mới chỉ giữ chỗ. Xe/hồ sơ có thêm `draft`, `suspended`; capability có `submitted / approved / rejected / suspended`.

Catalog thật không có RPC duyệt giấy tờ, xe, capability hoặc readiness trước thay đổi này. Không tạo thêm bảng, cột, bucket hay mô hình hồ sơ song song. Migration mới bổ sung API và policy còn thiếu trên các đối tượng hiện hữu; lý do từ chối lưu vào `admin_audit_logs`.

Nguyên nhân Admin không thấy dữ liệu:

1. `RescuerDetailPage.tsx` chỉ tải `admin_rescuers_view`; hai section là placeholder viết cứng.
2. `admin_rescuer_documents_view` có dữ liệu nhưng UI chưa gọi.
3. Storage có cả permissive và restrictive owner policy; thêm nút tải hoặc chỉ thêm permissive policy sẽ vẫn không đủ quyền đọc file của partner khác.
4. `admin_approve_rescuer` cố ý không tự duyệt giấy tờ/xe/capability. Ba loại dữ liệu này vẫn `submitted` sau khi hồ sơ approved.
5. App trước đây tính checklist cục bộ và cho mục giấy tờ hoàn tất khi profile approved; danh sách xe eligible lại cần xe + capability approved. Điều này gây hiển thị dễ hiểu nhầm.

## Hai hồ sơ Nguyễn Hữu A hiện tại

| Mã | Hồ sơ | Giấy tờ | Xe | Capability |
| --- | --- | --- | --- | --- |
| `DT-000003` | `approved` | 3 file đã upload, đều `submitted`, chưa đặt hạn | 1 `service_motorbike`, active, `submitted` | 7 mục enabled, đều `submitted` |
| `DT-000004` | `draft` | Không có | Không có | Không có |

Các capability của `DT-000003`: towing, battery, tire, fuel, locksmith, mechanic, other. Duyệt theo nội dung thực tế và trạng thái danh mục; không suy diễn rằng một xe phù hợp tất cả dịch vụ đã chọn.

Cả hai không có bản ghi khóa trong `system_account_controls`. Lúc audit: `rescuer.maintenance=false`, `rescuer.online_enabled=true`, `security.kill_new_jobs=false`. Không đọc/in mật khẩu, token hoặc URL giấy tờ trong báo cáo. Chưa xác định app trên thiết bị hiện đăng nhập hồ sơ nào; cần đối chiếu mã thay vì tên.

## Điều kiện trước và sau thay đổi

Backend đang chạy trước migration:

- Approved chỉ là `rescuer_profiles.verification_status='approved'`.
- `private.rescuer_require_vehicle` chỉ kiểm tra profile approved + xe cùng owner, approved, active. `rescuer_set_online` dùng helper này; giấy tờ hết hạn chưa chặn Online.
- Nhận đơn còn cần Online đúng xe/session, idle, GPS/heartbeat đủ mới và capability approved/enabled phù hợp dịch vụ + loại xe khách; danh mục dịch vụ active.
- App cũ yêu cầu thêm capability approved/enabled để hiện xe eligible, nhưng chưa đọc checklist backend và chưa dùng giấy tờ approved để quyết định.

Sau migration local mới, cùng một helper `private.rescuer_review_readiness(uid)` được dùng bởi Admin, partner và gate backend:

1. Profile approved.
2. Có ít nhất một căn cước và một bằng lái đã upload, approved, không hết hạn.
3. Có xe cùng owner, active, approved.
4. Xe đó có ít nhất một đăng ký xe đã upload, approved, không hết hạn.
5. Xe đó có ít nhất một capability approved/enabled, danh mục dịch vụ active.
6. `can_online` còn xét hệ thống không bảo trì và cho phép Online. `eligible_vehicle_ids` được tính từ các điều kiện kiểm duyệt, không lưu thành cờ cấp quyền mới.

`can_receive_requests` xét thêm phiên Online đúng xe/session, không có đơn active, heartbeat/GPS `received_at`/`captured_at` trong 120 giây, accuracy ≤100 m, không bảo trì và không bật `kill_new_jobs`. Để nhận một đơn cụ thể, RPC vẫn kiểm tra: yêu cầu `searching`, chưa có provider/assignment, không phải đơn của chính mình, capability đúng dịch vụ và loại xe khách, dịch vụ active; đơn có GPS trong bán kính coarse 30 km, đơn không GPS có địa chỉ nhập tay theo migration hiện hữu. Giới hạn discovery vẫn giữ nguyên (lượt thứ 30 trong cửa sổ một phút bị chặn).

Mọi RPC vẫn chịu session guard: JWT hợp lệ, tài khoản không bị khóa/tạm ngưng còn hiệu lực, quy định tuổi/thu hồi token; Admin chịu MFA nếu cấu hình yêu cầu. GPS stale, session cũ, tranh chấp nhận đơn và các công tắc vận hành vẫn do RPC/trigger quyết định. Readiness đọc được không bảo đảm một lệnh nhận đơn sau đó sẽ thành công nếu dữ liệu thay đổi.

Không duyệt/từ chối khi partner đang làm đơn để tránh bỏ dở nghiệp vụ. Nếu giấy tờ hết hạn giữa đơn, cập nhật vị trí cho đúng xe của đơn đang làm vẫn được giữ; readiness nhận đơn mới chuyển false. Không tự động duyệt mọi capability hoặc mọi xe khi duyệt profile/document.

## API và bảo mật bổ sung

- `admin_get_rescuer_review(p_rescuer_id)`: toàn bộ metadata giấy tờ, lý do kiểm duyệt mới nhất, xe, dịch vụ đã chọn và readiness. Giữ API hồ sơ chính hiện hữu.
- `admin_review_rescuer_document`: quyết định + expected status; kiểm tra upload/object/hạn khi duyệt; bắt buộc lý do khi từ chối.
- `admin_review_rescuer_vehicle`: quyết định + expected version.
- `admin_review_rescuer_capability`: khóa tổng hợp xe/dịch vụ/loại xe khách + expected updated_at.
- Các mutation khóa role Admin và cùng advisory lock/profile row với mutation của partner, ghi audit, không cấp UPDATE trực tiếp; từ chối tắt Online, trạng thái cũ không khớp trả conflict.
- `rescuer_get_readiness()`: chỉ trả readiness của `auth.uid()`, không nhận UID từ partner. App thiếu RPC/đọc lỗi sẽ không tự suy ra quyền Online.
- `admin_can_read_rescuer_document(path)`: chỉ reviewer đang có session hợp lệ mới đọc file đã upload của partner khác. Policy restrictive được sửa tương ứng; quyền owner đọc/upload chính mình được giữ nguyên. Admin `operator`/`support`/`finance` không được duyệt hoặc đọc tài liệu đối tác.
- SDK `createSignedUrl(path, 60)` với JWT người dùng; không có service key trong Admin. Link chỉ nằm trong state của dialog, tự bỏ khi hết hạn/đóng dialog, tạo lại khi người dùng yêu cầu; không localStorage/log URL, token hay lỗi Storage thô. Bucket luôn private. Link mở với `noopener noreferrer` và `no-referrer`.

Signed URL là bearer link trong thời gian còn hạn; file đã tải xuống không thể thu hồi. TTL của chức năng này là 60 giây, không phải giới hạn toàn cục ép lên mọi client có quyền ký link. Cơ chế dùng quyền SELECT Storage theo [tài liệu Supabase createSignedUrl](https://supabase.com/docs/reference/javascript/storage-from-createsignedurl).

## Kiểm thử

- Chuỗi migration đầy đủ và các regression sẵn có: PASS trên DB riêng `partner_review_audit_20261017`; catalog security audit PASS.
- Regression mới: **38 assertions PASS**. Pending, duyệt lần lượt, reject + lý do, stale status/version, owner/non-admin/operator bị chặn, direct write bị chặn, reviewer đọc private objects, readiness, Online, GPS/discovery/claim, expiry, dịch vụ tắt, busy và tiếp tục cập nhật vị trí đơn đang làm.
- Storage/Authz API local thật: **12 checks PASS**. Upload bytes thật, complete RPC, reviewer đọc metadata/ký URL, người khác không ký được, public endpoint bị chặn, partner không tự duyệt, reviewer duyệt, token có TTL đúng 60 giây, file đọc được trước hạn và máy chủ từ chối sau hạn, tạo link mới thành công. Schema local đã phục hồi, fixture đã dọn. Không dùng tài liệu thật.
- Admin: **89 Playwright tests PASS** toàn suite tại lượt kiểm tra hồi quy; **6/6 tests màn hình đối tác PASS** sau chỉnh sửa cuối, gồm desktop 1440 px và mobile 390 px không tràn ngang. Build TypeScript/Vite và lint cuối PASS (lint toàn workspace có warning cũ trong `.payment-sevqr-work`; build có warning chunk >500 kB).
- Rescuer: `flutter analyze` PASS, **254 tests PASS** toàn suite; test mới chứng minh profile approved không đủ cấp Online, refresh đọc readiness bật/tắt quyền đúng theo backend.
- `git diff --check` PASS. Không có chỉnh sửa Customer App từ công việc này.

Các script: `backend/supabase/tests/audit_partner_review_readonly.sql` chỉ đọc production; `partner_review_regression.sql` yêu cầu test mode và rollback; `tools/check_partner_review_storage.mjs` cố định localhost, tạm áp migration lên stack local rồi phục hồi. Không chạy regression/Storage harness lên project thật. Lần Storage đầu đã qua assertions nhưng cleanup gặp thiếu dấu chấm phẩy; đã sửa, phục hồi rồi chạy lại thành công toàn bộ, bao gồm cleanup.

## Test bằng Nguyễn Hữu A sau khi triển khai riêng

**Migration chưa được áp lên backend thật theo yêu cầu không deploy. Các bước dưới đây là kịch bản nghiệm thu sau một đợt triển khai được cho phép; không thể dùng UI mới để duyệt thật trước khi backend có RPC mới.**

1. Đăng nhập Admin có role `super_admin` hoặc `partner_reviewer`, mở đúng **DT-000003**. Kiểm tra tên/email trên hồ sơ để tránh nhầm DT-000004.
2. Kiểm tra đủ 3 giấy tờ, xe và 7 capability. Bấm Xem tài liệu, mở tab mới; xác nhận đúng nội dung và đúng đăng ký xe. Link hết hạn thì quay lại tạo mới, không chia sẻ link.
3. Duyệt từng giấy tờ hợp lệ. Có thể kiểm tra reject bằng một tài khoản/giấy tờ thử: bỏ trống lý do phải bị chặn, nhập lý do rồi xác nhận phải lưu backend và đọc lại thấy lý do. Không từ chối tài liệu thật chỉ để thử nếu không có lỗi nghiệp vụ.
4. Duyệt xe phù hợp; duyệt từng capability thực sự đủ điều kiện, có danh mục đang active. Hồ sơ DT-000003 đã approved nên không cần duyệt lại profile. Chưa đủ xe/dịch vụ thì readiness còn false dù ba tài liệu đã approved.
5. Trong rescuer_app đăng nhập tài khoản có mã **DT-000003**, bấm tải lại hồ sơ. Checklist lấy `rescuer_get_readiness`; chọn xe trong danh sách backend cho phép. Nếu app hiện DT-000004 thì đó là hồ sơ draft khác, không phải trạng thái bị lỗi của DT-000003.
6. Bật GPS/quyền vị trí, bật Online; app gửi GPS trước discovery. Backend phải trả session thật; chỉ sau đó app hiển thị Online. Dùng yêu cầu test đúng dịch vụ/loại xe và vùng phục vụ để kiểm tra nhận đơn, không dùng đơn khách thật cho thử nghiệm.
7. Tài khoản partner/khách/operator gọi RPC review phải nhận 42501. Người khác không đọc/ký được tài liệu. Mở lại URL cũ sau hơn 60 giây bằng request mới phải bị từ chối; nội dung đã mở trong tab có thể vẫn còn trong bộ nhớ trình duyệt.

## File thay đổi trong công việc này

Admin:
- `admin_web/src/pages/RescuerDetailPage.tsx`
- `admin_web/src/lib/partnerReviewApi.ts` (mới)
- `admin_web/src/components/ui/PartnerReview.tsx` (mới)
- `admin_web/tests/partner-review.spec.ts` (mới)

Backend và harness:
- `backend/supabase/migrations/202610170002_partner_review_readiness.sql` (mới)
- `backend/supabase/tests/audit_partner_review_readonly.sql` (mới)
- `backend/supabase/tests/partner_review_regression.sql` (mới)
- `tools/check_partner_review_storage.mjs` (mới)

Rescuer:
- `frontend/rescuer_app/lib/models/backend_models.dart`
- `frontend/rescuer_app/lib/services/rescuer_service.dart` (giữ các chỉnh sửa có sẵn)
- `frontend/rescuer_app/lib/app/rescuer_controller.dart` (giữ các chỉnh sửa có sẵn)
- `frontend/rescuer_app/test/connected_app_test.dart`
- `frontend/rescuer_app/test/compact_partner_ui_test.dart`
- `frontend/rescuer_app/test/partner_readiness_test.dart` (mới)

Báo cáo: `docs/partner_review_readiness_audit.md` (file này). Log/screenshot nằm trong `.tmp` và `admin_web/test-results`, đều là artifact local bị Git ignore.
