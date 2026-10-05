# Kế hoạch kiểm thử bảo mật — Cứu Hộ 24/7

> Dựa trên [checklist](SECURITY_CHECKLIST.md), [ma trận quyền](SECURITY_ROLE_MATRIX.md), [rà soát RLS](SECURITY_RLS_REVIEW.md), [RPC](SECURITY_RPC_REVIEW.md), [Storage](SECURITY_STORAGE_REVIEW.md) và [Realtime](SECURITY_REALTIME_REVIEW.md). Đây là tài liệu kiểm thử, chưa chạy trên Supabase thật và không thay đổi app, migration hoặc database.

## 1. Mục tiêu và giới hạn

Xác nhận quyền theo người sở hữu, đối tác được giao và vai trò admin **ở server**: Customer A không đọc/sửa dữ liệu Customer B; đối tác chưa nhận đơn không thấy SĐT/GPS chính xác; user thường không gọi được RPC/view admin; finance/operator/support/partner_reviewer chỉ có quyền được cấp; ảnh/giấy tờ private; Realtime không phát dữ liệu ngoài quyền.

Ẩn nút hoặc lọc trên frontend không được tính là PASS. Kiểm tra trực tiếp REST/RPC/Storage/Realtime với JWT thật trên staging và đối chiếu cấu hình qua [SQL kiểm tra](SECURITY_SQL_TESTS.sql). SQL Editor thường chạy quyền cao, nên `SET LOCAL ROLE authenticated` và giả lập claims chỉ là kiểm tra bổ trợ; nó **không thay thế** lời gọi PostgREST/Auth/Storage/Realtime bằng phiên thật.

## 2. Môi trường và bộ dữ liệu thử

Chỉ dùng **staging**, dữ liệu giả, bucket thử và tài khoản do đội dự án kiểm soát. Không dùng dữ liệu khách thật, không dùng `service_role` làm JWT kiểm thử. Chuẩn bị:

| Ký hiệu | Fixture | Điều kiện |
|---|---|---|
| CA, CB | Hai customer khác nhau | Mỗi người có profile; CB có xe, địa chỉ, đơn, ảnh và review nếu trạng thái cho phép. |
| RA, RB | Hai rescuer khác nhau | RA approved/online; RB đã nhận một đơn khác; thêm một rescuer pending/suspended. |
| SA, OP, SU, PR, FI | Năm admin active | Lần lượt super_admin, operator, support, partner_reviewer, finance; thêm admin blocked. |
| Q, P, D | Đơn, quote, ảnh, giấy tờ giả | Có đơn `searching` của CB để kiểm tra trước claim; quote đã phát hành cho ca finance; ảnh/giấy tờ có object thật trong Storage khi thử tải. |

Ghi UUID nội bộ trong kho test riêng, không đưa token hay PII vào tài liệu/issue. Với mỗi ca âm tính, xác nhận fixture mục tiêu **tồn tại** bằng tài khoản chủ sở hữu hoặc preflight có quyền rồi mới kết luận `0 row/403` là PASS. Dùng request ID/quote ID thật; mã hiển thị chỉ để đối chiếu UI, không thay UUID trong API.

## 3. Tầng và thứ tự chạy

1. **Preflight SQL Editor, chỉ đọc:** kiểm tra role/status fixture, `relrowsecurity`, grants/policy, bucket `public=false`, publication. Phần này kiểm tra cấu hình, chưa chứng minh quyền API.
2. **SQL Editor, transaction `BEGIN`/`ROLLBACK`:** giả lập `authenticated` + `auth.uid()` từng fixture để đọc `count` hoặc cờ quyền, không dùng mutation. Nếu có `permission denied`, ghi lỗi riêng; không diễn giải thành policy PASS khi chưa kiểm tra grants.
3. **JWT thật qua app/API:** dùng phiên CA/CB/RA/RB và từng admin để gọi table/view/RPC; thử cả URL thủ công, bỏ filter frontend, UUID của người khác. Đây là bằng chứng chính cho RLS/RPC.
4. **Storage và Realtime:** anonymous URL, signed URL, object path chéo; đăng ký kênh với JWT khác nhau, ghi payload đã che dữ liệu, thử logout/đổi role/reconnect.
5. **Mutation có nguy cơ:** cancel/claim/approve/block/toggle/quote chỉ chạy trong staging riêng với dữ liệu giả, kịch bản và hậu kiểm cụ thể; SQL ví dụ được để comment, không tự chạy. `ROLLBACK` SQL Editor không hoàn tác thao tác từ app/API, upload Storage hoặc thông báo ngoài DB.

## 4. Mã ca và tiêu chí PASS

| Nhóm | Ca chính | Kết quả mong đợi |
|---|---|---|
| AUTH | Chưa đăng nhập, blocked, logout/refresh | Không có dữ liệu hoặc mutation mới; phiên/channels được thu hồi đúng. |
| CUS | CA đọc profile/xe/địa chỉ/đơn/ảnh/review của CB | `0 row` hoặc 403/permission denied; CA vẫn đọc dữ liệu của chính mình. |
| PRE | RA chưa claim khám phá đơn CB | Chỉ thấy dịch vụ, xe, khu vực/vị trí làm thô; không có phone/email/GPS/địa chỉ chi tiết/ảnh. |
| ADM | User thường gọi view/RPC admin | Không trả dữ liệu admin; mutation bị chặn trước khi ghi. |
| ROLE | FI/OP/SU/PR gọi chéo | FI xem quote/doanh thu nhưng không duyệt; OP điều phối nhưng không xem doanh thu; SU xem hỗ trợ nhưng không hủy; PR duyệt nhưng không xem quote/hủy. |
| STO | Ảnh/giấy tờ không public, chéo chủ | Anonymous/public URL thất bại; URL có quyền và hết hạn đúng; không tải chéo. |
| RT | CA nghe đơn CB, rescuer chưa nhận, admin blocked | Không nhận event nhạy cảm; cleanup và reconnect không rò dữ liệu. |

Phân biệt `BLOCKED` (chưa có tính năng hoặc thiếu fixture), `FAIL` (rò quyền/không đúng kỳ vọng), `PASS` (có bằng chứng). Ví dụ: hiện chưa có cơ chế khóa customer nên ca “blocked customer không tạo đơn” là **BLOCKED**, không PASS. Quyền tải ảnh của đối tác sau nhận và file giấy tờ của reviewer cũng đang là khoảng trống chức năng theo migration đã rà soát; kiểm tra mục tiêu sau khi có triển khai riêng.

## 5. Bằng chứng và xử lý lỗi

Mỗi ca ghi: mã ca, commit/migration đã deploy, môi trường, thời điểm, persona, fixture tồn tại, thao tác, kết quả mong đợi/thực tế, request ID hoặc trace đã che PII, người thực hiện và ticket. Không chụp nguyên token, signed URL, SĐT, GPS hay giấy tờ. Lỗi P0 (đọc chéo dữ liệu, user thường gọi admin RPC, bucket public, Realtime lộ dữ liệu) dừng đợt nghiệm thu và liên kết [sổ rủi ro](SECURITY_RISKS.md).

## 6. Điều kiện kết thúc

Các ca P0 có PASS trên JWT thật hoặc ticket chặn phát hành; ca SQL Editor có kết quả khớp với API, không thay thế API; mọi mutation thử đã được rollback/khôi phục và xác minh audit. Ưu tiên sửa theo [SECURITY_FIX_PRIORITY.md](SECURITY_FIX_PRIORITY.md). Không chạy bộ test này trên production khi chưa có kế hoạch riêng.
