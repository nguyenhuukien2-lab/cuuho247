# Rà soát RPC và thao tác trạng thái

> Phạm vi: mã SQL trong `backend/supabase/migrations` và `admin_web/backend/supabase/migrations`. Đây là rà soát tĩnh; quyền thực tế phải kiểm thử trên Supabase đã triển khai. Không đổi RPC trong giai đoạn tài liệu.

## Quy tắc kiểm tra chung

- RPC `SECURITY DEFINER` phải đặt `search_path` an toàn, giới hạn `EXECUTE` và kiểm tra `auth.uid()` ở đầu luồng; quyền gọi hàm không thay thế kiểm tra quyền bên trong.
- Với mọi UUID do client gửi: kiểm tra chủ sở hữu, vai trò, trạng thái hiện tại và quan hệ giữa các bản ghi. Khóa hàng khi cạnh tranh nhận/hủy/hoàn tất đơn; có idempotency cho thao tác có thể retry.
- Kiểm tra chuyển trạng thái ở database, không dựa vào màn hình. Trả dữ liệu tối thiểu; lỗi không tiết lộ dữ liệu của người khác.
- RPC admin phải kiểm tra admin còn `active`, vai trò phù hợp và ghi audit log trong cùng giao dịch cho thao tác thay đổi dữ liệu.
- Kiểm tra `GRANT EXECUTE` trên môi trường triển khai; không giả định cấu hình từ tên hàm.

## Customer RPC

| RPC thực tế | Mục đích / đầu vào đáng kiểm tra | Quyền, trạng thái và dữ liệu thay đổi | Rủi ro và test bắt buộc |
|---|---|---|---|
| `create_customer_rescue_request` | Tạo đơn: dịch vụ, xe, địa điểm, khóa idempotency và các trường yêu cầu | `auth.uid()`; xe thuộc khách; dịch vụ khả dụng; giới hạn đơn đang hoạt động; tạo `rescue_requests` và sự kiện liên quan | Giả `customer_id`/xe của B, tạo lặp cùng khóa, hai lệnh đồng thời, dữ liệu vị trí ngoài phạm vi; đều phải chặn hoặc trả cùng kết quả idempotent. Cần bổ sung giới hạn tần suất theo tài khoản/IP ở giai đoạn sau. |
| `cancel_own_rescue_request` | Hủy đơn bằng UUID, lý do nếu có | Chủ đơn; chỉ trạng thái được phép; ghi trạng thái/sự kiện nhất quán | Khách A hủy đơn B, hủy sau hoàn tất, hủy đua với đối tác nhận đơn. |
| `reserve_customer_request_photo`, `complete_customer_request_photo` | Xin slot và xác nhận upload | Chủ đơn; tối đa 3 ảnh; loại/size và đường dẫn object khớp reservation; cập nhật metadata `rescue_request_photos` | Dùng reservation của B, xác nhận object không tồn tại hoặc sai path, vượt hạn mức. |
| `submit_customer_request_review` | Gửi hoặc cập nhật đánh giá | Chủ đơn, đơn `completed`, quan hệ đánh giá đúng đơn | A đánh giá đơn B, đánh giá đơn chưa xong, gửi lặp để tạo nhiều bản ghi; xác định chính sách cho phép sửa đánh giá. |
| `customer_request_display_codes` | Tra mã hiển thị theo danh sách UUID | Migration mã hiển thị lọc theo chủ đơn; chỉ trả `request_code` cho đơn của người gọi | Trộn UUID của A/B trong một lời gọi: kết quả chỉ có A; anonymous nhận rỗng/bị từ chối. |

## Rescuer RPC

