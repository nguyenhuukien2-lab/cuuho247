# Rà soát RLS theo bảng

**Phương pháp:** đọc migration, grants và policies trong repo; chưa truy vấn `pg_policies`, `information_schema.role_table_grants` hoặc `storage.objects` của project thật. `—` nghĩa client không có grant/policy trực tiếp; trusted SQL hoặc RPC `SECURITY DEFINER` vẫn có thể ghi. Dùng hai JWT khác nhau và role `anon` để làm lại mọi phép thử; filter `.eq(...)` ở client không phải bằng chứng RLS.

## customer_profiles

- **Dữ liệu:** tên, điện thoại, mã khách. **SELECT/INSERT/UPDATE:** chủ `user_id=auth.uid()`; Admin đọc qua `admin_customers_view`, không qua owner policy. **DELETE:** —.
- **Rủi ro:** đọc chéo chủ, sửa `user_id`, tự đặt mã hoặc tạo profile khách từ tài khoản đối tác. **Test:** A/B đọc/sửa/insert owner giả, Admin dùng view. **Đề xuất:** xem lại quyền UPDATE theo cột và guard các field định danh; thiết kế `account_status` nếu cần khóa.

## customer_vehicles

- **Dữ liệu:** xe, biển số, ghi chú. **SELECT/INSERT/UPDATE/DELETE:** chỉ chủ `customer_id=auth.uid()`.
- **Rủi ro:** sửa xe của người khác rồi gắn vào đơn. **Test:** A/B từng thao tác và RPC tạo đơn dùng vehicle ID của B. **Đề xuất:** kiểm tra đồng bộ loại xe trong RPC khi xe thay đổi đồng thời.

## customer_saved_addresses

- **Dữ liệu:** địa chỉ, tọa độ/ghi chú lưu. **SELECT/INSERT/UPDATE/DELETE:** chủ `customer_id=auth.uid()`.
- **Rủi ro:** lộ nhà riêng hoặc gán lại owner. **Test:** A/B cả CRUD và update owner. **Đề xuất:** giảm dữ liệu trả về và retention theo chính sách riêng tư.

## rescue_requests

- **Dữ liệu:** liên hệ, địa chỉ/GPS, mô tả, trạng thái, giá. **SELECT:** chủ đơn qua owner policy; Admin qua gated view; đối tác chưa nhận dùng RPC projection thô, sau nhận dùng RPC active job. **INSERT/UPDATE/DELETE trực tiếp:** — cho client.
- **Rủi ro:** lộ PII qua direct SELECT/Realtime hoặc sửa `provider_id/status/quoted_price`. **Test:** A/B SELECT, update REST, rescuer chưa/đã claim, Realtime JWT B. **Đề xuất:** giữ mutation qua RPC và review cột trong publication.

## request_status_events

- **Dữ liệu:** lịch sử status/thời điểm. **SELECT:** chủ đơn qua join `rescue_requests`. **INSERT/UPDATE/DELETE trực tiếp:** —; trigger ghi.
- **Rủi ro:** thấy hành trình của B hoặc ghi sự kiện giả. **Test:** A/B SELECT, thử INSERT/DELETE bằng JWT. **Đề xuất:** xét retention/ẩn mốc nhạy cảm sau khi kết thúc.

## rescue_request_photos (`request_photos` trong yêu cầu nghiệp vụ)

- **Dữ liệu:** metadata/path ảnh sự cố. **SELECT:** chủ đơn; **INSERT/UPDATE/DELETE trực tiếp:** —, reserve/complete RPC ghi metadata.
- **Rủi ro:** metadata/path của B; lầm tưởng partner/Admin được xem object chỉ vì thấy metadata. **Test:** A/B metadata và object riêng biệt, ảnh chưa complete, 3 slot. **Đề xuất:** thiết kế gateway ảnh cho đối tác sau claim/Admin có quyền; không mở policy chung cho `authenticated`.

## customer_request_reviews

- **Dữ liệu:** rating/comment, customer/request ID. **SELECT:** chủ; Admin xem qua `admin_reviews_view`. **INSERT/UPDATE:** chủ đơn đã `completed`, trigger kiểm tra identity; **DELETE:** —.
- **Rủi ro:** đánh giá đơn B, đánh giá trước hoàn tất, sửa owner qua UPDATE. **Test:** A/B, trạng thái searching/cancelled, upsert lặp. **Đề xuất:** quyết định có khóa chỉnh sửa sau thời hạn cụ thể không.

## rescuer_profiles

- **Dữ liệu:** danh tính, trạng thái duyệt, số liên hệ. **SELECT:** chủ `user_id`; Admin qua view. **INSERT/UPDATE/DELETE trực tiếp:** — cho client; RPC/guard riêng.
- **Rủi ro:** tự approve/suspended hoặc đọc hồ sơ khác. **Test:** A/B SELECT/UPDATE verification; RPC đăng ký và phiên bị suspended. **Đề xuất:** xác nhận mã đối tác nằm trong projection client nếu UI cần.

## rescuer_vehicles

- **Dữ liệu:** phương tiện/biển số/trạng thái duyệt. **SELECT:** chủ. **INSERT/UPDATE/DELETE trực tiếp:** —; RPC đăng ký/sửa.
- **Rủi ro:** dùng xe chưa duyệt để online/claim. **Test:** owner chéo, xe chưa duyệt, xe của B trong RPC. **Đề xuất:** kiểm tra phiên/khóa xe khi duyệt bị thu hồi.

