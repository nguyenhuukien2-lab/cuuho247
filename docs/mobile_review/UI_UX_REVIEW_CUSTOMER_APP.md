# Rà soát UI/UX app khách hàng

Ngày 05/10/2026. Phạm vi đang chạy: `AppShell` gắn `NewHomeScreen`, `NewRequestScreen`, `NewTrackingScreen`, `NewHistoryScreen`, `NewAccountScreen`. Màn chi tiết lịch sử và chỉnh sửa hồ sơ mở ngoài tab. Nhận xét dựa trên mã nguồn, chưa đo bằng screenshot/thiết bị; các vấn đề thị giác được ghi là **rủi ro cần kiểm chứng**. P0 = ảnh hưởng demo và luồng chính, P1 = nâng trải nghiệm, P2 = về sau.

## Nền thiết kế chung

`app_theme.dart` định nghĩa navy/cam, nền `#F5F7FA`, radius card 20 và không đổ bóng; nhưng năm màn tab bọc `BookingStyle.theme()` với xanh `#1D4ED8`, xanh lá, nền `#F8F9FF`, card radius 22 có bóng. Header và bottom nav cũng có cách dùng khác. Đây là nguyên nhân cụ thể khiến app có cảm giác nhiều bộ nhận diện. Các khoảng cách 16/20/24 có sẵn nhưng chưa tạo quy tắc ổn định giữa trang, card và form. Mục tiêu kiểm tra: mép trang thống nhất 16 hoặc 20 dp, một thang chữ, một màu CTA, một kiểu card; chữ phụ đo tương phản theo [WCAG 2.2](https://www.w3.org/TR/wcag/), vùng chạm theo [Material](https://m2.material.io/design/layout/spacing-methods.html).

## 1. Trang chủ — P0

- **Mục tiêu:** Người gặp sự cố nhận ra ngay hành động đặt cứu hộ, vị trí hiện tại và đơn đang chạy.
- **Đã ổn:** Có lời chào/vị trí, banner đơn đang xử lý, CTA lớn, nhóm dịch vụ, cam kết và mẹo an toàn (`new_home_screen.dart`, `home_ui.dart`).
- **Chưa ổn:** Có nhiều lớp nội dung trước và sau hành động chính; câu “tìm đối tác gần bạn trong vài giây” là lời hứa chưa được chứng minh trong UI.
- **Bố cục:** Header chung + vị trí + banner đơn + hero + lưới + cam kết + carousel tạo trang dài. Khi có đơn hoạt động, banner và hero “tạo yêu cầu” cùng nổi bật.
- **Chữ:** CTA toàn chữ hoa “YÊU CẦU CỨU HỘ NGAY” và nhiều câu mang tính quảng cáo; nhãn “Dịch vụ tại chỗ” có thể không bao quát kéo xe.
- **Màu:** Hero dùng xanh của `BookingStyle`, tab/nav chịu theme gốc navy/cam; kiểm tra độ nhất quán và tương phản trên thiết bị.
- **Spacing:** Dùng liên tiếp 16/24 dp giữa khối, nhưng lưới card có thông tin dài có thể làm các ô lệch chiều cao.
- **Card/nút:** Hero và service card đều dẫn tới cùng form; cần phân biệt CTA chính và đường tắt dịch vụ. Nút “Theo dõi” trên banner có thể nhỏ trong hàng ngang.
- **Chưa chuyên nghiệp:** Trộn mục tiêu khẩn cấp với carousel nội dung và lời hứa tốc độ dễ làm trang giống landing page hơn màn tác nghiệp.
- **Sửa cụ thể:** Đưa “Bạn cần hỗ trợ gì?” + CTA rõ ở màn đầu; khi có đơn, ưu tiên card theo dõi, giảm hero; chuyển mẹo an toàn xuống dưới; viết “Đặt cứu hộ”/“Xem đơn đang xử lý”; đo trạng thái trên màn 360 dp.

## 2. Đặt cứu hộ — P0

- **Mục tiêu:** Tạo yêu cầu đúng dịch vụ, xe, địa điểm, ảnh và liên hệ với ít sai sót nhất.
- **Đã ổn:** Có 5 bước, chọn xe/địa chỉ đã lưu, GPS hoặc nhập tay, ảnh tối đa 3, kiểm tra thông tin trước gửi, báo lỗi và giữ bản nháp trong `IndexedStack` (`new_request_screen.dart`).
- **Chưa ổn:** Năm bước cho tình huống khẩn cấp làm tăng chi phí thao tác; ở bước cuối có cả tóm tắt và `QuoteSummaryCard` dù giá chưa chốt.
- **Bố cục:** Step indicator riêng trên đầu, nội dung cuộn ở giữa, CTA cố định dưới cùng; cần kiểm tra vùng hiển thị thực tế khi bàn phím mở, chữ phóng to và bottom nav vẫn hiện.
- **Chữ:** Tên bước “Mô tả / ảnh” chưa nói ảnh tùy chọn; phải nói rõ GPS không thay thế xác nhận địa chỉ. Không để “báo giá” bị hiểu là giá cuối trước gửi.
- **Màu:** Form dùng xanh `BookingStyle` còn theme gốc navy/cam; trạng thái lỗi/đã chọn cần một quy ước màu xuyên 5 bước.
- **Spacing:** `AppSpacing.page` 16 dp trong form nhưng header/step indicator dùng 16 dp khác với trang chủ 20 dp; nhiều khoảng 12/16/24 nội bộ cần chuẩn hóa.
- **Card/nút:** Mỗi bước là card lớn; phần chọn sự cố và chọn xe có thể chiếm nhiều chiều cao. Nút bước tiếp theo cố định hữu ích nhưng phải tránh che nội dung và thông báo lỗi.
- **Chưa chuyên nghiệp:** Form “wizard” tạo cảm giác khảo sát dài, chưa giống luồng cứu hộ cần nhập nhanh; giá dự kiến dễ bị hiểu nhầm.
- **Sửa cụ thể:** Trình bày tiến trình bằng số bước và tên ngắn; gộp/chỉ thu gọn trường phụ, ưu tiên sự cố + vị trí + liên hệ; bước cuối hiển thị rõ “Giá sẽ được đối tác báo sau”; kiểm tra 360 dp, bàn phím, text scale 150%; không bỏ xác nhận vị trí.

## 3. Theo dõi đơn — P0

- **Mục tiêu:** Biết trạng thái hiện tại, bước tiếp theo, vị trí, báo giá và cách nhận hỗ trợ.
- **Đã ổn:** Có card trạng thái, thời gian cập nhật nếu có, timeline, vị trí, mã CH, ảnh, báo giá BG/tổng tiền, cập nhật thủ công, hỗ trợ và hủy theo điều kiện (`new_tracking_screen.dart`, `tracking_ui.dart`).
- **Chưa ổn:** `RescuerInfoCard` xuất hiện từ khi được nhận nhưng chỉ ghi “Kỹ thuật viên / Chưa có dữ liệu”; `LiveMetricsGrid` chỉ ghi “Đang cập nhật”, không có ETA thực.
- **Bố cục:** Status → map → card KTV → timeline → giá → chi tiết → cập nhật → hỗ trợ; hành động liên hệ/hỗ trợ và số tiền nằm thấp. Màn dài ở trạng thái đang xử lý.
- **Chữ:** “Trực tiếp” dễ gợi ý có tracking thời gian thực; thực tế model chưa có telemetry. Thông báo thiếu dữ liệu quá chung, cần nói rõ “Thông tin đối tác sẽ hiển thị khi có”.
- **Màu:** Xanh lá trạng thái live, xanh dương CTA và giá có thể cạnh tranh; trạng thái báo giá cần màu riêng theo đã gửi/chưa có.
- **Spacing:** Mỗi card cách 16 dp, timeline có 6 bước và card địa điểm; kiểm tra chiều dài trên màn nhỏ.
- **Card/nút:** Nút refresh và hỗ trợ nên ở gần trạng thái hiện tại; mã CH cần sao chép dễ dàng. Hủy chỉ là text button ở cuối phù hợp mức ưu tiên thấp.
- **Chưa chuyên nghiệp:** Card “Kỹ thuật viên” trống và vùng “Đang cập nhật” giống placeholder demo hơn sản phẩm đã kết nối.
- **Sửa cụ thể:** Trên cùng: trạng thái + thời điểm cập nhật + hành động phù hợp; chỉ hiện card đối tác khi có dữ liệu thật, nếu thiếu dùng một dòng giải thích; gộp timeline có thể thu gọn; hiển thị giá ngay khi có BG; nhãn “Trạng thái cập nhật” thay cho live khi không có vị trí đối tác.

## 4. Lịch sử — P1

- **Mục tiêu:** Tìm lại đơn và chi phí, mở chi tiết để hỗ trợ/đánh giá.
- **Đã ổn:** Có tổng chuyến đã tải, lọc tất cả/hoàn tất/đã hủy, trạng thái trống và card mã CH, xe, địa điểm, chi phí (`new_history_screen.dart`, `history_ui.dart`).
- **Chưa ổn:** Chưa thấy tìm nhanh theo mã CH; summary card lớn đứng trước danh sách, card mỗi đơn có nhiều hộp lồng.
- **Bố cục:** `HistorySummaryCard` + filter + card đầy đủ thông tin + banner hỗ trợ làm danh sách có mật độ thấp.
- **Chữ:** “Nhật Ký Cứu Hộ An Toàn”, “Tổng chuyến” hơi trang trọng và dài; “Chi phí / báo giá” gộp hai trạng thái khác nhau.
- **Màu:** Card summary đậm và số tiền nhấn màu làm trạng thái đơn kém nổi; đo tương phản nhãn phụ.
- **Spacing:** Summary 24 dp, filter 24 dp, mỗi card 16 dp; giảm chiều cao mỗi hàng để quét danh sách nhanh.
- **Card/nút:** Một card đơn nên ưu tiên dịch vụ + ngày + trạng thái + mã CH + số tiền, mở chi tiết bằng toàn card hoặc nút rõ.
- **Chưa chuyên nghiệp:** Banner cố định về hỗ trợ sau cứu hộ lặp ở mọi lần xem lịch sử, trong khi mục tiêu chính là tìm đơn.
- **Sửa cụ thể:** Thu gọn summary thành một hàng; thêm tìm mã CH khi dữ liệu/độ dài danh sách đủ; tách nhãn “Báo giá” với “Chi phí cuối” dựa trên trạng thái; hỗ trợ đặt trong chi tiết.

## 5. Tài khoản — P1

- **Mục tiêu:** Xem hồ sơ, xe và địa chỉ lưu; tới cài đặt và hỗ trợ.
- **Đã ổn:** Có profile card, xe, địa chỉ, cài đặt, đăng xuất xác nhận; xử lý loading/error riêng cho dữ liệu lưu (`new_account_screen.dart`).
- **Chưa ổn:** “Thêm phương tiện mới” và “Quản lý xe đã lưu” cùng một đường đi; nhiều mục dài trước cài đặt/hỗ trợ.
- **Bố cục:** Profile → xe → địa chỉ → cài đặt → đăng xuất; khi có nhiều xe/địa chỉ, màn trở thành danh sách dài không phân cấp.
- **Chữ:** Dùng thống nhất “Xe của tôi”, “Địa chỉ thường dùng”, “Thông tin cá nhân”; tránh nhãn hai nghĩa cho cùng nút.
- **Màu:** Nút thêm xe dùng xanh nhạt cứng `#DCE9FF`, trong khi theme chung có `selected`/`orangeSoft`; cần chuẩn hóa.
- **Spacing:** Khối chính 24 dp, item xe 12 dp; thống nhất với các tab khác.
- **Card/nút:** Chỉ một CTA “Quản lý xe” dẫn tới trang xe; đặt “Thêm xe” trong trang đó hoặc CTA phụ khi chưa có xe.
- **Chưa chuyên nghiệp:** Hai nút cùng đích và nhiều card nội dung tài khoản làm giao diện giống form quản trị.
- **Sửa cụ thể:** Tài khoản là danh sách mục ngắn với số lượng, profile card trên đầu; giữ CTA chỉnh sửa rõ; đẩy chi tiết xe/địa chỉ sang màn quản lý.

## 6. Hồ sơ / mã KH — P1

- **Mục tiêu:** Xác nhận danh tính tài khoản và mã dùng khi liên hệ hỗ trợ.
- **Đã ổn:** `CustomerProfileCard` hiển thị “Mã khách hàng”, tên, liên hệ và hành động chỉnh sửa; có màn editor và trạng thái lưu.
- **Chưa ổn:** Mã KH là text trong card, chưa thấy affordance sao chép; profile card dạng `royal` có nguy cơ nhấn quá mạnh so với tác vụ chính của tab.
- **Bố cục:** Avatar, mã, tên và thông tin phụ trong một khối; màn editor riêng hợp lý.
- **Chữ:** Mã khách hàng nên có mẫu `KH…` dễ đọc/copy, giải thích ngắn “Dùng khi liên hệ hỗ trợ”.
- **Màu:** Card nổi bật cần giữ tương phản chữ/mã; không dùng màu trạng thái cứu hộ cho trang cá nhân.
- **Spacing:** Mã và tên nên cách 4–8 dp; nút chỉnh sửa cách 16 dp, giữ vùng chạm 48 dp.
- **Card/nút:** Thêm nút copy cạnh mã; chỉ một CTA chỉnh sửa hồ sơ.
- **Chưa chuyên nghiệp:** Mã dạng nội dung tĩnh buộc người dùng ghi nhớ/chép tay khi gọi hỗ trợ.
- **Sửa cụ thể:** Mã KH trên một hàng có copy + feedback “Đã sao chép”; editor giữ nhãn trường và lỗi tại trường.

## 7. Mã đơn CH — P0

- **Mục tiêu:** Định danh đơn để tra cứu khi theo dõi, xem lịch sử, gọi hỗ trợ.
- **Đã ổn:** Mã lấy qua `displayCode`, hiện ở tracking status, chi tiết tracking, card lịch sử và chi tiết lịch sử.
- **Chưa ổn:** Trong tracking mã lặp hai lần; chữ mã trong status card cỡ 11, dễ chìm. Chưa thấy nút copy chuyên dụng.
- **Bố cục:** Mã nên ở cùng trạng thái đầu màn và cuối biên nhận, không lặp trong `MoreDetails` nếu không có lý do.
- **Chữ:** Nhãn “Mã đơn CH” lần đầu; hiển thị mã nguyên vẹn, không co nhỏ quá mức.
- **Màu:** Mã là thông tin phụ quan trọng, dùng màu chữ đủ tương phản thay vì màu nhạt quá.
- **Spacing:** Đặt copy cách mã 8 dp và tối thiểu 48 dp vùng chạm.
- **Card/nút:** Chip copy mã, không tạo thêm card riêng chỉ cho mã.
- **Chưa chuyên nghiệp:** Mã lặp nhưng lại khó sao chép khi gọi tổng đài.
- **Sửa cụ thể:** Một vị trí rõ ở tracking header và lịch sử chi tiết; copy với thông báo ngắn; kiểm tra mã dài trên 360 dp.

## 8. Báo giá BG — P1 (tính năng hiện có ở mức tổng tiền)

- **Mục tiêu:** Hiểu giá, nguồn giá và mã báo giá trước khi kết thúc hỗ trợ.
- **Đã ổn:** `QuoteStatusCard(price, quoteCode)` trong tracking; `history_details_screen.dart` có mã BG khi có; lịch sử card hiển thị giá.
- **Chưa ổn:** UI hiện chủ yếu có tổng tiền/mã; chưa thấy chi tiết dòng phí hoặc trạng thái khách chấp thuận trong app khách. Đây là thiếu dữ liệu/luồng, không chỉ là lỗi visual.
- **Bố cục:** Card giá sau timeline, dễ bị bỏ qua nếu người dùng cuộn ít.
- **Chữ:** Phân biệt “Chưa có báo giá”, “Đối tác đã gửi báo giá”, “Chi phí hoàn tất”. Không dùng một nhãn “Chi phí / báo giá” cho mọi giai đoạn.
- **Màu:** Giá nhấn rõ nhưng không dùng màu đỏ như lỗi; cảnh báo phí phát sinh cần nhãn riêng.
- **Spacing:** Tách tổng tiền khỏi mã BG và thời gian gửi bằng 8–12 dp; phần chi tiết phí có thể thu gọn.
- **Card/nút:** Nếu chỉ có tổng, thể hiện trung thực “Chi tiết phí chưa có trong ứng dụng”; khi có dữ liệu thì dòng phí + tổng. Nút hỗ trợ đặt gần báo giá.
- **Chưa chuyên nghiệp:** Có mã BG nhưng không giải thích khách đang xem báo giá hay biên nhận cuối.
- **Sửa cụ thể:** Sửa microcopy theo trạng thái ngay P1; bản chi tiết phí và xác nhận khách là nghiên cứu P2, chỉ đề xuất sau khi xác minh dữ liệu/luồng.

## Điểm cần kiểm tra trực quan trước khi chốt

Chụp 5 tab ở trạng thái rỗng/có dữ liệu, bước 1 và 5 của form, tracking ở searching/accepted/in-progress, lịch sử 3 đơn, tài khoản nhiều xe. Đo trên Android 360×800 dp và máy màn nhỏ hơn, cỡ chữ 100%/150%, bàn phím mở; kiểm tra tràn chữ, đáy CTA/bottom nav, vùng chạm, tương phản và thời gian tìm được nút tiếp theo. Không suy ra các lỗi render này chỉ từ mã nguồn.
