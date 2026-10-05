# Rà soát UI/UX app đối tác

Ngày 05/10/2026. **Entry point thực tế:** `main.dart` → `ConnectedRescuerApp` → `PreparationScreen`. Các file `screens/home`, `requests`, `active_job`, `history`, `account` tồn tại nhưng không được entry point này điều hướng trực tiếp; vì vậy báo cáo đánh giá các panel `screens/preparation/`. Đây là đánh giá tĩnh từ mã, chưa thử trên máy hoặc chụp màn hình. P0 = demo/luồng chính, P1 = trải nghiệm, P2 = tương lai.

## Nền thiết kế chung

Theme app dùng navy/cam, nền `#F5F7FA`, Roboto, tiêu đề 26, section 17, caption 12; `PreparationScreen` đặt max width 720, lề 18 dp, tab dưới cao 76. Một màn thường chứa nhiều `PreparationCard`, `AppCard`, `NavyPanel`, `StatusBadge`, `InfoBanner` và `AppButton`. Component đã tạo sự thống nhất cơ bản; vấn đề chính là **mật độ card, nhãn dài và CTA dàn đều** làm khó quét nhanh trong tình huống đang lái/đang tác nghiệp. Chuẩn đo là mục tiêu chạm 48 dp theo [Material](https://m2.material.io/design/layout/spacing-methods.html), chữ đủ tương phản theo [WCAG 2.2](https://www.w3.org/TR/wcag/); chưa kết luận cặp màu nào trượt khi chưa đo.

## 1. Dashboard / Trang chủ — P0

- **Mục tiêu:** Trong vài giây biết có được nhận đơn không, online hay offline, có chuyến đang xử lý không.
- **Đã ổn:** Có `PartnerHero`, tình trạng hồ sơ, online/GPS, checklist điều kiện, CTA mở đơn hoặc chuyến hiện tại (`preparation_screen.dart`).
- **Chưa ổn:** Trạng thái hồ sơ và checklist luôn chiếm nhiều diện tích, kể cả khi đối tác đã được duyệt; CTA vận hành nằm sau các card điều kiện.
- **Bố cục:** Hero → hồ sơ → online → checklist → CTA; thứ tự phù hợp onboarding nhưng chưa tối ưu cho đối tác đã hoạt động.
- **Chữ:** “Trạng thái phát tín hiệu”, “Điều kiện vận hành tiếp nhận”, “Định vị viễn thông GPS” mang giọng kỹ thuật; dùng câu ngắn “Sẵn sàng nhận đơn”, “Vị trí”.
- **Màu:** Navy panel/hero + nút cam + nhiều badge xanh/cam cùng lúc; cần để chỉ một tín hiệu mạnh cho trạng thái sẵn sàng.
- **Spacing:** Các card cách 18 dp, bên trong nhiều khoảng 12–16 dp; tổng chiều cao đầu trang lớn.
- **Card/nút:** Nhiều `AppButton` cùng dạng; CTA chính nên đổi theo trạng thái (Bật online / Xem đơn / Mở chuyến), action hồ sơ là phụ.
- **Chưa chuyên nghiệp:** Dashboard giống checklist đăng ký hơn bảng điều khiển sau khi đã được duyệt.
- **Sửa cụ thể:** Dashboard có hai trạng thái: chưa đủ điều kiện hiển thị checklist; đã đủ điều kiện đặt online + đơn/chuyến hiện tại ở màn đầu, thu checklist thành một hàng “Hồ sơ đã duyệt”.

## 2. Online/offline — P0

- **Mục tiêu:** Đối tác biết chắc khi nào đang nhận đơn và vì sao không thể bật online.
- **Đã ổn:** Có status text, GPS signal, chọn xe hoạt động, danh sách blocker, switch và nút lớn; có tiến trình cập nhật (`PreparationOnline`).
- **Chưa ổn:** Switch và nút “Bật/Tắt Online” làm cùng hành động; trạng thái `online` và `locationReady` có thể khác, nên “Đang online” chưa đồng nghĩa đang được định vị đúng.
- **Bố cục:** Trạng thái, GPS, dropdown, blocker, switch, nút, refresh trong một card dài; quyết định chính bị đẩy xuống.
- **Chữ:** Thống nhất “Trực tuyến/Ngoại tuyến” hoặc “Online/Offline”, tránh trộn “Đang Offline” và “Tắt Online”. Nêu rõ khi “Online · cần cập nhật GPS”.
- **Màu:** Xanh lá chỉ khi online **và** GPS sẵn sàng; vàng/cam cho trạng thái cần xử lý, không dùng xanh như hoàn tất.
- **Spacing:** Giữa status và nút chính hiện có nhiều thành phần; nhóm thông tin phụ cách 12–16 dp dưới CTA.
- **Card/nút:** Chọn một điều khiển chính dễ chạm; nếu giữ switch vì accessibility thì đặt sát nhãn và bỏ CTA trùng, hoặc CTA chỉ xuất hiện theo trạng thái cần sửa.
- **Chưa chuyên nghiệp:** Hai điều khiển tương đương làm người dùng không chắc cách nào là chính thức.
- **Sửa cụ thể:** Header card “Sẵn sàng nhận đơn” + chấm trạng thái + lần GPS gần nhất nếu có; một CTA bật/tắt; dưới mới hiện xe đang chọn và lỗi chặn. Không hứa hoạt động nền khi app chỉ cập nhật foreground.

## 3. Danh sách đơn mới — P0

- **Mục tiêu:** So sánh nhanh đơn phù hợp và quyết định xem thêm/nhận/bỏ qua.
- **Đã ổn:** Có filter dịch vụ, GPS, trạng thái tải/rỗng/lỗi, card loại dịch vụ, xe, mã CH, vùng gần đúng, khoảng cách và bỏ qua (`_feed`).
- **Chưa ổn:** Card hiển thị tọa độ làm tròn 3 chữ số thay cho tên khu vực; mỗi card đặt “Bỏ qua” và “NHẬN ĐƠN NGAY” đều full width, gây dài và nặng.
- **Bố cục:** Header → mô tả → GPS card → filter → danh sách; thông tin định vị chung đứng trước danh sách nên đẩy đơn xuống dưới fold.
- **Chữ:** “Khu vực gần đúng: 10.xxx, 106.xxx” khó hình dung; ưu tiên quận/khu vực nếu có dữ liệu geocoding, vẫn không lộ tọa độ chính xác. “Đơn cứu hộ trực tiếp” nên là “Đơn mới gần bạn”.
- **Màu:** Card xanh nhạt lồng trong card trắng + badge cam + nút chính; nhiều bề mặt cạnh tranh.
- **Spacing:** Card 12 dp cách nhau, nội dung địa điểm padding 16 dp, hai nút cách 10 dp; tăng mật độ bằng một hàng thông tin và action row.
- **Card/nút:** Card tóm tắt 4 thông tin: dịch vụ, loại xe, khoảng cách, khu vực; “Xem chi tiết” hoặc bấm toàn card, “Bỏ qua” phụ.
- **Chưa chuyên nghiệp:** Feed quyết định bằng tọa độ kỹ thuật thay cho địa danh thực tế.
- **Sửa cụ thể:** Đổi vùng tọa độ thành tên khu vực **nếu dữ liệu sẵn có**; nếu chưa, ghi “Vị trí gần đúng” và khoảng cách rõ, không giả địa danh; thu GPS card; phân cấp nút.

## 4. Chi tiết đơn trước khi nhận — P0 (chưa có màn riêng trong luồng chạy)

- **Mục tiêu:** Xem đủ thông tin được phép và xác nhận nhận đơn có chủ ý.
- **Đã ổn:** Card feed có dịch vụ, loại xe, khoảng cách, mã CH, vị trí gần đúng và che thông tin liên hệ/vị trí chính xác trước khi nhận. Đây là quyết định bảo vệ dữ liệu hợp lý.
- **Chưa ổn:** Trong `PreparationScreen._feed`, nút `claimRequest(r)` nằm ngay trên card; không có bước/màn chi tiết trước nhận. Các `RequestDetailsScreen` ở nhánh `screens/requests` không nằm trong entry point hiện tại.
- **Bố cục:** Cần một màn/sheet xem trước chứa tóm tắt, điều kiện thao tác và CTA nhận cố định; không lộ dữ liệu được bảo vệ.
- **Chữ:** Ghi “Thông tin hiện có trước khi nhận”, “Liên hệ và địa chỉ chính xác mở sau khi nhận”; tránh hứa thu nhập/ETA khi chưa có.
- **Màu:** Nút nhận dùng màu chính, bỏ qua dùng text/outline; màu badge “Đơn mới” là phụ.
- **Spacing:** Tóm tắt nên chia 2 nhóm cách 16–24 dp; CTA 48–56 dp, không chật dưới bottom nav.
- **Card/nút:** Nút “Xem chi tiết” từ feed; sau khi xem, “Nhận đơn” có trạng thái đang xử lý và phản hồi lỗi. Nếu không kịp thêm màn cho demo, ít nhất đổi card thành vùng mở chi tiết/sheet tĩnh từ dữ liệu hiện có.
- **Chưa chuyên nghiệp:** Nhận đơn trực tiếp trong feed làm luồng giống thao tác thử nghiệm, dễ bấm nhầm.
- **Sửa cụ thể:** P0 thiết kế màn/sheet xem trước bằng dữ liệu hiện có; xác minh tương tác thật trước khi triển khai vì cần kiểm tra controller/logic nhận đơn.

## 5. Đơn đang xử lý — P0

- **Mục tiêu:** Biết giai đoạn hiện tại, liên hệ khách, tới điểm cứu hộ và thực hiện một hành động tiếp theo.
- **Đã ổn:** Có mã CH, timeline, thông tin yêu cầu, khách, địa điểm, mở Google Maps khi có tọa độ, gọi điện và nút chuyển trạng thái (`active_job_panel.dart`).
- **Chưa ổn:** Nút “Tải lại chuyến” đứng trước toàn bộ thông tin và CTA chuyển trạng thái cuối màn. Card địa điểm ghi “Chưa tích hợp bản đồ trực tiếp” và “Chưa có ảnh hiện trường” như placeholder.
- **Bố cục:** Nhiều card liên tục: mã/trạng thái → reload → timeline → dịch vụ → khách → địa điểm → báo giá → CTA; tác vụ kế tiếp nằm rất xa đầu màn.
- **Chữ:** Nhãn tiến độ toàn chữ hoa (“ĐANG ĐẾN…”, “XÁC NHẬN…”) khó quét; câu placeholder nên viết thành thông tin hành động (“Mở chỉ đường” khi có tọa độ).
- **Màu:** Navy panel tốt cho trạng thái, nhưng cam ở icon/mã/giá/CTA cần phân vai nhất quán.
- **Spacing:** Mỗi card 16–20 dp; việc cuộn qua nhiều card trong tác nghiệp là rủi ro thao tác.
- **Card/nút:** Đặt CTA bước tiếp theo cố định hoặc gần đầu màn, với xác nhận phù hợp; Gọi và Chỉ đường là hai action phụ ngay dưới trạng thái. Reload là icon/action phụ.
- **Chưa chuyên nghiệp:** Placeholder bản đồ và ảnh làm luồng trông chưa hoàn thiện ngay giữa nhiệm vụ chính.
- **Sửa cụ thể:** Header trạng thái + địa điểm + Gọi/Chỉ đường + CTA kế tiếp trong viewport đầu; timeline và chi tiết thu gọn. Nếu không có ảnh, ẩn câu “Chưa có ảnh hiện trường” hoặc diễn đạt theo dữ liệu thật.

## 6. Báo giá BG — P0

- **Mục tiêu:** Nhập phí đúng, kiểm tra tổng, gửi cho khách và biết BG nào đang có hiệu lực.
- **Đã ổn:** Có phí chính, phụ thu, ghi chú, tổng dự kiến và validator; sau gửi hiển thị mã BG, tổng và các dòng phí nếu `currentQuote` còn trong bộ nhớ (`job_finance_section.dart`).
- **Chưa ổn:** Khi tải lại và `currentQuote == null`, màn chỉ có tổng và thông báo “chi tiết dòng phí và ghi chú chưa hỗ trợ tải lại”; đây là khoảng trống niềm tin về tiền.
- **Bố cục:** Toàn bộ form giá nằm sau nhiều card active job; người dùng phải cuộn sâu để nhập.
- **Chữ:** “Nhập số đồng, không có dấu phân cách” là hướng dẫn kỹ thuật; “TỔNG CHI PHÍ DỰ KIẾN · CHƯA GỬI” đúng trạng thái nhưng chữ hoa dày. Dùng ví dụ định dạng VND thân thiện.
- **Màu:** Tổng tiền cam cần đi kèm trạng thái “Dự kiến/Đã gửi”; tránh cùng màu với cảnh báo hoặc CTA mọi nơi.
- **Spacing:** Trường cách 14 dp, tổng 12 dp; ổn về nhịp, nhưng mật độ tăng khi bàn phím mở.
- **Card/nút:** Nút gửi đặt ngay sau tổng; sau gửi thì CTA hoàn tất phải rõ nhưng không thay thế thông tin báo giá.
- **Chưa chuyên nghiệp:** Có BG nhưng chi tiết không khôi phục khi mở lại, tạo cảm giác không có biên nhận đầy đủ.
- **Sửa cụ thể:** P0 sửa nhãn/tóm tắt và trạng thái gửi trung thực, tránh trình bày chi tiết dòng phí khi không có; P1 cần khả năng tải lại chi tiết trước khi gọi là biên nhận.

## 7. Hoàn tất đơn — P0

- **Mục tiêu:** Xác nhận đúng chuyến, đúng chi phí và kết thúc có chủ ý.
- **Đã ổn:** Có dialog xác nhận, tổng tiền, trạng thái đang lưu và lỗi; không đóng dialog khi đang lưu (`CompleteJobDialog`).
- **Chưa ổn:** Dialog chứa `TextField(enabled: false)` ghi “Ghi chú hoàn tất ... chưa hỗ trợ lưu”; đây là thành phần không dùng được xuất hiện ngay lúc quyết định cuối.
- **Bố cục:** Dialog vừa có ghi chú vô hiệu vừa có action; trên màn nhỏ/bàn phím cỡ chữ lớn có nguy cơ chật.
- **Chữ:** “Hoàn tất chuyến?” cần kèm mã CH/BG và câu xác nhận chi phí. Không để người dùng nghĩ có thể nhập ghi chú.
- **Màu:** Icon cam ổn cho hoàn tất nhưng trạng thái thành công nên dùng xanh lá, không lẫn màu CTA nhận đơn.
- **Spacing:** Bỏ ô vô hiệu sẽ giảm 18+ dp và giúp action nổi rõ.
- **Card/nút:** “Quay lại” và “Xác nhận hoàn tất” tách bậc rõ, vùng chạm đủ lớn.
- **Chưa chuyên nghiệp:** Input bị khóa với lời hẹn tính năng sau này khiến dialog giống bản thử nghiệm.
- **Sửa cụ thể:** Ẩn input vô hiệu ngay; hiển thị mã CH, BG, tổng tiền và xác nhận; sau thành công đưa tới trạng thái/chi tiết hoàn tất có thể kiểm chứng.

## 8. Lịch sử — P1

- **Mục tiêu:** Tìm chuyến cũ, mã CH/BG, chi phí và tiến trình kết thúc.
- **Đã ổn:** Có summary theo danh sách đã tải, filter, pagination, card trạng thái, mã CH và chi tiết BG/events (`history_panel.dart`).
- **Chưa ổn:** Summary đậm lớn, lặp tiêu đề, nút “Tải lại lịch sử” full width trước danh sách; chi tiết tải vào cuối trang thay vì màn riêng.
- **Bố cục:** Summary → tiêu đề + mô tả → filter → reload → card → chi tiết ở cuối; khó giữ ngữ cảnh khi mở đơn dài.
- **Chữ:** “Chi phí ghi nhận” có giải thích “chưa bao gồm thanh toán” tốt; nên đổi “Nhật ký tác nghiệp” thành nhãn ngắn hơn để quét nhanh.
- **Màu:** Số tiền cam trên navy dễ hút chú ý hơn danh sách; cân bằng với trạng thái.
- **Spacing:** 22 dp sau summary và 16 dp trước filter/nút; giảm bậc dọc cho danh sách.
- **Card/nút:** Mỗi card có CTA xem chi tiết; chuyển sang route/sheet riêng sẽ rõ hơn nếu tăng nội dung.
- **Chưa chuyên nghiệp:** Chi tiết nối vào cuối danh sách dễ khiến người dùng không nhận ra đã mở đúng chuyến.
- **Sửa cụ thể:** Rút gọn summary, đặt refresh trong header, ưu tiên tìm CH và chuyển chi tiết thành màn riêng; giữ giải thích số liệu đã tải.

## 9. Tài khoản / mã DT — P1

- **Mục tiêu:** Xem tình trạng đối tác và quản lý xe, dịch vụ, giấy tờ, GPS.
- **Đã ổn:** `PartnerHero` hiển thị mã đối tác; `AccountOverview` có xe, dịch vụ, giấy tờ, vận hành, GPS, bảo mật, hỗ trợ và editor từng mục.
- **Chưa ổn:** Tài khoản liệt kê đầy đủ từng xe/dịch vụ/giấy tờ rồi lại có chip editor; nhiều thông tin trùng. “Bảo mật tài khoản” và “Hỗ trợ kỹ thuật” mở dialog nói chưa có chức năng/kênh cấu hình.
- **Bố cục:** Tổng quan dài trước các chip chỉnh sửa; chọn mục có thể cuộn lại, nhưng vẫn mang cảm giác biểu mẫu quản trị.
- **Chữ:** “Mã đối tác DT” nên đặt cùng nút sao chép; các mục chưa hoạt động cần nhãn trung thực hoặc ẩn đến khi có đường xử lý.
- **Màu:** Hero và nhiều badge duyệt dễ quá tải; chỉ nổi bật trạng thái duyệt hiện tại, mục chi tiết dùng bề mặt nhẹ.
- **Spacing:** Các card cách 16 dp, tile con 10–14 dp; rút thành hàng tóm tắt để giảm cuộn.
- **Card/nút:** Một hàng cho mỗi nhóm có trạng thái/số lượng và chevron; editor ở màn con. Copy mã DT với feedback.
- **Chưa chuyên nghiệp:** Tác vụ bấm vào mục chỉ nhận thông báo “chưa hỗ trợ” dễ làm app trông chưa sẵn sàng.
- **Sửa cụ thể:** P0 ẩn/đổi các đường hỗ trợ chưa cấu hình trong demo; P1 tái cấu trúc tổng quan thành menu ngắn và một chi tiết/màn; thêm copy DT.

## Kiểm tra trực quan trước khi chốt

Chụp dashboard ở chưa duyệt/đã duyệt, online có GPS/không GPS, feed 1 và 5 đơn, active job ở từng trạng thái, báo giá trước/sau gửi/tải lại, dialog hoàn tất, lịch sử có 10 chuyến, tài khoản nhiều xe. Kiểm tra 360×800 dp, text scale 150%, bàn phím tiền tệ, hit target, CTA trong viewport và tương phản. Đây là bước xác nhận các rủi ro bố cục, không phải điều đã chứng minh bằng đọc mã.
