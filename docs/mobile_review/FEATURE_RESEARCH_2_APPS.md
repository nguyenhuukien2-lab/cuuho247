# Nghiên cứu tính năng cho hai app Cứu Hộ 24/7

Ngày rà soát: 05/10/2026. Phạm vi: mã Flutter trong `frontend/customer_app` và `frontend/rescuer_app`; không đánh giá admin web, backend hoặc migration. Đây là **đánh giá tĩnh từ mã nguồn**, chưa phải kiểm thử hình ảnh trên thiết bị hay phỏng vấn người dùng. Những nhận xét như “dày”, “rối” là rủi ro thị giác cần xác nhận bằng ảnh chụp 360–430 dp, cỡ chữ hệ thống 100% và 150%.

## Luồng hiện có và điểm đứt

| Giai đoạn | Khách hàng hiện có | Đối tác hiện có | Cơ hội sản phẩm |
|---|---|---|---|
| Tạo yêu cầu | Trang chủ CTA cứu hộ; form 5 bước: sự cố, xe, vị trí, mô tả/ảnh, xác nhận | Feed lọc đơn theo dịch vụ, hiển thị loại dịch vụ, xe, vùng gần đúng, khoảng cách | Giảm số thao tác trong tình huống khẩn cấp; xem chi tiết trước khi nhận |
| Ghép và theo dõi | Mã CH, trạng thái, timeline, địa điểm, ảnh, tổng báo giá; chủ động làm mới và có luồng cập nhật | Online/offline, GPS, nhận đơn, tiến độ | Hiển thị thông tin có thật: người đến, cách liên hệ, ETA chỉ khi có dữ liệu; tránh lời hứa không đo được |
| Báo giá | Tổng tiền và mã BG nếu có; lịch sử có mã BG | Nhập phí chính, phụ thu, ghi chú; tổng dự kiến và mã BG sau gửi | Giải thích từng dòng phí, trạng thái báo giá, xác nhận của khách nếu nghiệp vụ hỗ trợ |
| Kết thúc | Lịch sử, chi tiết, đánh giá | Xác nhận hoàn tất bằng dialog; lịch sử chuyến | Biên nhận rõ chi phí, thời điểm, mã CH/BG, kênh hỗ trợ sau cứu hộ |
| Hồ sơ | Mã KH, xe và địa chỉ đã lưu | Mã DT, xe, dịch vụ, giấy tờ, duyệt, GPS | Sao chép mã, thông tin xác minh, chỉ dẫn điều kiện còn thiếu theo ngữ cảnh |

**Phân biệt đã có và đề xuất:** Chưa thấy dữ liệu kỹ thuật viên hay điện thoại được cấp cho màn tracking khách; widget hiện ghi “Chưa có dữ liệu”. Chưa thấy bản đồ trực tiếp cho đối tác trong active job; có nút mở Google Maps khi có tọa độ. Báo giá phía đối tác sau tải lại chỉ còn tổng tiền và thông báo chưa tải lại chi tiết dòng phí. Không nên vẽ ETA, tuyến đi, thông tin kỹ thuật viên hoặc chi tiết phí giả trong demo.

## Mẫu tham chiếu thị trường

