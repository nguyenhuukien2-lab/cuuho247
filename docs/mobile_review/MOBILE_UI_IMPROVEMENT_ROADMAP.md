# Roadmap cải thiện UI hai app mobile

Ngày 05/10/2026. Roadmap này là kế hoạch đề xuất, **chưa thay đổi code**. Cơ sở: hai báo cáo UI/UX trong thư mục này, luồng thực chạy của `AppShell` và `PreparationScreen`. P0 dành cho demo/bảo vệ; P1 nâng trải nghiệm; P2 chỉ triển khai khi có dữ liệu và nghiệp vụ phù hợp.

## Nguyên tắc quyết định

1. Mỗi màn có một hành động chính phù hợp trạng thái; hành động phụ không cùng trọng lượng màu/kích thước.
2. Trong viewport đầu, trả lời được: “Tôi đang ở đâu?”, “Điều gì đang xảy ra?”, “Tôi làm gì tiếp?”.
3. Mã KH/DT/CH/BG phục vụ tra cứu và sao chép; trạng thái và CTA luôn được ưu tiên thị giác hơn mã.
4. Giữ dữ liệu thật: không giả ETA, bản đồ xe, thông tin KTV, phí chi tiết hoặc địa danh geocode khi chưa có nguồn.
5. Chuẩn thị giác đề xuất: một palette xuyên hai app (navy nền tảng, cam CTA/cứu hộ, xanh lá thành công), spacing 4/8/12/16/24/32 dp, page gutter 16–20 dp, card radius 16–20 dp, tiêu đề 20–24 sp, body 14–16 sp, nhãn phụ tối thiểu 12 sp; kiểm tra trên thiết bị trước khi chốt. Target 48×48 dp, tương phản chữ thường 4.5:1.

## P0 — sửa ngay để demo/bảo vệ

| Thứ tự | Hạng mục | Màn / việc cụ thể | Tiêu chí nghiệm thu quan sát được |
|---|---|---|---|
| 1 | Chốt hệ UI chung | Hai app; tập trung `BookingStyle` của khách và `AppTheme` | Một màu CTA chính, một thang chữ/spacing/card; 5 tab khách và 5 tab đối tác nhìn cùng họ; không tràn trên 360 dp |
| 2 | Đặt cứu hộ | 5 bước và màn xác nhận | Bước hiện tại rõ; lỗi tại trường; vị trí được xác nhận; CTA không bị bàn phím/bottom nav che; giá chưa chốt được nói rõ |
| 3 | Theo dõi đơn | Status, đối tác, báo giá, hỗ trợ | Trạng thái + thời gian cập nhật + CTA trong viewport đầu; card KTV thiếu dữ liệu không trông như placeholder; không dùng “trực tiếp” khi không có telemetry |
| 4 | Dashboard đối tác | Trạng thái sẵn sàng và CTA | Người đã duyệt thấy online/đơn/chuyến trước checklist; người chưa duyệt thấy đúng việc phải hoàn thành |
| 5 | Online/offline | GPS, xe hoạt động, điều khiển | Chỉ một điều khiển chính; phân biệt online và GPS chưa sẵn sàng; blocker rõ, không thể hiểu nhầm đã nhận đơn |
| 6 | Feed + xem trước đơn | Danh sách và bước trước nhận | Card tóm tắt quét nhanh; thông tin bảo vệ không lộ; có bước xem trước/đọc đủ dữ liệu trước nhận, hoặc sheet tương đương |
| 7 | Đơn đang xử lý | CTA chuyển trạng thái, Gọi, Chỉ đường | Hành động tiếp theo trong viewport đầu; reload là phụ; không để placeholder bản đồ/ảnh chiếm chỗ |
| 8 | Báo giá và hoàn tất | BG, tổng tiền, dialog | Trạng thái giá rõ “dự kiến/đã gửi”; không hiện input hoàn tất bị khóa; dialog có mã CH/BG và tổng, báo lỗi rõ |
| 9 | Chạy walkthrough demo | Hai app, một đơn xuyên luồng | Mọi nhãn CH/BG/DT/KH nhất quán; không xuất hiện nội dung “chưa hỗ trợ” trong đường demo đã chọn |

