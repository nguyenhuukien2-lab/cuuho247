# Ưu tiên demo hai app mobile

Ngày 05/10/2026. Tài liệu này dùng để chọn phạm vi sửa và kịch bản bảo vệ. Không mô tả tính năng chưa có như đã hoàn thành.

## Màn cần sửa nhất

1. **Khách hàng: Theo dõi đơn (`NewTrackingScreen`)**. Đây là nơi chứng minh dịch vụ có vận hành sau khi bấm đặt. Màn đã có trạng thái, timeline, vị trí, BG và hỗ trợ, nhưng card “Kỹ thuật viên / Chưa có dữ liệu” cùng “Đang cập nhật” làm yếu niềm tin; thông tin quan trọng trải dài qua nhiều card. Đưa trạng thái, cập nhật gần nhất và hành động phù hợp lên đầu. Form đặt cứu hộ là ưu tiên thứ hai vì 5 bước dài.
2. **Đối tác: Đơn mới và bước trước nhận (`PreparationScreen._feed`)**. Đây là thời điểm đối tác quyết định nhận việc; luồng đang chạy nhận thẳng trên card với tọa độ gần đúng dạng số, chưa có màn xem trước riêng. Ưu tiên tóm tắt dễ quét và một bước xác nhận trước khi `claimRequest`. Active job là ưu tiên sát sau vì CTA chuyển trạng thái nằm cuối trang.

## Vấn đề UI lớn nhất

**Thiếu thứ bậc thông tin theo trạng thái công việc.** Các màn chứa nhiều card/nút cùng mức nhấn nên người dùng phải cuộn hoặc đọc lâu để tìm việc tiếp theo. Ở app khách, `BookingStyle` còn đổi bảng màu so với `AppTheme`, làm cảm giác hệ thống thiếu nhất quán. Sửa thứ bậc trước khi tô lại màu để tránh chỉ làm đẹp bề mặt.

## Kịch bản demo đề xuất

| Bước | Màn | Điều cần chứng minh | Dữ liệu/điều kiện cần chuẩn bị |
|---|---|---|---|
| 1 | Khách: Trang chủ | Một CTA “Đặt cứu hộ”; nếu có đơn thì “Theo dõi” nổi bật | Tài khoản khách đã đăng nhập |
| 2 | Khách: Form | Chọn sự cố/xe, xác nhận địa điểm, liên hệ, xem tóm tắt | Quyền GPS hoặc địa chỉ nhập tay; xe lưu nếu muốn trình diễn |
| 3 | Khách: Theo dõi | Mã CH, trạng thái “Đang tìm”, timeline; giá chưa có hiển thị trung thực | Đơn thật mới tạo, không cần mô phỏng ETA |
| 4 | Đối tác: Dashboard/Online | Đủ điều kiện, đúng xe, GPS và online | Hồ sơ/xe/dịch vụ đã được duyệt, GPS sẵn sàng |
| 5 | Đối tác: Đơn mới | Nhìn dịch vụ, xe, vùng gần đúng, khoảng cách; xem trước rồi nhận | Đơn phù hợp khu vực; nếu bước xem trước chưa làm, nói rõ hiện nhận trên card |
| 6 | Đối tác: Đang xử lý | Gọi, chỉ đường, chuyển trạng thái | Đơn vừa nhận, tọa độ có thật nếu trình diễn Maps |
| 7 | Đối tác: Báo giá/Hoàn tất | Nhập phí, gửi BG, kiểm tra tổng, hoàn tất | Giá ví dụ rõ là dữ liệu demo; không nói khách đã chấp thuận nếu hệ thống chưa ghi nhận |
| 8 | Khách: Tracking/Lịch sử | Xem BG, trạng thái hoàn tất, mã CH/BG, đánh giá nếu có | Đồng bộ dữ liệu thật hoặc làm mới trạng thái |
| 9 | Hai tài khoản | Mã KH/DT và hồ sơ | Tài khoản đã tạo đủ dữ liệu |

## Thứ tự sửa cho một vòng demo ngắn

1. Chốt token UI chung và 3 mẫu component: status header, card đơn, CTA chính/phụ.
2. Theo dõi khách: bỏ cảm giác placeholder, đưa trạng thái và action lên đầu.
3. Feed đối tác: card tóm tắt và bước xem trước nhận đơn.
4. Active job: hành động tiếp theo, gọi/chỉ đường trong viewport đầu.
5. Form khách: nhãn bước, vị trí, tóm tắt và giá chưa chốt.
6. Dashboard/online: phân biệt điều kiện chuẩn bị với trạng thái sẵn sàng.
7. Báo giá/hoàn tất: ngôn ngữ giá, ẩn input vô hiệu, xác nhận CH/BG/tổng.
8. Lịch sử/tài khoản: rút gọn card và mã sao chép.

## Điểm chặn khi diễn giải demo

- Chỉ nói có tracking trạng thái đơn; **chưa** có ETA hay vị trí xe đối tác trực tiếp từ model hiện tại.
- Chỉ hiển thị thông tin đối tác có thật; card khách hiện chưa có tên/số điện thoại KTV.
- Vị trí trước nhận của đối tác là gần đúng và cần giữ giới hạn này.
- BG hiện có mã và tổng; chi tiết dòng phí phía đối tác không tải lại được trong giao diện hiện tại. Không giới thiệu như biên nhận đầy đủ.
- Nút hỗ trợ/tính năng tài khoản nào mới mở thông báo “chưa cấu hình” thì tránh đưa vào kịch bản chính cho đến khi có luồng thật.

Chi tiết bằng chứng và đề xuất: `UI_UX_REVIEW_CUSTOMER_APP.md`, `UI_UX_REVIEW_RESCUER_APP.md`, `FEATURE_RESEARCH_2_APPS.md`, `MOBILE_UI_IMPROVEMENT_ROADMAP.md`.