- [AAA Mobile](https://www.ace.aaa.com/content/dam/ace/pdf/AL-MemberGuide.pdf) mô tả việc yêu cầu cứu hộ và theo dõi xe dịch vụ. Đây là mẫu cho trục “gửi yêu cầu → biết ai/xe nào đang tới”; mức dữ liệu thực tế của Cứu Hộ 24/7 cần quyết định mức hiển thị.
- [Uber Driver App](https://www.uber.com/us/en/drive/driver-app/) cho người làm dịch vụ xem thông tin thiết yếu trước khi nhận, sau đó chuyển sang các hành động theo chặng. Cứu hộ có rủi ro và thời gian xử lý khác chở khách, nên chỉ mượn nguyên tắc thứ bậc và trạng thái, không sao chép cơ chế giá hay thời gian.
- [Uber: How to Take Trips](https://www.uber.com/gb/en/drive/basics/how-to-take-trips/) cho thấy luồng rõ “xem → nhận → điều hướng → bắt đầu → hoàn tất”. Đây là tham chiếu cho thao tác đối tác, không phải xác nhận rằng dữ liệu hiện có đã đủ cho mọi bước.
- [Apple UI Design Dos and Don’ts](https://developer.apple.com/design/tips/) nêu mục tiêu chạm tối thiểu 44 pt; [Material spacing](https://m2.material.io/design/layout/spacing-methods.html) khuyến nghị 48 dp và khoảng cách 8 dp. [WCAG 2.2](https://www.w3.org/TR/wcag/) đặt ngưỡng tương phản chữ thông thường 4.5:1. Dùng các ngưỡng này để đo trên thiết bị, không suy đoán từ mã màu.

## Đề xuất tính năng theo giá trị

| Ưu tiên | Tính năng / cải tiến | Lý do và điều kiện | Chỉ số xác nhận |
|---|---|---|---|
| P0 | Tóm tắt đơn trước khi gửi: sự cố, xe, địa điểm, liên hệ, ảnh, lưu ý giá chưa chốt | Đã có dữ liệu trong form; làm rõ quyết định cuối cùng | Tỉ lệ gửi thành công, lỗi quay lại sửa thông tin |
| P0 | Card đơn mới đối tác có tên khu vực dễ hiểu và màn xem trước với giới hạn dữ liệu rõ ràng | Tọa độ làm tròn khó hiểu khi lái xe; giữ bảo vệ vị trí chính xác và liên hệ trước khi nhận | Tỉ lệ mở chi tiết, nhận đơn, bỏ qua |
| P0 | Trạng thái đơn hiện tại và CTA kế tiếp đứng đầu màn tracking/active job | Người dùng cần hiểu “đang ở đâu, làm gì tiếp” trong vài giây | Thời gian tìm CTA, số lần gọi hỗ trợ vì không rõ trạng thái |
| P1 | Biên nhận báo giá có dòng phí, phụ thu, mã BG, thời điểm gửi và trạng thái | Cần xác nhận khả năng lưu/đọc chi tiết và quy tắc khách đồng ý; hiện app đối tác thừa nhận thiếu chi tiết sau tải lại | Khiếu nại về phí, tỉ lệ xem báo giá |
| P1 | Trạng thái đối tác dễ tin cậy: online, GPS, xe đang chọn, lần cập nhật gần nhất | Hiện trạng thái online và GPS có thể khác nhau; làm rõ khi mất kết nối | Số lần bỏ lỡ đơn do trạng thái sai hiểu |
| P1 | Lịch sử có tìm theo CH và lọc kết quả; mã KH/DT/CH/BG có nút sao chép | Tăng tốc hỗ trợ qua tổng đài, không tạo thêm dữ liệu nghiệp vụ | Thời gian tìm một đơn cũ |
| P2 | ETA và theo dõi xe trực tiếp | Chỉ triển khai khi có vị trí đối tác cập nhật đáng tin cậy, quyền riêng tư và quy tắc hết hạn | Sai số ETA, tỉ lệ GPS hợp lệ |
| P2 | Bằng chứng hoàn tất/ảnh và ghi chú thật | Cần lưu trữ, quyền truy cập, chống tranh chấp; hiện dialog có ô ghi chú bị vô hiệu | Tỉ lệ tranh chấp, đủ bằng chứng |
| P2 | Đặt hộ/người liên hệ thay thế, chia sẻ trạng thái đơn | Phù hợp tình huống cứu hộ ngoài đường; cần kiểm soát dữ liệu cá nhân | Tỉ lệ dùng và lỗi liên hệ |

## Quy tắc thiết kế tính năng chung

1. Dùng một ngôn ngữ trạng thái xuyên hai app: “Đã gửi → Đã nhận → Đang đến → Đang hỗ trợ → Hoàn tất”; phân biệt “Đã hủy”. Nếu trạng thái kỹ thuật có thêm `arrived`, mô tả bằng câu dễ hiểu.
2. Mã định danh mang nhãn đầy đủ lần đầu (`Mã khách hàng KH`, `Mã đối tác DT`, `Mã đơn CH`, `Mã báo giá BG`); sau đó dùng mã ngắn ở chỗ cần tra cứu. Không cho mã cạnh tranh với trạng thái/CTA.
3. Tách **giá dự kiến**, **báo giá đã gửi**, **chi phí hoàn tất**. Không dùng một con số để ngụ ý khách đã chấp thuận nếu chưa có trạng thái xác nhận.
4. Thông tin chưa có phải là trạng thái trống tử tế; không hiển thị mô phỏng như dữ liệu thời gian thực. Những câu “trong vài giây” chỉ nên dùng khi có số liệu vận hành chứng minh.

## Nguồn mã chính

`customer_app/lib/app/app_shell.dart`, `screens/new_request_screen.dart`, `screens/new_tracking_screen.dart`, `screens/history_details_screen.dart`, `widgets/tracking_ui.dart`; `rescuer_app/lib/main.dart`, `app/connected_app.dart`, `screens/preparation/preparation_screen.dart`, `active_job_panel.dart`, `job_finance_section.dart`.