**Phụ thuộc:** Thứ tự 1 nên làm trước để các màn không phải sửa lại màu/chữ. Feed xem trước đơn (6) có thể cần thay đổi điều hướng app; báo giá chi tiết sau tải lại không thể giải quyết đầy đủ bằng UI nếu dữ liệu chưa được cung cấp, nên P0 chỉ sửa cách trình bày trung thực.

## P1 — nâng cấp trải nghiệm

| Hạng mục | Phạm vi | Kết quả mong muốn |
|---|---|---|
| Rút gọn trang chủ khách | Hero, danh sách dịch vụ, banner đơn, nội dung mẹo | Đơn đang chạy được ưu tiên; nội dung giáo dục ít cản đường cứu hộ |
| Thu gọn lịch sử hai app | Summary, filter, chi tiết | Quét danh sách nhanh; tìm theo CH; chi tiết không mọc ở cuối danh sách |
| Tài khoản hai app | Xe/địa chỉ/dịch vụ/giấy tờ, mã KH/DT | Tổng quan ngắn, màn quản lý riêng; copy mã có phản hồi |
| Báo giá có biên nhận | Hai app | Xem lại dòng phí/phụ thu/ghi chú sau tải lại khi dữ liệu được hỗ trợ; nhãn giá chính xác theo giai đoạn |
| Trạng thái offline và lỗi | Hai app | Retry gần lỗi, giải thích hành động, giữ ngữ cảnh sau khi kết nối lại |
| Khả năng đọc/chạm | Hai app | Text scale 150%, vùng chạm >=48 dp, không mất CTA, tương phản đạt ngưỡng |

## P2 — tính năng về sau

| Ý tưởng | Điều kiện mở khóa | Rủi ro cần nghiên cứu |
|---|---|---|
| ETA và xe đối tác trên bản đồ khách | Vị trí đối tác cập nhật đáng tin cậy và quyền riêng tư được thiết kế | ETA sai gây mất niềm tin; tiêu thụ pin |
| Khách chấp thuận báo giá trong app | Quy tắc nghiệp vụ rõ về sửa báo giá, hoàn/huỷ, chậm phản hồi | Tranh chấp giá và trạng thái |
| Bằng chứng hoàn tất | Lưu ảnh/chữ ký/ghi chú, phân quyền truy cập | Dữ liệu cá nhân và tranh chấp |
| Chia sẻ trạng thái, đặt hộ | Sự đồng ý và giới hạn thông tin khi chia sẻ | Lộ vị trí/liên hệ |
| Hỗ trợ trong app | Có kênh vận hành thật và SLA | Nút hỗ trợ không ai phản hồi |

## Kế hoạch kiểm chứng

| Mốc | Thiết bị/trạng thái | Câu hỏi kiểm tra |
|---|---|---|
| Trước P0 | Android 360×800 dp và màn lớn, text scale 100%/150% | Có thấy CTA, mã, trạng thái không? Có tràn/che khi bàn phím mở không? |
| Sau P0 | Walkthrough một đơn: tạo → nhận → đến → báo giá → hoàn tất | Người mới có giải thích được bước tiếp theo trong 5 giây không? Có nội dung giả/chưa hỗ trợ trong đường demo không? |
| Sau P1 | 3–5 người thử theo vai khách/đối tác | Tìm lại CH/BG, bật online, xem giá và sửa địa chỉ mất bao lâu? |

Nguồn chuẩn: [Apple touch controls](https://developer.apple.com/design/tips/), [Material spacing/touch targets](https://m2.material.io/design/layout/spacing-methods.html), [WCAG 2.2](https://www.w3.org/TR/wcag/). Mốc và số đo là tiêu chí thiết kế đề xuất, không phải kết quả kiểm thử đã đạt.
