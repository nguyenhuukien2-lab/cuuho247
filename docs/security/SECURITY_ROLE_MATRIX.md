# Ma trận quyền thực tế và quyền mục tiêu

Ký hiệu: ✅ cho phép bởi code/policy hiện có; ❌ bị từ chối/chưa triển khai; ⚠️ có điều kiện nêu ở cột ghi chú. Ma trận dựa trên migration trong repo, **chưa xác nhận drift database đã triển khai**. `customer` và `rescuer` đều là JWT `authenticated`; chức năng đổi theo hồ sơ và state. `SA` = super_admin, `OP` = operator, `SU` = support, `PR` = partner_reviewer, `FI` = finance. Cột Admin chỉ nói về API hiện có, không bảo đảm UI đã nối.

| Chức năng | customer | rescuer | SA | OP | SU | PR | FI | Ghi chú |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|
| Xem/sửa hồ sơ cá nhân khách | ⚠️ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | RLS theo `auth.uid()`; cùng JWT có thể có cả profile; Admin xem qua view, không sửa trực tiếp |
| Xem hồ sơ rescuer của mình | ❌ | ⚠️ | ⚠️ | ⚠️ | ❌ | ⚠️ | ❌ | Đối tác owner SELECT; Admin xem qua view theo vai trò |
| Sửa hồ sơ rescuer của mình | ❌ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | Qua RPC và version; không tự duyệt |
| Khóa tài khoản customer | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Chưa có `account_status`/RPC; đề xuất riêng |
| Quản lý role/status Admin | ❌ | ❌ | ⚠️ | ❌ | ❌ | ❌ | ❌ | Policy/guard `super_admin`, cấm tự đổi quyền/status; UI quản lý chưa xác nhận |
| Tạo đơn / hủy đơn của mình | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | Tạo/hủy theo `auth.uid()` của người sở hữu, **không theo tên role**; hủy Admin riêng chỉ SA/OP |
| Xem lịch sử đơn, ảnh của mình | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ❌ | ❌ | Chủ đơn qua RLS; Admin xem đơn qua view SA/OP/SU, ảnh object Admin chưa có policy |
| Gửi/sửa đánh giá đơn đã hoàn tất | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | RPC kiểm tra owner + completed; danh tính nào sở hữu đơn đều có thể gọi; mỗi request một review |
| Bật/tắt online | ❌ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | Có profile, xe/capability duyệt; kiểm tra phiên; không cho suspended |
| Xem đơn chờ nhận / nhận đơn | ❌ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | Approved, online, vị trí tươi, phù hợp dịch vụ, chưa bận; RPC khám phá chỉ trả coarse location |
| Cập nhật trạng thái / hoàn tất | ❌ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | Chỉ assignment của mình, đúng version và chuỗi state; hoàn tất cần báo giá issued |
| Gửi báo giá | ❌ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | `rescuer_create_quote`, chỉ job của mình ở `arrived`/`in_progress` |
| Upload/xem giấy tờ của mình | ❌ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | Reserve/complete, bucket private, owner SELECT object |
| Xem **file** giấy tờ để duyệt | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Hiện chỉ có view **metadata** cho SA/PR; chưa có đường tải file hợp lệ |
| Xem dashboard tổng quát | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | RPC thống kê cho 5 role; doanh thu bị che riêng |
| Xem danh sách khách | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | `admin_customers_view` |
| Xem danh sách đối tác | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ | `admin_rescuers_view` |
| Xem đơn/đánh giá toàn hệ thống | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | Admin views |
| Xem báo giá/doanh thu | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ | `admin_quotes_view`; dashboard chỉ SA/FI thấy doanh thu |
| Duyệt/từ chối đối tác | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | Profile phải `submitted`, không có job đang chạy; từ chối cần lý do |
| Khóa đối tác | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | RPC đặt `suspended`, từ chối nếu đang bận |
| Hủy đơn với tư cách Admin | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | Chỉ `searching`/`accepted`/`arriving`, cần reason |
| Bật/tắt dịch vụ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | RPC qua service catalog, audit |
| Xem audit log | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | RLS hiện cho mọi Admin active; UI chưa nối, nên xét thu hẹp nội dung |
| Gửi thông báo | ❌ | ❌ | ⚠️ | ⚠️ | ⚠️ | ❌ | ❌ | BE có policy/guard; UI hiện disabled |

**Không được diễn giải ⚠️ ở cột Admin như quyền customer/rescuer của Admin:** khi cùng một JWT có bản ghi khách/đối tác, RPC nghiệp vụ kiểm tra owner của bản ghi đó; đây là quyền theo danh tính, không phải quyền Admin. Kiểm tra biên role trong [checklist](SECURITY_CHECKLIST.md).
