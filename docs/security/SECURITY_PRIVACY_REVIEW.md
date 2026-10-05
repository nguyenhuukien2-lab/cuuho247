# Rà soát quyền riêng tư và giảm thiểu dữ liệu

> Tài liệu này mô tả quyền truy cập và đề xuất sản phẩm; không khẳng định chính sách lưu giữ hoặc tuân thủ pháp lý đã được triển khai.

## 1. Dữ liệu cần bảo vệ

| Nhóm | Ví dụ | Nguy cơ khi lộ | Quy tắc tối thiểu |
|---|---|---|---|
| Danh tính/liên hệ | Họ tên, email, số điện thoại khách/đối tác | Quấy rối, giả mạo | Chỉ hiển thị đúng người và khi cần làm việc. |
| Vị trí/lịch sử | GPS chính xác, địa chỉ, điểm đón, địa chỉ đã lưu | Theo dõi cá nhân | Trước khi nhận đơn chỉ dùng khu vực gần đúng; không lưu vô hạn. |
| Hình ảnh | Ảnh sự cố, giấy tờ đối tác | Lộ tài sản, danh tính | Bucket private, URL có thời hạn, quyền theo owner/assignment/role. |
| Nghiệp vụ | Thông tin xe, báo giá, doanh thu, đánh giá | Lộ hoạt động/giá | Phân quyền theo vai trò; tách báo giá khỏi thực thu. |
| Truy cập | Token, session, audit log | Chiếm tài khoản, suy luận hành vi | Không log token; bảo vệ và giới hạn thời gian giữ log. |

## 2. Hiển thị theo vòng đời đơn

| Giai đoạn | Khách hàng | Đối tác | Admin |
|---|---|---|---|
| `searching` | Đơn, địa điểm và ảnh của chính mình | Danh sách khám phá tối thiểu: dịch vụ, loại xe, khu vực gần đúng, khoảng cách; **không** có số điện thoại/email/GPS chính xác/địa chỉ chi tiết | Operator/super_admin thấy dữ liệu cần điều phối qua view/RPC có quyền. |
| `accepted`, `arriving`, `in_progress` | Thông tin đối tác được phân công, tiến độ và báo giá của đơn | Thông tin liên hệ/vị trí/ảnh cần thiết cho **đơn đã nhận**; không mở đơn khác | Theo vai trò, không mặc định cho finance/support xem mọi dữ liệu. |
| `completed`, `cancelled` | Lịch sử đơn của mình, đánh giá khi đủ điều kiện | Lịch sử công việc được giao, thông tin cần cho tranh chấp | Giữ tối thiểu cho vận hành/kế toán/khiếu nại; doanh thu chỉ finance/super_admin. |

RPC khám phá đơn đối tác trong migration hiện trả dữ liệu làm thô trước khi nhận. Cần test REST/Realtime/Storage song song để bảo đảm không tồn tại lối khác trả hàng `rescue_requests` hoặc ảnh đầy đủ. Không xem việc ẩn trường ở UI là kiểm soát quyền.

## 3. Giảm thiểu và vòng đời dữ liệu

- Xác định mục đích cho từng trường, ai cần, trong bao lâu; lập lịch giữ/xóa hoặc ẩn danh cho GPS, ảnh, giấy tờ, audit log, quote và dữ liệu hỗ trợ. Chưa thấy chính sách retention có thể xác nhận từ phần mã đã rà soát.
- Khi hết nhu cầu: xóa/ẩn danh metadata và object Storage theo cùng quy trình; đảm bảo backup, signed URL còn hạn và dữ liệu export được xem xét.
- Không gửi PII hoặc signed URL vào analytics, crash log, push notification dạng chi tiết hoặc URL trang web. Nếu cần thông báo, gửi mã đơn/trạng thái tối thiểu và tải chi tiết sau xác thực.
- Định nghĩa quy trình xử lý yêu cầu xem/sửa/xóa dữ liệu, khiếu nại, sự cố lộ dữ liệu và quyền truy cập của nhân viên; lưu audit truy cập giấy tờ.

## 4. Roadmap che số và liên lạc

**Giai đoạn 1:** khóa truy cập số điện thoại/email và tọa độ chính xác trước `accepted` ở database/RPC; chỉ đối tác đã nhận đơn thấy dữ liệu cần thiết. Kiểm tra mọi đường REST, Realtime, Storage.

**Giai đoạn 2, chỉ khi có yêu cầu sản phẩm:** chat trong app hoặc gọi qua tổng đài trung gian để che số thật; xác định quyền truy cập, lưu giữ tin nhắn và phòng chống quấy rối trước khi triển khai.

## 5. Share Request / SOS (đề xuất sau này)

Nếu bổ sung chia sẻ trạng thái cho người thân hoặc nút SOS, dùng link có TTL, phạm vi chỉ trạng thái cần thiết, quyền thu hồi, giới hạn người nhận và audit; không phát GPS liên tục qua link công khai. Chức năng này **chưa được triển khai** trong giai đoạn lập tài liệu.

## Checklist

- [ ] Đối tác chưa nhận không lấy được số điện thoại/email/GPS chính xác qua mọi API và Realtime.
- [ ] Sau khi nhận, chỉ đúng đối tác được giao truy cập; sau thu hồi assignment/khóa tài khoản không cấp quyền mới.
- [ ] Bucket private, URL ký hết hạn, không log URL; giấy tờ chỉ reviewer có quyền xem.
- [ ] Xác định và phê duyệt thời hạn giữ/xóa từng nhóm dữ liệu trước vận hành chính thức.
- [ ] Báo giá và thực thu được phân biệt trong màn hình, báo cáo và quyền finance.