## rescuer_service_capabilities

- **Dữ liệu:** dịch vụ/loại xe được phép. **SELECT:** chủ. **INSERT/UPDATE/DELETE trực tiếp:** —; RPC quản lý capability.
- **Rủi ro:** tự bật capability chưa duyệt. **Test:** REST UPDATE, claim ngoài capability, approved→suspended. **Đề xuất:** giữ kiểm tra tại thời điểm claim, không chỉ khi hiển thị feed.

## rescuer_documents

- **Dữ liệu:** metadata giấy tờ và `storage_path`. **SELECT:** chủ; SA/PR thấy metadata qua `admin_rescuer_documents_view`. **INSERT/UPDATE/DELETE trực tiếp:** —; reserve/complete RPC.
- **Rủi ro:** path bị dùng để tải giấy tờ người khác. **Test:** A/B metadata/object, reviewer metadata vs file. **Đề xuất:** gateway/signed URL giới hạn reviewer; log quyền xem file.

## rescuer_online_status

- **Dữ liệu:** online, session, xe, last seen. **SELECT:** chủ. **INSERT/UPDATE/DELETE trực tiếp:** —; RPC online/location cập nhật.
- **Rủi ro:** giả online hoặc giữ phiên cũ. **Test:** JWT B, session cũ, suspended, xe đổi. **Đề xuất:** monitor phiên online không còn heartbeat.

## rescuer_locations

- **Dữ liệu:** GPS chính xác của đối tác. **SELECT:** chủ. **INSERT/UPDATE/DELETE trực tiếp:** —; RPC update location.
- **Rủi ro:** GPS bị đọc chéo hoặc replay. **Test:** A/B và sequence/timestamp cũ. **Đề xuất:** retention vị trí và giới hạn consumer.

## rescue_request_assignments

- **Dữ liệu:** nhận đơn, rescuer/vehicle ID, tiến độ, quote ID. **SELECT/INSERT/UPDATE/DELETE trực tiếp:** —; RPC và DTO có gate riêng.
- **Rủi ro:** partner lấy job B hoặc sửa trạng thái. **Test:** REST SELECT/UPDATE, RPC cross owner, claim cạnh tranh. **Đề xuất:** giữ default deny và audit chuyển trạng thái.

## rescue_quotes

- **Dữ liệu:** giá, dòng phí, ghi chú, version/trạng thái. **SELECT/INSERT/UPDATE/DELETE trực tiếp:** —; RPC đối tác và Admin view; khách chỉ lấy mã quote của đơn mình qua RPC nhỏ.
- **Rủi ro:** sửa giá đã phát hành, finance bị lộ cho role khác. **Test:** REST CRUD, RPC của B, superseded/current, Admin OP/SU vs FI. **Đề xuất:** tách báo giá khỏi thanh toán/thực thu.

## admin_profiles

- **Dữ liệu:** role/status Admin, liên hệ. **SELECT:** mọi Admin active theo `is_admin()`. **INSERT/UPDATE:** chỉ `super_admin`, trigger guard; **DELETE:** —.
- **Rủi ro:** tự nâng quyền, tự khóa hoặc đọc danh bạ Admin quá rộng. **Test:** user thường/blocked Admin/OP/SA; self-demotion. **Đề xuất:** xét giới hạn cột nhạy cảm qua view nếu cần.

## admin_audit_logs

- **Dữ liệu:** actor, hành động, target, metadata. **SELECT:** mọi Admin active. **INSERT/UPDATE/DELETE trực tiếp:** —; trigger/RPC ghi.
- **Rủi ro:** log giả/sửa/xóa; metadata lý do chứa PII được đọc bởi role quá rộng. **Test:** REST insert/update/delete dưới các JWT, actor `auth.uid()`. **Đề xuất:** retention, lọc metadata theo role và log truy cập nhật ký.

## admin_notifications

- **Dữ liệu:** nội dung, đối tượng, người tạo. **SELECT:** mọi Admin active. **INSERT:** SA/OP/SU với guard role và target; **UPDATE/DELETE:** —.
- **Rủi ro:** gửi nhầm nhóm, sửa `created_by`, spam hoặc nhồi PII. **Test:** FI/PR bị chặn, target không tồn tại, spoof creator. **Đề xuất:** quy trình duyệt/throttle khi mở UI gửi thật.

## admin_service_catalog

- **Dữ liệu:** metadata dịch vụ và giá tham chiếu. **SELECT:** mọi Admin active. **UPDATE:** SA/OP chỉ các cột được grant; **INSERT/DELETE:** — client.
- **Rủi ro:** đổi giá/hiển thị dịch vụ trái quyền. **Test:** OP/SU/FI, sửa ID/code, audit trước/sau. **Đề xuất:** xác định giá catalog có ý nghĩa tài chính hay chỉ tham khảo.

## Bảng bổ sung cần giữ trong inventory

`rescue_services` có owner-read dịch vụ active cho `authenticated` và Admin-read policy; trạng thái dịch vụ đổi qua Admin RPC. `rescuer_assignment_events`, `private.rescuer_rpc_receipts`, `private.rescuer_discovery_limits` không cấp SELECT client. Chạy inventory thực tế trước release để phát hiện bảng/view/policy mới ngoài migration đã đọc.