| RPC thực tế | Mục đích / đầu vào đáng kiểm tra | Quyền, trạng thái và dữ liệu thay đổi | Rủi ro và test bắt buộc |
|---|---|---|
| `rescuer_set_online` | Bật/tắt sẵn sàng | Hồ sơ hợp lệ, không bị khóa/đình chỉ; phương tiện và phiên phù hợp; cập nhật `rescuer_online_status` | Đối tác chưa duyệt/bị suspended bật online, đổi online của người khác. |
| `rescuer_list_available_requests`, `rescuer_get_available_request` | Khám phá đơn gần đây | Đối tác đủ điều kiện; chỉ trả loại dịch vụ/xe, khu vực gần đúng, khoảng cách và mã/id cần cho nhận đơn; có giới hạn discovery | Trước khi nhận, không trả số điện thoại, email, tọa độ/địa chỉ chính xác; thử vét danh sách/UUID và giới hạn tốc độ. |
| `rescuer_claim_request` | Nhận đơn bằng UUID | Đã approved, online, xe/capability/vị trí hợp lệ, không bận; khóa hàng và kiểm tra trạng thái; tạo assignment | A và B nhận đồng thời chỉ một người thành công; suspended hoặc đang có đơn không được nhận; retry idempotent. |
| `rescuer_update_job_status` | Đến nơi, bắt đầu, hoàn tất hoặc hủy công việc | Chỉ đối tác được phân công; phiên bản/trạng thái chuyển hợp lệ; hoàn tất cần báo giá đã phát hành; cập nhật request/assignment/events | A không hoàn tất đơn B; không bỏ qua bước; không hoàn tất hai lần hoặc sau hủy. Đây là RPC hoàn tất thực tế, không có `rescuer_complete_job` riêng. |
| `rescuer_create_quote` | Tạo/phát hành báo giá theo đơn, dòng chi phí | Chỉ đối tác nhận đơn; trạng thái `arrived`/`in_progress`; kiểm tra dịch vụ, số tiền, revision; ghi quote và items | Giá âm/sai tổng, sửa quote không thuộc mình, sửa giá đã xác nhận, retry tạo trùng. Đây là tên thực tế, không có `rescuer_submit_quote` trong migration đã rà soát. |
| `rescuer_reserve_document`, `rescuer_complete_document` | Đặt chỗ và xác nhận giấy tờ | Chỉ chủ hồ sơ; object đúng bucket/path, loại/size hợp lệ; cập nhật metadata | Upload sang thư mục người khác hoặc xác nhận object chưa hợp lệ. |
| RPC cập nhật hồ sơ/vị trí đối tác | Đăng ký, chỉnh hồ sơ, cập nhật vị trí | `auth.uid()` gắn hồ sơ; không tự ghi `verification_status=approved`; vị trí chỉ khi phiên hợp lệ | User thường tự duyệt hồ sơ hoặc ghi vị trí đối tác khác. Đối chiếu danh sách RPC cụ thể khi lập test SQL. |

## Admin RPC

| RPC thực tế | Vai trò được phép theo migration | Kiểm tra và thay đổi | Test phủ định / audit |
|---|---|---|---|
| `admin_get_dashboard_stats` | Admin active thuộc 5 vai trò | Tổng hợp thống kê; `today_revenue` chỉ hiện cho `super_admin`/`finance`, các vai trò khác nhận `revenue_visible=false` | Operator/support không thấy doanh thu kể cả gọi RPC trực tiếp. Chỉ số doanh thu hiện theo báo giá, chưa phải thực thu. |
| `admin_approve_rescuer`, `admin_reject_rescuer` | `super_admin`, `partner_reviewer` | Kiểm tra hồ sơ/trạng thái, lý do từ chối; thay đổi duyệt và audit | Finance/operator không gọi được; thao tác lặp và lý do rỗng phải xử lý rõ. |
| `admin_block_rescuer` | `super_admin`, `operator` | Khóa đối tác, reason, audit; không cho tiếp tục nhận đơn | Support/finance bị từ chối; xem tác động với đơn đang chạy. |
| `admin_cancel_request` | `super_admin`, `operator` | Chỉ `searching`/`accepted`/`arriving`, lý do bắt buộc; ghi trạng thái và audit | Support/partner_reviewer bị từ chối; completed không hủy; hai lệnh đua không tạo trạng thái sai. |
| `admin_toggle_service` | `super_admin`, `operator` | Bật/tắt dịch vụ và ghi audit | Finance/support bị từ chối; dịch vụ không tồn tại và thao tác lặp. |

## Bộ ca kiểm thử tối thiểu

- [ ] Customer A hủy/đánh giá/tra mã đơn Customer B: bị từ chối hoặc không trả dữ liệu B.
- [ ] Đối tác chưa approved hoặc suspended gọi discovery/claim/set_online: bị chặn.
- [ ] Đối tác A hoàn tất/tạo quote trên đơn của B: bị chặn, dữ liệu không đổi.
- [ ] Hai đối tác nhận cùng đơn đồng thời: tối đa một assignment hiệu lực.
- [ ] User thường gọi từng RPC admin: bị chặn; finance gọi approve, support gọi cancel cũng bị chặn.
- [ ] Operator gọi dashboard được nhưng không nhận số doanh thu; finance có quyền doanh thu nhưng không được duyệt đối tác.
- [ ] Mọi mutation admin sinh đúng một audit log với actor, target, reason và thời gian; client không tự chèn log giả.
- [ ] Kiểm tra `EXECUTE`, `search_path`, `auth.uid()` và dữ liệu trả của từng overload/signature trong database triển khai.

## Đề xuất giai đoạn triển khai

Viết test SQL với JWT từng vai trò và transaction rollback; bổ sung rate limit tạo đơn; kiểm chứng bất biến giá sau xác nhận bằng trigger/RPC hiện có; thống nhất tên RPC trong tài liệu API và test. Các thay đổi này chưa được thực hiện.
