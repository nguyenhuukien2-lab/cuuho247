# Review giao diện thanh toán khách hàng — Stitch 15211892260039587534

Ngày review: 10/10/2026. Workspace: `D:\DAndroidStudioProjects\flutter_app`.

Chỉ đọc Stitch, source Flutter/backend và tài liệu hiện có. Thay đổi duy nhất của tác vụ này là báo cáo này. Không sửa Dart/pubspec/backend/RPC/RLS, không chạy migration, không tải asset vào workspace, không chạy app/test/build, không commit. Các sửa đổi và file untracked đã có trong workspace trước review được giữ nguyên.

## 1. Project, nguồn bằng chứng và giới hạn

- MCP server: `stitch`; gọi trực tiếp `get_project(projects/15211892260039587534)`, `list_screens(projectId=15211892260039587534)`, rồi `get_screen` cho mọi sourceScreen của project. Không tìm project khác.
- Tên project: **Cứu Hộ 24/7 Partner App**; quyền OWNER; PRIVATE; MOBILE; TEXT_TO_UI_PRO. Tuy tên là Partner App, nội dung 6 screen hiện hành là CUSTOMER payment.
- Project tạo 02/10/2026 08:42:42 UTC; cập nhật 10/10/2026 13:18:40 UTC.
- `list_screens` trả **6 screen hiện hành**. `get_project.screenInstances` có **35 instance**, gồm **32 sourceScreen khác nhau** (6 hiện + 26 hidden) và **3 design-system instance**, không phải 35 màn ứng dụng.
- 32 resource gồm **28 UI screen + 4 ảnh/logo/reference**. Đã gọi get_screen cho cả 32. Có 29 HTML URL (bao gồm HTML logo), 31 screenshot URL; riêng `d4244d...` không có screenshot URL.
- Có **6 màn payment chuyên biệt**; thêm **2 màn tài khoản chứa phần phương thức/VAT** và **4 màn theo dõi/lịch sử chứa ngữ cảnh giá/hóa đơn**. Các màn đặt cứu hộ có báo giá dự tính được ghi nhận nhưng không coi là giao dịch payment.
- Đã đọc toàn bộ 29 HTML: 6 payment đọc đầy đủ CSS/structure/script; 23 hidden đọc nội dung HTML đã loại script/style để phân loại; 2 màn tài khoản trong số này đọc thêm structure phần payment/VAT.
- Đã xem screenshot cả 6 payment, 2 màn tài khoản và 3 resource chỉ có ảnh. Không tuyên bố đã soi visual chi tiết mọi màn không phải payment.
- Trình đọc web không mở được URL ảnh Google. Đã đọc lại URL do Stitch cung cấp và hiển thị preview trực tiếp từ bộ nhớ; không lưu ảnh, HTML, font hay QR thành asset/file trong workspace.
- CSS dưới đây là giá trị khai báo trong HTML/Tailwind và phép quy đổi rem thông thường 16 px. Không chạy browser để đo computed layout. Chiều cao tự co theo nội dung được ghi rõ; không biến ước lượng thành số đo.
- Review backend dựa trên source migrations/RPC + Dart + tài liệu GD1–GD4 trong working tree, **không kết nối database production**. “REAL NOW” trong báo cáo nghĩa là đã có contract/source hiện tại, không phải chứng nhận production đã deploy.

## 2. Toàn bộ screen list, IDs, dimensions và availability

Cột “resource” là width/height từ get_screen, không phải kích thước Flutter dp. Cột “canvas” là kích thước instance; không tự coi canvas height là chiều cao screenshot. Link ảnh/HTML ở bảng trỏ tới URL trả trực tiếp từ MCP, có thể hết hạn về sau.

| # | Screen name | Screen ID | Resource px | Canvas | Hiển thị | Screenshot | HTML | Phân loại |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | {F3B05EAC-EDA3-47B4-885C-D1E7B1E6BE11}.png | `7459672242727792880` | 1083 × 98 | 512 × 46 | Ẩn | [Có][img-7459672242727792880] | Không | Ảnh tham chiếu canvas |
| 2 | Trạng thái Xác minh Hồ sơ | `06c2a74b70b24267b7f1831431e17132` | 780 × 2596 | 390 × 1310 | Ẩn | [Có][img-06c2a74b70b24267b7f1831431e17132] | [Có, đã đọc][html-06c2a74b70b24267b7f1831431e17132] | Không phải payment khách hàng |
| 3 | Customer App - Theo Dõi (Xanh Tech) | `13c6068d371b4f9cbbb2fdaed2bfdb47` | 780 × 3964 | 492 × 1868 | Ẩn | [Có][img-13c6068d371b4f9cbbb2fdaed2bfdb47] | [Có, đã đọc][html-13c6068d371b4f9cbbb2fdaed2bfdb47] | Ngữ cảnh: theo dõi + báo giá |
| 4 | Trang chủ - Sẵn sàng nhận đơn | `17810f18484c45f8a7eab51869ce7908` | 780 × 2304 | 390 × 1151 | Ẩn | [Có][img-17810f18484c45f8a7eab51869ce7908] | [Có, đã đọc][html-17810f18484c45f8a7eab51869ce7908] | Không phải payment khách hàng |
| 5 | Customer App - Trang Chủ V2 | `206ebde95ce344b48c691861024b2e4d` | 780 × 3444 | 390 × 1719 | Ẩn | [Có][img-206ebde95ce344b48c691861024b2e4d] | [Có, đã đọc][html-206ebde95ce344b48c691861024b2e4d] | Không phải payment khách hàng |
| 6 | Customer App - Lịch Sử (Xanh Tech) | `23b62b9902a946a7b99979413ba794f7` | 780 × 2984 | 659 × 1463 | Ẩn | [Có][img-23b62b9902a946a7b99979413ba794f7] | [Có, đã đọc][html-23b62b9902a946a7b99979413ba794f7] | Ngữ cảnh: lịch sử + hóa đơn |
| 7 | Rescuer App - Trang Chủ V2 | `3217cfce0239451f9dfd04f6d6169fe7` | 780 × 3098 | 390 × 1547 | Ẩn | [Có][img-3217cfce0239451f9dfd04f6d6169fe7] | [Có, đã đọc][html-3217cfce0239451f9dfd04f6d6169fe7] | Không phải payment khách hàng |
| 8 | Đăng nhập Đối tác | `398a688b68ea408481f628ffb814238b` | 780 × 2040 | 390 × 1019 | Ẩn | [Có][img-398a688b68ea408481f628ffb814238b] | [Có, đã đọc][html-398a688b68ea408481f628ffb814238b] | Không phải payment khách hàng |
| 9 | Customer Bank Verifying | `59a97c6c9d9c443a87671e93a29f3f3c` | 780 × 1944 | 390 × 954 | Hiện | [Có][img-59a97c6c9d9c443a87671e93a29f3f3c] | [Có, đã đọc][html-59a97c6c9d9c443a87671e93a29f3f3c] | Payment chính |
| 10 | Customer App - Đặt Cứu Hộ V2 | `694460bce8a042368f984c67e29c40af` | 780 × 3170 | 390 × 1566 | Ẩn | [Có][img-694460bce8a042368f984c67e29c40af] | [Có, đã đọc][html-694460bce8a042368f984c67e29c40af] | Không phải payment khách hàng |
| 11 | Customer Cash Awaiting | `6b12b965628e4666911b7d2f011bde09` | 780 × 2442 | 390 × 1205 | Hiện | [Có][img-6b12b965628e4666911b7d2f011bde09] | [Có, đã đọc][html-6b12b965628e4666911b7d2f011bde09] | Payment chính |
| 12 | Customer App - Tài Khoản (Xanh Tech) | `753b331a6ffa4341aadfafde01a881a0` | 780 × 3544 | 558 × 1734 | Ẩn | [Có][img-753b331a6ffa4341aadfafde01a881a0] | [Có, đã đọc][html-753b331a6ffa4341aadfafde01a881a0] | Liên quan: phương thức đã lưu/VAT; future |
| 13 | {397E63BA-525A-4C89-957F-CF0855A35F8C}.png | `1553543826145774209` | 1041 × 50 | 512 × 25 | Ẩn | [Có][img-1553543826145774209] | Không | Ảnh tham chiếu canvas |
| 14 | Customer App - Đặt Cứu Hộ (Xanh Tech) | `83799155581b493085050ef9808ace01` | 780 × 3124 | 531 × 1555 | Ẩn | [Có][img-83799155581b493085050ef9808ace01] | [Có, đã đọc][html-83799155581b493085050ef9808ace01] | Không phải payment khách hàng |
| 15 | Customer Payment Method | `83d8804a503246e2bf3e89baf949da16` | 780 × 2244 | 390 × 1092 | Hiện | [Có][img-83d8804a503246e2bf3e89baf949da16] | [Có, đã đọc][html-83d8804a503246e2bf3e89baf949da16] | Payment chính |
| 16 | Customer App - Trang Chủ (Xanh Tech) | `895f01efe5d244ceaf7a02b3cdb7ca53` | 780 × 4200 | 617 × 1693 | Ẩn | [Có][img-895f01efe5d244ceaf7a02b3cdb7ca53] | [Có, đã đọc][html-895f01efe5d244ceaf7a02b3cdb7ca53] | Không phải payment khách hàng |
| 17 | Đăng ký Đối tác - Phương tiện | `8fa1ff44887b48779665883082a01bc6` | 780 × 4444 | 390 × 2198 | Ẩn | [Có][img-8fa1ff44887b48779665883082a01bc6] | [Có, đã đọc][html-8fa1ff44887b48779665883082a01bc6] | Không phải payment khách hàng |
| 18 | Rescuer App - Đơn Mới V2 | `940e363705f0463eae7b0ec107c47d3f` | 780 × 2440 | 390 × 1220 | Ẩn | [Có][img-940e363705f0463eae7b0ec107c47d3f] | [Có, đã đọc][html-940e363705f0463eae7b0ec107c47d3f] | Không phải payment khách hàng |
| 19 | Rescuer App - Tài Khoản V2 | `a367f086a20248b6a0ea0d9956656440` | 780 × 5296 | 390 × 2639 | Ẩn | [Có][img-a367f086a20248b6a0ea0d9956656440] | [Có, đã đọc][html-a367f086a20248b6a0ea0d9956656440] | Không phải payment khách hàng |
| 20 | Customer Bank Paid | `aba372441d284c2a90b4e4baf1051f53` | 780 × 2688 | 390 × 1335 | Hiện | [Có][img-aba372441d284c2a90b4e4baf1051f53] | [Có, đã đọc][html-aba372441d284c2a90b4e4baf1051f53] | Payment chính |
| 21 | Customer App - Lịch Sử V2 | `ace3f779031845f9ae6fc73aeb36ad80` | 780 × 3040 | 390 × 1511 | Ẩn | [Có][img-ace3f779031845f9ae6fc73aeb36ad80] | [Có, đã đọc][html-ace3f779031845f9ae6fc73aeb36ad80] | Ngữ cảnh: lịch sử + hóa đơn |
| 22 | Professional headshot portrait of a Vietnamese male roadside-assistance technician in his 30s wearing a high-visibility navy and reflective rescue vest, warm confident smile, daylight outdoor, neat haircut, high resolution | `b0c1364ba4e144fcba60b1616779dcc8` | 1024 × 1024 | 512 × 512 | Ẩn | [Có][img-b0c1364ba4e144fcba60b1616779dcc8] | Không | Ảnh chân dung |
| 23 | Customer Bank QR | `bd756e87ab6a4299876b1ef8d40c649d` | 780 × 2546 | 390 × 1257 | Hiện | [Có][img-bd756e87ab6a4299876b1ef8d40c649d] | [Có, đã đọc][html-bd756e87ab6a4299876b1ef8d40c649d] | Payment chính |
| 24 | Customer App - Tài Khoản V2 | `c30e75d700b748cdacaf555d15021de2` | 780 × 3500 | 390 × 1750 | Ẩn | [Có][img-c30e75d700b748cdacaf555d15021de2] | [Có, đã đọc][html-c30e75d700b748cdacaf555d15021de2] | Liên quan: thẻ/ví/VAT; future |
| 25 | Trang chủ - Đang tác nghiệp | `c45e93e0decd4c1292c56d842d574b72` | 780 × 2540 | 390 × 1269 | Ẩn | [Có][img-c45e93e0decd4c1292c56d842d574b72] | [Có, đã đọc][html-c45e93e0decd4c1292c56d842d574b72] | Không phải payment khách hàng |
| 26 | Customer App - Theo Dõi V2 | `d1c6f49df78c41dca159fb5b1402557b` | 780 × 3308 | 390 × 1654 | Ẩn | [Có][img-d1c6f49df78c41dca159fb5b1402557b] | [Có, đã đọc][html-d1c6f49df78c41dca159fb5b1402557b] | Ngữ cảnh: theo dõi + báo giá |
| 27 | Rescuer App - Lịch Sử V2 | `d2fcf03d7d2d4cb689524d23b10eb80a` | 780 × 2576 | 390 × 1288 | Ẩn | [Có][img-d2fcf03d7d2d4cb689524d23b10eb80a] | [Có, đã đọc][html-d2fcf03d7d2d4cb689524d23b10eb80a] | Không phải payment khách hàng |
| 28 | Customer App - Đặt Cứu Hộ (Xanh Tech) | `d4244d2210de42d1b6f5c8cdb531eb98` | 390 × 884 | 390 × 884 | Ẩn | Không URL | [Có, đã đọc][html-d4244d2210de42d1b6f5c8cdb531eb98] | Không phải payment khách hàng |
| 29 | Logo Cứu Hộ 24/7 Đối Tác | `e7b2e94240f743769a19261e0ecf3cb1` | 100 × 100 | 100 × 108 | Ẩn | [Có][img-e7b2e94240f743769a19261e0ecf3cb1] | [Có, đã đọc][html-e7b2e94240f743769a19261e0ecf3cb1] | Logo |
| 30 | Trang chủ - Ngoại tuyến | `e7c500e1b16e4ab9aa4a4f24256aaebb` | 780 × 2498 | 390 × 1249 | Ẩn | [Có][img-e7c500e1b16e4ab9aa4a4f24256aaebb] | [Có, đã đọc][html-e7c500e1b16e4ab9aa4a4f24256aaebb] | Không phải payment khách hàng |
| 31 | Customer Cash Paid | `ef8318c14b8c42b2b6c9865af26489e4` | 780 × 2618 | 390 × 1313 | Hiện | [Có][img-ef8318c14b8c42b2b6c9865af26489e4] | [Có, đã đọc][html-ef8318c14b8c42b2b6c9865af26489e4] | Payment chính |
| 32 | Rescuer App - Đang Xử Lý V2 | `ffe3f13b0106406b8a5c8fdd1067c207` | 780 × 2560 | 390 × 1280 | Ẩn | [Có][img-ffe3f13b0106406b8a5c8fdd1067c207] | [Có, đã đọc][html-ffe3f13b0106406b8a5c8fdd1067c207] | Không phải payment khách hàng |

Ba design-system instance ẩn: `assets_62eb3e9a03624dff8febfa0cbf18ffbd`, `assets_8eba3a09f22342c596bb52341a27b7dd`, `assets_93dc24f9f96344e2956d6bb57e5f4a10`, mỗi instance 960 × 540. Không tính là screen thanh toán.

## 3. Payment screens được xác định bằng nội dung

| Screen | ID | Bằng chứng nội dung/structure | Phạm vi |
| --- | --- | --- | --- |
| Customer Payment Method | `83d8804a503246e2bf3e89baf949da16` | Summary CH/TT/amount, cash + VietQR cards, thẻ/ví disabled, sheet chọn phương thức | Cash dùng làm reference ngay; bank/thẻ/ví future |
| Customer Cash Awaiting | `6b12b965628e4666911b7d2f011bde09` | “Đang chờ đối tác xác nhận”, tiền cần giao, người nhận tiền, không có customer-paid button | Cash awaiting_payment |
| Customer Cash Paid | `ef8318c14b8c42b2b6c9865af26489e4` | “Đã thanh toán”, “Đối tác đã xác nhận nhận tiền mặt”, receipt phương thức tiền mặt | Cash paid do backend xác nhận |
| Customer Bank QR | `bd756e87ab6a4299876b1ef8d40c649d` | QR placeholder, MB Bank/account/transfer content/copy, chờ ngân hàng | FUTURE ONLY |
| Customer Bank Verifying | `59a97c6c9d9c443a87671e93a29f3f3c` | Spinner, “Đang xác minh giao dịch”, MB Bank/Napas, webhook syncing | FUTURE ONLY |
| Customer Bank Paid | `aba372441d284c2a90b4e4baf1051f53` | “Thanh toán thành công”, VietQR receipt, bank Ref ID | FUTURE ONLY |

Tất cả 6 có screenshot và HTML đã đọc được. Không tìm thấy màn payment failed riêng, trạng thái lỗi mạng riêng, pending chưa tạo payment riêng, refund/cancel riêng. Không suy “Xác minh hồ sơ” thành bank verifying: `06c2a...` thực tế là hồ sơ đối tác và giấy tờ.

Hai màn tài khoản `753b...`, `c30...` có thẻ/ví đã liên kết và VAT; là phần cài đặt thanh toán, không có CH/TT/amount của một payment cụ thể. Bốn màn theo dõi/lịch sử ở bảng chỉ chứa báo giá, tổng cước hoặc link hóa đơn; không có flow chọn cash/awaiting/paid mới.

## 4. Screenshot so với HTML và quy tắc kích thước

- Sáu ảnh payment rộng 780 px, canvas rộng 390. Preview 390 px thể hiện mật độ mobile tương ứng; dùng CSS width 390 làm cơ sở logical layout, không nhân đôi cỡ chữ/padding trong Flutter.
- Method: ảnh 780×2244 → preview 390×1122, nhưng canvas 390×1092.
- Cash Awaiting: 780×2442 → 390×1221, canvas 390×1205.
- Cash Paid: 780×2618 → 390×1309, canvas 390×1313.
- Bank QR: 780×2546 → 390×1273, canvas 390×1257.
- Bank Verifying: 780×1944 → 390×972, canvas 390×954.
- Bank Paid: 780×2688 → 390×1344, canvas 390×1335.
- Vì height khác nhau, không gán cứng height của canvas cho nội dung scroll Flutter.
- Hierarchy 6 screenshot phù hợp structure HTML: method có summary trước cards; awaiting có hero vàng trước KTV; cash paid có hero xanh và amount trước receipt; QR đặt trên bank data; verifying ưu tiên spinner; bank paid ưu tiên success/receipt.
- Khác biệt trạng thái động: screenshot QR hiển thị **14:56**, HTML ban đầu **14:59** và JS countdown; screenshot verifying hiển thị **9–12 giây**, HTML ban đầu **5–15**, JS tự đếm từ 14. Đây là snapshot của timer giả lập, không phải dữ liệu server.
- Method screenshot không cho thấy action sheet vì HTML đặt `hidden`; nội dung sheet và alert nguy hiểm chỉ phát hiện qua HTML.
- Screenshot không chứng minh backend đã phản hồi hoặc trạng thái paid là thật. Cả hai paid page render success tĩnh ngay từ markup.
- Theme cấp project là **Roboto Flex / #123b66**, trong khi HTML và screenshot payment thuộc **Plus Jakarta Sans / #0037b0 / #1d4ed8**. Báo cáo giữ cả hai và chọn per-screen HTML làm bằng chứng cho bộ payment đang review; không áp theme Partner lên customer.
- Không phát hiện mâu thuẫn tĩnh rõ ràng về thứ tự section/nội dung giữa ảnh và HTML 6 payment; chưa kiểm pixel-perfect/computed CSS. `shadow-xs` và `opacity-65` có trong HTML nhưng không được định nghĩa rõ trong config; không mặc định coi chúng có computed effect cụ thể.

## 5. Colors

Các token dưới đây lấy từ config HTML của payment; giá trị opacity là modifier của từng phần tử, không phải màu solid mới.

| Vai trò | Token / hex | Nơi dùng |
| --- | --- | --- |
| Header / brand / số tiền | primary #0037B0 | Header 5 screen, amount, icon |
| CTA bank / avatar / spinner | primary-container #1D4ED8 | Bank Paid CTA, spinner |
| Chữ chính | on-surface / on-background #0B1C30 | Headline và value |
| Chữ phụ | on-surface-variant #434655 | Label/body |
| Hint | outline #747686 | Metadata/footer |
| Nền trang | surface/background #F8F9FF | Tất cả payment |
| Card | surface-container-lowest #FFFFFF | Summary/receipt/method |
| Nền nhóm nhạt | surface-container-low #EFF4FF | Detail groups |
| Nền nhóm | surface-container #E5EEFF | Chip/secondary |
| Nền advisory | surface-container-high #DCE9FF | Safety block |
| Nền icon | surface-container-highest #D3E4FE | Icon box |
| Tím xanh nhạt | primary-fixed #DCE1FF | Icon/hero |
| Thành công | secondary #006C49 | Success icon/text |
| Success container | secondary-container #6CF8BB | Paid badges, đôi khi /40 hoặc /50 |
| Mint chip | secondary-fixed #6FFBBE | Recommended/connection |
| Chữ trên mint | on-secondary-container #00714D; on-secondary-fixed #002113 | Chip |
| Cyan | tertiary-fixed #ACEDFF; tertiary-fixed-dim #4CD7F6 | VietQR free badge/glow |
| Error/SOS | error #BA1A1A; on-error #FFFFFF | SOS, transfer text |
| Error soft | error-container #FFDAD6 | QR warning |
| Đường biên | outline-variant #C4C5D7 | Dashed receipt, separator |
| Cash Paid CTA riêng | #F97316, hover #EA580C | Nút xem chi tiết màu cam |
| VietQR wordmark | #ED1B24 / #005BA9 | Brand text trong QR card |

Cash awaiting dùng Tailwind amber: amber-50 #FFFBEB, amber-100 #FEF3C7 (/70 cho pill), amber-300 #FCD34D (/30), amber-400 #FBBF24 (/20), amber-500 #F59E0B, amber-600 #D97706, amber-700 #B45309, amber-900 #78350F, amber-950 #451A03. Đây là quy đổi palette mặc định Tailwind từ class trong HTML, chưa phải sampling screenshot.

## 6. Typography

Font payment: **Plus Jakarta Sans**, Google font request 400/600/700/800; Material Symbols Outlined cho icon. Một số code dùng `font-mono` nên không đồng nhất với chữ body.

| Token HTML | Size / line height | Weight khai báo | Letter spacing |
| --- | --- | --- | --- |
| display-lg | 36 / 44 | 800 | -0.03em |
| display-lg-mobile | 28 / 36 | 800 | -0.02em |
| headline-lg | 30 / 38 | 700 | -0.02em |
| headline-lg-mobile | 24 / 32 | 700 | -0.01em |
| headline-md | 20 / 28 | 700 | -0.01em |
| headline-sm | 18 / 24 | 600 | 0 |
| body-lg | 16 / 24 | 400 | 0 |
| body-md | 14 / 20 | 400 | 0 |
| body-sm | 12 / 16 | 400 | 0.01em |
| label-lg | 16 / 20 | 600 | 0.01em |
| label-md | 14 / 18 | 600 | 0.01em |
| label-sm | 11 / 14 | 700 | 0.04em |

Các class `font-bold` (700), `font-extrabold` (800), `tracking-tight` (-0.025em), `tracking-wide` (0.025em), `tracking-wider` (0.05em) có thể override token ở node cụ thể. HTML dùng `font-semibold` cho 600. Ghi theo node, không suy mọi headline luôn cùng weight.

Amount: Method/Cash Awaiting/Bank Paid 28/36, Cash Paid 36/44, Bank QR 24/32, Bank Verifying 18/24. Ký hiệu **đ** là node riêng nhỏ hơn. Backend currency là **VND**, không hardcode số tiền từ ảnh.

## 7. Spacing, page và visual components chung

- Main `w-full max-w-[480px] mx-auto px-margin`: max 480, lề ngang 20 px. Ở viewport 390, bề rộng nội dung khoảng **350 px** trước padding từng card.
- Header chung 5 screen: fixed top, z50, full viewport, inner max480/h64/px20. Main pt64; background #F8F9FF. Header cộng safe-area top, cần bù safe-area cho main khi port Flutter.
- Body min-height `max(884px,100dvh)`; là chiều cao tối thiểu prototype, không phải yêu cầu thiết bị cao 884 dp.
- Scroll theo document; main không khai báo scroll area riêng/overflow-y-auto. Scrollbar ẩn, overscroll none. Footer nằm sau main, **không sticky bottom CTA**. Method sheet là fixed bottom.
- Space token: xs4, sm8, md16, lg24, xl32, gutter16, margin20. Lưu ý `space-md=16` khác `RescueSpace.md=12` hiện tại.
- Radius: default4, lg8, xl12, rounded-2xl16, custom20/22/24, full9999. Không áp một card radius chung cho mọi component.
- Shadow header khai báo chính xác `0 1px 8px rgba(0,0,0,.06)`; SOS `0 2px 8px rgba(186,26,26,.3)`. Card chủ yếu shadow-sm/shadow-md; không có border bao quanh mặc định.
- Theo Tailwind mặc định, shadow-sm = 0 1px 2px rgba(0,0,0,.05); shadow-md = 0 4px 6px -1px rgba(0,0,0,.1) + 0 2px 4px -2px rgba(0,0,0,.1). Chưa đo computed CSS runtime của CDN.
- Icon thường 14/16/18/20/22/24/26 px; hero 32/34/40/44; icon container 28/32/36/40/48/56/80/96/144 theo từng node.
- HTML viewport cấm zoom (`user-scalable=no`) và có nhiều truncate/fixed-height. Khi lập Flutter plan phải giữ text scaling/semantics; không copy hạn chế accessibility, không clip CTA tiếng Việt trên màn hẹp.

## 8. Phân tích từng payment screen (A–I)

### 8.1 Customer Payment Method — 83d8804a503246e2bf3e89baf949da16

**A. Header:** cao 64 + safe area; nền primary #0037B0. Back là button 44×44, icon24, history.back(). Title “Payment Methods” 18/24, dưới là shield14 + “BẢO MẬT 256-BIT” 11/14 mint. Title truncate max190. SOS cao44, padding ngang8, pill đỏ, icon18, tel:19002470. Avatar32, person18; avatar không có action riêng trong markup.

**B. Layout:** main max480, px20, pt64, pb24. Stack gap16. Banner reassurance padding16×8/r12. Summary card r20/p24/shadow-sm; vùng metadata dùng negative margin24 để ăn tới mép card. Section phương thức gap8, top4. Không có nav 5 tab, không có primary CTA cố định ở đáy.

**C. Summary:** CH-982401 ở label11 bold/primary; TT-882940 chip 11 trên #E5EEFF; dịch vụ18, xe14, địa điểm12. “Xe đã lên sàn” badge mint là trạng thái cứu hộ mẫu, không chứng minh completed hoặc paid. Amount panel p16/r12/#DCE9FF với opacity40%; label11 uppercase → amount28/36 weight800 primary → đ20/28 → chú thích VAT12. 850.000, Mazda, biển số, vị trí, VAT đều là mock.

**D. Method:** cash và VietQR là **button card có chevron**, không phải radio. p16/r20/shadow-sm; icon box48/r12/icon26; title16/20 weight600, subtitle12/16 truncate, gap16; chevron container32/icon20. Cash mint, badge “Khuyên dùng”; bank tím xanh, badge cyan “Miễn phí 24/7”. Height auto: khoảng tối thiểu80 với icon48 + p16 hai phía, tăng khi bank title wrap. Không có selected border/check trong danh sách: chọn mở sheet.

Thẻ Visa/MasterCard/MoMo là div không onClick, class cursor-not-allowed + opacity-65, icon xám, badge “Tạm khóa”. Không dùng câu “Bảo trì định kỳ” cho tính năng chưa triển khai. Với GD2B, **bank cũng phải unavailable**; ảnh hiện tại cho click bank nên cần thay đổi.

**E. Status:** banner “Đối tác đang chờ thanh toán an toàn” và “Bảo mật 100%” tĩnh; pending ở đây là suy luận mapping từ chưa chọn method, HTML không có enum backend. Cash success/failed/loading chưa được thiết kế tại page này.

**F. Cash:** bottom sheet title “Tiền mặt tại chỗ”; mô tả trả trực tiếp amount mẫu. Button “Tiến hành” chạy alert **“Đã ghi nhận thanh toán tiền mặt. Tài xế sẽ xuất biên lai cứu hộ số TT-882940.”**, không RPC. Không được biến chọn phương thức thành xác nhận đã thanh toán.

**G. Bank/QR:** sheet nói sẽ tạo QR động đúng amount và TT882940 nhưng chỉ alert; không có bank intent thực. Giữ làm reference future-only.

**H. CTA:** sheet fixed bottom/max480/p20/safe area; card r24/p24/shadow-2xl, drag handle40×4; 2 button flex1/h48/r12, gap8. “Chọn lại” nền high; “Tiến hành” primary/white, icon18. Không loading/disabled chống double-submit. Main CTA là chính method cards.

**I. Visual/security:** ảnh xác nhận thứ tự summary → method → notice. Sheet không hiện trong screenshot. MUST NOT IMPLEMENT AS-IS đối với alert cash, bank enabled, compliance claims và mọi dữ liệu mẫu. Chỉ sheet xác nhận lựa chọn cash + RPC GD2B thành công mới chuyển awaiting; không ghi paid.

### 8.2 Customer Cash Awaiting — 6b12b965628e4666911b7d2f011bde09

**A. Header:** cấu trúc chung64, title “Invoice Summary”; back44/icon24, SOS44, avatar32; màu primary.

**B. Layout:** px20, pt64, main pb24 và wrapper pb24/gap16. Metadata strip p16×8/r12; hero trắng r12/p24/shadow-sm/overflow-hidden; KTV card r12/p16/gap8; safety card r12/p16/gap8. Document scroll.

**C. Summary:** TT-882940 ngay đầu (label14/18, bold, tracking-wider); CH-982401 ở header card người nhận (label11). Amount “Số tiền cần giao tiền mặt”11 uppercase, 850.000 đ: số28/36 weight800 ink, đ18/24 muted. Amount phải từ amountExpected; không lấy tổng preview quote khi payment đã tồn tại.

**D. Method:** cash đã chọn, không radio/card selector. Chỉ có secondary đổi sang QR/bank; chưa có API hỗ trợ nên ẩn/disabled tại phase cash. Không ngầm reset awaiting về pending.

**E. Status:** pill “Đang chờ đối tác xác nhận”, bg amber100/70, text amber900, px16/py6, label14 bold, dot10 amber600 + pulse. Outer hero ring96, core80/amber50/icon40, badge28/amber500/hourglass16 quay3s. Không có failed variant. Đây là awaiting_payment, khác pending chưa chọn method.

**F. Cash:** yêu cầu giao tiền trực tiếp KTV; card “Người nhận tiền thực tế”, avatar56, tên18 bold, mã KTV11, xe/biển số12. Nút gọi KTV 0982 765 432. Quy trình ghi rõ đối tác bấm “Đã nhận đủ tiền” trên thiết bị của họ, khách không cần bấm nút. Đây là **mô tả action rescuer**, không phải nút customer. Trạng thái nhận tiền chỉ thay đổi sau backend + getter.

**G. Bank/QR:** không QR/account. Có button alert “Chuyển sang phương thức thanh toán VietQR / Thẻ quốc tế”; MUST NOT IMPLEMENT AS-IS vì GD2B cash-only và không có đổi method.

**H. CTA:** gọi KTV full width/h48/r12/bg #E5EEFF/icon20; đổi method full width/h56/pill/white/primary/icon20; support dạng link tel:19006868. Các nút nằm trong scroll. Không có “Tôi đã thanh toán”, “Đã trả tiền”, nút customer-confirm-paid hay loading action thu tiền.

**I. Visual/security:** safety có icon36, bullet cards p8/r8/white80, warning amber50. Dòng chấm xanh “Đang lắng nghe tín hiệu xác thực từ máy KTV...” và JS setInterval mỗi4s chỉ tăng biến, không SSE/WebSocket thật. Thay bằng state GD4, khi stale không nói đang kết nối. Không sao chép lời yêu cầu “không rời hiện trường” thành điều kiện an toàn bắt buộc trên đường; dùng lời nhắc kiểm tra xác nhận/gọi hỗ trợ phù hợp thực tế. Số tiền, tên, ảnh, xe và hotline đều phải lấy nguồn hợp lệ.

### 8.3 Customer Cash Paid — ef8318c14b8c42b2b6c9865af26489e4

**A. Header:** chung64, “Payment Success”, back44, SOS44, avatar32, nền primary.

**B. Layout:** max480/px20/pt64/pb24. Hero r12/pt16/pb24/px20, gradient primary-fixed30 → surface-low → white, mb16. Receipt r12/overflow-hidden/mb16; aftercare p20/r12/mb24. CTA stack gap8. Không fixed CTA.

**C. Summary:** h2 “Đã thanh toán”28/36; mô tả cash14/20. Amount box r12/py16/px24: label11 → số **36/44 weight800** primary → đ18. TT-882940 dưới amount và row receipt; CH-982401 caption12. Amount hiển thị paid phải là amountReceived của DTO paid, đồng thời đối chiếu expected; không fabricate missing value.

**D. Method:** read-only “Tiền mặt (Trực tiếp KTV)”; không chọn/đổi phương thức.

**E. Status:** xanh secondary #006C49; core80/check44, ring96 mint40 pulse, micro verified18 trên nền trắng. Badge label11 uppercase “THANH TOÁN HOÀN TẤT”, mint. Receipt badge “ĐÃ ĐỐI SOÁT”. Đổi wording thành “Đối tác đã xác nhận thu tiền” để không nhầm cash collected với bank settlement/payout. Không failed/verifying branch.

**F. Cash:** mô tả “Đối tác đã xác nhận nhận tiền mặt”. Receipt rows method, nhận lúc “14:42, Hôm nay (15/10/2024)”, Nguyễn Văn Hùng/#KTV-082, TT. Lấy cashReceivedAt/paidAt server; không dùng ngày tạo request hoặc DateTime.now. DTO hiện không trả tên/ảnh/số điện thoại/mã KTV: chỉ hiển thị khi có nguồn khác đã được phép đọc; không lấy UUID làm mã KTV.

**G. Bank/QR:** không có QR hay bank; không gán bank success copy cho cash. VAT e-Invoice đang gửi tới email mẫu không thuộc GD1–GD4.

**H. CTA:** xem chi tiết full width **h56/pill/#F97316** hover #EA580C/icon20, HTML href="#"; đánh giá h48/pill/white/icon20 amber; PDF và share grid2/gap8/h44/pill/#DCE9FF/icon18. Các secondary chưa có handler nghiệp vụ. Không loading/disabled mô tả. Đánh giá nên mở flow chọn đánh giá hiện có, không tự gán 5★.

**I. Visual/security:** ticket header p20/bg high40, separator dashed border-b2/#C4C5D7, content p20/gap8/row py4; icon rows18. 48h warranty, PDF, email VAT, đối soát, 5★ là mẫu/claim chưa xác nhận. Success chỉ render khi getter trả method=cash/status=paid; mở route thành công trực tiếp hoặc bấm chọn cash không đủ. MUST NOT IMPLEMENT AS-IS đối với receipt tĩnh và tính năng phụ chưa có.

### 8.4 Customer Bank QR — bd756e87ab6a4299876b1ef8d40c649d

**A. Header:** chung64, “Invoice Summary”, back/SOS/avatar như cash.

**B. Layout:** max480/px20/pt64; countdown strip p8/r12/mb16; QR card r24/p16/shadow-md/mb16; bank detail card r24/p16/shadow-sm/mb16. Document scroll.

**C. Summary:** amount ở card thứ hai, số24/32 weight800 primary + đ18; 850.000 là hằng mẫu. CH/TT không có summary rows riêng phía trên QR: chúng xuất hiện ghép trong nội dung **CUUHO 982401 TT882940**; không tự thêm dấu gạch vào payload chuyển khoản dựa theo label UI.

**D. Method:** VietQR/MB Bank, không picker; link chuyển cash chỉ toast. Không có bank-selection RPC trong source GD2B.

**E. Status:** pill dưới QR “Đang chờ thanh toán từ ngân hàng...” nền low/blue/dot10; countdown14:59 →0. Countdown không đánh dấu expired, không vô hiệu QR/copy/chuyển khoản khi0. Không failed/expired design thật. Manual refresh disabled1200ms chỉ là giả lập.

**F. Cash:** button “Đổi sang thanh toán tiền mặt cho tài xế” gọi switchCashPayment() để toast, không RPC. Future phải có policy bank intent/cancel/reconciliation trước đổi phương thức, tránh thu trùng; không implement switch bằng local state.

**G. Bank/QR:** white QR box w-full/max280/aspect1:1/p12/r16, img fill/object-contain/r12; corner guides16/border2/offset8. Ảnh QR là **image placeholder sinh sẵn**; screenshot thấy một hình thẻ QR lồng trong UI khác, không phải ma trận QR được sinh từ payment intent. Không có payload đã kiểm chứng hoặc tài khoản production.

Bank rows: MB Bank, Ngân hàng TMCP Quân Đội, CÔNG TY CP CỨU HỘ GIAO THÔNG 247, account **09886868247**, transfer **CUUHO 982401 TT882940**. Account16 bold/letter-spacing, transfer14 weight800/error; rows14 label, support12. Copy account32×32/icon18/r-full; copy content h32/px8/r8/icon16. JS copy bỏ qua lỗi clipboard nhưng vẫn báo thành công, cần sửa ở future.

**H. CTA:** “Kiểm tra thanh toán” w-full/h56/pill/white/primary/icon22; click xoay icon, disabled=true, toast “đồng bộ Napas”, sau1200ms luôn báo chưa nhận được giao dịch. Không network request. Hotline h36/pill/primary-container/icon16. Không có “Tôi đã chuyển khoản” để tự paid.

**I. Visual/security:** QR warning bg error-container40/p8/r12; logo VietQR đỏ/xanh và Napas là reference. 10–30 giây đối soát, countdown và trạng thái bank là giả. **FUTURE ONLY / MUST NOT IMPLEMENT AS-IS** toàn bộ bank behavior, fake QR/account/expiry; manual refresh chỉ được gọi authoritative getter khi bank contract thật tồn tại.

### 8.5 Customer Bank Verifying — 59a97c6c9d9c443a87671e93a29f3f3c

**A. Header:** khác 5 màn còn lại: **không app bar fixed64, không back/SOS/avatar**. Trong main px20, row py12/height auto; lock32/icon20, title “Xác minh thanh toán”18/24, bảo mật11 uppercase; badge “CỔNG KẾT NỐI MỞ” px10/py4, nền mint/label11/dot8. Chiều cao phụ thuộc wrap của hai cụm tại width350, không có số height cố định.

**B. Layout:** body pt-safe/pb-safe, main max480/px20, wrapper pb32. Hero pt20/pb24/center; overview p20/r12/mb16/shadow-md; advice p16/r12/mb24/shadow-sm; footer action trong flow/mt-auto. Không menu/bottom nav.

**C. Summary:** overview “Thông tin đối chiếu”; amount850.000đ18/24 bold/primary; TT-882940 font-mono14, CH-982401 font-mono14 bold. Heading24/32 bold, body14/20 + leading-relaxed (1.625, khoảng22.75), max340. Không chi tiết chủ tài khoản/QR.

**D. Method:** badge MB Bank(VietQR) read-only; không đổi method/selected/unselected control.

**E. Status:** spinner outer144, center96/white/shadow-md, shield box56/icon32. SVG circle r42/stroke5 và arc5.5, animation2.8s; glow/pulse. H1 “Đang xác minh giao dịch”; estimated pill px14/py6/label14, JS từ14 giây đến “Đang đồng bộ...”. Connection badge/webhook row không được nối backend, không chứng minh verifying. Failed/timeout action chưa có.

**F. Cash:** không có; không reuse trạng thái verifying này cho cash awaiting.

**G. Bank:** text Napas/MB Bank, technical row “API WEBHOOK BACKEND: SYNCING...”, monospace11/icon16/dot8. Đây là giả lập. Advisory cấm đóng ứng dụng/tải lại, hứa tự cập nhật sau60s; không suy hệ thống hiện có guarantee này. UI product nên nói “Đang kiểm tra giao dịch”, bỏ thuật ngữ API WEBHOOK BACKEND và không khóa khả năng rời màn.

**H. CTA:** chỉ support link full width/py14/px16/r12/white/icon20/label14; khoảng48px theo20px icon +28px padding, có thể cao hơn nếu wrap. Footer lock14 + label11. Không customer confirm, không primary submit.

**I. Visual/security:** screenshot đang9–12s, HTML5–15 trước JS. FUTURE ONLY. Giữ hierarchy nhưng không triển khai timer/connected/verifying từ thời gian chờ local; chỉ backend thật xác định state và timeout policy.

### 8.6 Customer Bank Paid — aba372441d284c2a90b4e4baf1051f53

**A. Header:** chung64 “Payment Success”, back44, SOS44, avatar32. Micro row ngay dưới: dot10 + “XÁC NHẬN THỜI GIAN THỰC”11, nút Đóng px12/py6/r-full/icon16; handler reload() không phải navigation đúng nghĩa.

**B. Layout:** max480/px20/pt64; wrapper gap16. Hero trắng r16/p24; receipt r16/p16/gap8; journey card r16/p16; CTA gap8/pt4. Document scroll, không sticky CTA.

**C. Summary:** “Thanh toán thành công”24/32 weight800; amount28/36 weight800 blue + đ20; panel r12/px16/py12. TT-882940, CH-982401 trong receipt14; bank Ref ID **FT2428989104523** font-mono14; timestamp “14:43:12 • 15/10/2024”. Đây là mock, DTO hiện không có bank ref.

**D. Method:** receipt “VietQR Napas247 (MB Bank)” read-only; không method switch.

**E. Status:** outer icon80 mint40, inner56/secondary/verified34, micro badge28/check20; success badge11 uppercase mint50; receipt “ĐÃ KHÓA SỔ” mint/lock13. Wording “Đã ghi nhận vào tài khoản MB Bank thụ hưởng” đòi bank settlement thật, không suy từ customer action.

**F. Cash:** không; cash paid không được dùng copy “đã vào tài khoản MB Bank”.

**G. Bank:** receipt gồm method, payment code, bank reference+copy, CH, time; VAT PDF/XML chữ ký số tới ketoan@alphatech.vn. Không QR. Bank ref và invoice không có trong GD1–GD4 getter; không đi đọc raw payment_events để lấp dữ liệu.

**H. CTA:** xem chi tiết h56/pill/#1D4ED8/white/icon22; secondary grid2/h48/r12/white/icon20: tải VAT và đánh giá5 sao; hotline Gọi ngay py6/px14/pill/highest/icon16. Copy bank ref chỉ icon16, thiếu hit target lớn; JS đổi icon done1800ms kể cả chưa xác minh clipboard. Các CTA nghiệp vụ chủ yếu không handler.

**I. Visual/security:** journey card khẳng định bàn giao xe và48h warranty/KÍCH HOẠT. Không lấy paid làm bằng chứng mọi milestone cứu hộ/warranty. **FUTURE ONLY / MUST NOT IMPLEMENT AS-IS**: paid tĩnh, ref, timestamp, bank received, invoice/email/chữ ký số và 5★. Nút Đóng phải điều hướng hợp lệ, không reload success giả.

## 9. Các phần payment liên quan trong screen ẩn

| Screen/ID | Nội dung đã xác nhận qua HTML + screenshot | Structure phần payment | Kết luận |
| --- | --- | --- | --- |
| Tài Khoản (Xanh Tech), `753b331a6ffa4341aadfafde01a881a0` | Visa••9812 Mặc định; MoMo Đã kết nối; VNPay-QR Quét tức thì; VAT toggle bật và công ty/email/MST mẫu | Section title18; card trắng r22/p16/gap16; grid3/gap8, tile p10/r16, icon32/icon20; label11, trạng thái9; toggle48×28, thumb20; VAT detail p12/r12 | Future saved-method/invoice; không phải payment cho một request. Không show linked/default khi chưa có dữ liệu thật |
| Tài Khoản V2, `c30e75d700b748cdacaf555d15021de2` | Thẻ & Ví liên kết Visa/MoMo/VNPay; tự gửi VAT | Card r12/p24/shadow-sm; rows p16/r8/low; icon40/icon22; title14/body12; VAT toggle44×24/thumb20 | Future; không reuse palette V2 để thay bộ payment Xanh Tech |

Hai màn này không có payment amount/CH/TT, cash pending/paid, QR thanh toán hoặc confirmation thu tiền; A–I của một giao dịch không áp dụng. Screenshot xác nhận grouping đúng phần giữa trang tài khoản, không phải trang payment riêng.

Theo dõi Xanh Tech `13c606...` và V2 `d1c6f...`: đọc HTML thấy giá dự tính850.000 và bước hoàn tất/thanh toán, không thấy selector/settlement. Lịch sử Xanh Tech `23b62...` và V2 `ace3...`: có tổng cước/link hóa đơn, không chứng minh paid. Chỉ dùng làm entry/navigation reference; không gộp completed của request với paid của payment. Bốn màn ngữ cảnh này chưa được review visual chi tiết trong tác vụ payment.

## 10. Customer app hiện tại: điểm đã có và điểm còn thiếu

Đã đọc trực tiếp các file người dùng chỉ định và các dependency liên quan:

| Nguồn | Kết quả đối chiếu |
| --- | --- |
| [payment_screen.dart](../frontend/customer_app/lib/screens/payment_screen.dart) | Standalone StatefulWidget, không requestId/controller/payment DTO. selectedMethod='momo'; mọi amount/status/method là local/mock; CTA chỉ pushNamed('/history') |
| [app_theme.dart](../frontend/customer_app/lib/app/app_theme.dart) | Alias AppColors/AppSpacing/AppRadius sang mobile_ui; không phải bộ payment riêng |
| [mobile_ui.dart](../frontend/customer_app/lib/app/mobile_ui.dart) | Đã có phần lớn màu brand Xanh Tech/Plus Jakarta Sans, buttons có loading/disabled/semantics; status mapping hiện dành cho request/profile |
| [app_shell.dart](../frontend/customer_app/lib/app/app_shell.dart) | 5 tab IndexedStack, SafeArea và lifecycle. Không có payment tab; payment nên là route chi tiết theo request |
| [main.dart](../frontend/customer_app/lib/main.dart) | Routes thực tế **không đăng ký /payment**; app maxWidth520, khác HTML max480 |
| [app_controller.dart](../frontend/customer_app/lib/app/app_controller.dart) | Sở hữu PaymentWatcher; loadPayment/watchPayment/refreshPayment/clearPayment; có watch active hoặc completed-history fallback |
| [payment_dto.dart](../frontend/customer_app/lib/models/payment_dto.dart) | Safe DTO; amountExpected/amountReceived/version BigInt; paymentCode/requestId/method/status/paidAt/cashReceivedAt |
| [payment_service.dart](../frontend/customer_app/lib/services/payment_service.dart) | PaymentSource chỉ load/watch; Supabase adapter gọi customer_get_payment và INSERT/UPDATE invalidation. Chưa có prepare/selectCash command |
| [payment_watcher.dart](../frontend/customer_app/lib/app/payment_watcher.dart) | Getter source of truth; newer-version-only, auth/request scope, retries/reconnect/resume/stale/error; không tạo payment/chọn method/confirm |
| [supabase_service.dart](../frontend/customer_app/lib/services/supabase_service.dart) | Factory PaymentSource và backend/request handling hiện có |
| [stitch_customer_header.dart](../frontend/customer_app/lib/widgets/stitch_customer_header.dart) | Header trắng min64, brand/title cố định; thiếu back/payment title/SOS của Stitch payment |
| [customer_ui.dart](../frontend/customer_app/lib/widgets/customer_ui.dart) | InfoRow, InlineNotice, CustomerEmptyState, customerDate, reduced-motion helper |
| [booking_ui.dart](../frontend/customer_app/lib/widgets/booking_ui.dart) | CustomerCard, PrimaryActionButton, CustomerBottomNav; reuse có chọn lọc, không thêm bottom nav vào payment |
| [tracking_ui.dart](../frontend/customer_app/lib/widgets/tracking_ui.dart) | RescuerInfoCard nhận optional data, chỉ enable call khi có phone + callback; TrackingInfoRow hỗ trợ màn nhỏ |
| [history_ui.dart](../frontend/customer_app/lib/widgets/history_ui.dart) | HistoryVehicleStrip/HistoryStatusBadge; request status, không thay thế payment status |
| [rescue_widgets.dart](../frontend/customer_app/lib/widgets/rescue_widgets.dart) | money(int?) format dấu chấm và đ; logic format tái dùng được nhưng signature chưa nhận BigInt |
| [history_details_screen.dart](../frontend/customer_app/lib/screens/history_details_screen.dart) | Route detail theo requestId/controller + repository; có review feature, phù hợp CTA sau payment |
| [request_details_service.dart](../frontend/customer_app/lib/services/request_details_service.dart) | Read owned request + request_status_events + enrich display codes; không phải payment_events, không cung cấp bank info |
| [pubspec.yaml](../frontend/customer_app/pubspec.yaml) | Đã đăng ký font Plus Jakarta Sans; không cần thêm font/asset cho plan này |

Không thấy customer_prepare_payment/customer_select_payment_method được gọi trong customer_app/lib. Backend đã có contract nhưng command integration Flutter vẫn phải bổ sung ở lần triển khai sau.

RequestDetails không tự trả hồ sơ/tài khoản ngân hàng KTV. RescueRequestData.contactName/contactPhone là thông tin liên hệ yêu cầu, **không mặc định là tên/số KTV**. Không đưa chúng vào “Người nhận tiền thực tế” nếu không có nguồn xác thực role/người nhận.

## 11. Component reuse và phần phải redesign

| Thành phần | Giữ/reuse | Thay đổi cần có trong PLAN |
| --- | --- | --- |
| AppColors/RescueColors | Primary, accent, background, ink, muted, success, danger đã khớp nhiều token | Thêm token local cho surface-low/high/mint/amber/radii payment nếu cần; không đổi theme toàn app chỉ để khớp payment |
| Plus Jakarta Sans | Reuse font đã bundle | Amount28/36 và36/44, label11/14 và mono-code cần style riêng; hiện RescueType.section weight700 khác Stitch headline-sm600 |
| RescueSpace | Reuse giá trị4/8/16/24/32 | Không map tên máy móc: RescueSpace.md12 khác Stitch space-md16; page hiện top16/bottom32 khác pt64/pb24 |
| RescueButton | Giữ semantics, loading→disabled, pressed/disabled logic, Flexible text | Stitch có pill và h44/48/56, default hiện r12/h56; dùng wrapper/variant payment có kiểm soát |
| RescueCard/CustomerCard | Giữ composition/accessibility | RescueCard r16 + border; Stitch thường r12/20/24 và shadow/no border. CustomerCard title19/p16 không khớp mọi card payment |
| StitchCustomerHeader | Giữ cách thích ứng text scale/min64 | Cần PaymentHeader nền xanh/back/title/SOS tùy dữ liệu; không sửa header trắng của 5 tab theo mặc định |
| InlineNotice/RescueFeedback/CustomerEmptyState | Reuse cho error/null/offline/loading | Lời nhắc dành cho payment, không dùng lỗi mạng làm failed payment |
| RescueStatusBadge/HistoryStatusBadge | Giữ cho request/profile nơi đang dùng | Không reuse mapping hiện tại cho payment: pending đang hiện “Đang chờ duyệt”, paid/awaiting chưa có. Cần PaymentStatusBadge riêng |
| InfoRow/TrackingInfoRow | Reuse display grouping và responsive stack | Style receipt/amount khác; không ép width label96/100 làm tràn TT dài |
| RescuerInfoCard | Reuse nguyên tắc dữ liệu optional, ảnh fallback, call guard | PaymentRecipientCard gọn hơn, không hardcode KTV; thiếu nguồn người nhận thì ẩn phần không có |
| HistoryVehicleStrip | Reuse tên/biển số hợp lệ, chống lộ UUID | Trang payment chỉ là contextual info của đúng request |
| customerDate | Reuse local formatting | Truyền cashReceivedAt/paidAt server, không giả “hôm nay” |
| money(int?) | Reuse thuật toán phân nhóm chữ số | Cần helper BigInt/string; không .toInt()/.toDouble() làm mất chính xác Flutter web; missing payment ≠ “Chờ báo giá” |
| PaymentDto/Source/Watcher | **Giữ contract và guard GD4** | UI observe snapshot; command prepare/select tách read/watch; không inject paid vào watcher |
| HistoryDetailsScreen + review flow | Reuse CTA xem chi tiết/đánh giá hợp lệ | Mở đúng request; không auto-rate5; không xây receipt PDF giả |
| payment_screen.dart _CostRow/_PaymentMethodItem | Có thể giữ ý tưởng row/option | Widget private hiện hardcoded style/radio và onTap non-null; redesign cho cards+sheet+disabled; không ưu tiên giữ implementation cũ khi khác contract |

AppShell không cần thêm tab thứ6. Có thể giữ nguyên shell nếu route nhận controller/requestId và lifecycle vẫn tới watcher; xem xét route ownership khi triển khai, không tạo controller độc lập để rồi mất scope realtime.

## 12. Mock/fake data cần loại

**Trong payment_screen.dart hiện tại:**

- Banner “Đã cứu hộ thành công”, giờ20:45, mã **#RQ-8839** đều tĩnh; không phải requestCode CH từ server.
- Dòng Vá lốp150.000đ + phụ tùng50.000đ − giảm30.000đ = tổng **170.000đ** là mock. Không có quote/payment backing.
- Default MoMo; MoMo/VNPay/card/cash chỉ setState local, không RPC.
- Badge “Hoàn5%”, “PCI-DSS”, bảo hành30 ngày không có bằng chứng trong payment contract.
- CTA **“Xác nhận thanh toán 170.000đ” → Navigator.pushNamed('/history')**: không chuyển backend sang paid nhưng tạo UX hiểu nhầm đã thanh toán; MUST NOT IMPLEMENT AS-IS.
- Màu đỏ #C1121F, header trắng, nền #F7F7FA, padding16, CTA h52/pill/sticky bottom không khớp bộ payment Stitch.
- Không có backend loader/null/unauthorized/stale/version conflict/cash awaiting/paid branch.

**Trong Stitch:**

- 850.000đ, CH-982401, TT-882940, FT2428989104523, mọi thời gian15/10/2024.
- KTV Nguyễn Văn Hùng/#KTV-082, avatar, xe Isuzu/biển số, Mazda/biển số/địa điểm.
- MB Bank account09886868247, tên chủ tài khoản, transfer payload, QR image.
- Email cá nhân/doanh nghiệp, MST, “đã gửi VAT/PDF/XML/chữ ký số”, “chuẩn NHNN”.
- Timer QR, timer verifying, fake SSE heartbeat, connection badge/webhook syncing.
- MoMo/Visa/VNPay linked/default, bank miễn phí24/7, thẻ bảo trì, bảo mật100%/256-bit/PCI-DSS, bảo hành48h.
- Các số hotline khác nhau19002470/19006868 là design data; xác nhận từ config nghiệp vụ trước khi nối call. Không gọi thử trong review này.

Không copy bất kỳ giá trị fixture nào vào live payment. Tên/địa điểm/CH chỉ hiển thị nếu có dữ liệu thật cùng request; TT/amount/status/timestamps từ payment getter.

## 13. Backend truth check GD1–GD4

### Nguồn backend đã đọc

- [GD1 security migration](../backend/supabase/migrations/202610100001_payment_core_security.sql) và [báo cáo](payment_core_security_implementation.md).
- [GD2A prepare/get](../backend/supabase/migrations/202610100002_payment_customer_prepare.sql) và [báo cáo](payment_customer_prepare_implementation.md).
- [GD2B select cash](../backend/supabase/migrations/202610100003_payment_customer_select_cash.sql) và [báo cáo](payment_customer_select_cash_implementation.md).
- [GD3 rescuer cash](../backend/supabase/migrations/202610100004_payment_rescuer_cash.sql) và [báo cáo](payment_rescuer_cash_implementation.md).
- [GD4 realtime](../backend/supabase/migrations/202610100005_payment_realtime.sql) và [báo cáo](payment_realtime_implementation.md).

| Phase | Source truth | Hệ quả với UI |
| --- | --- | --- |
| GD1 | Payment snapshot immutable; amount bigint/currency VND; TT server-assigned; RLS participant SELECT; client không DML; events private/append-only | UI không nhập/set amountExpected, TT, actor, timestamps, paid; không truy vấn raw ledger để render |
| GD2A get | customer_get_payment(p_request_id); kiểm owner trước; null khi chưa có; safe DTO | Đọc không tạo payment; null là chưa có payment, không đồng nghĩa0đ/paid |
| GD2A prepare | customer_prepare_payment(p_request_id); request và assignment completed; completion/current quote issued, price/currency nhất quán; amount>0; idempotent | Chuẩn bị payment theo explicit command; không auto-prepare từ watch/build; trả pending/method null hoặc payment hiện có, không reset |
| GD2B | customer_select_payment_method(requestId,paymentId,'cash',expectedVersion,operationId); method khác cash→METHOD_NOT_IMPLEMENTED; chuyển pending→awaiting_payment và version+1 | Cash là lựa chọn thật duy nhất. Không chuyển paid. Disable submit trong flight; gửi version/operationId đúng |
| GD3 | rescuer_confirm_cash_received; đúng assigned rescuer đã approved, completed request/assignment, cash awaiting, amount đúng expected, version đúng, operationId; atomic event/receipt/paid timestamps | Customer chỉ đợi/đọc. Không gọi RPC rescuer từ customer UI, không local cash confirm |
| GD4 | Publication chỉ payments; events/receipts không publish; source emit invalidation, getter refetch, watcher kiểm scope/version/auth | Chỉ đổi UI sau authoritative DTO; không dùng websocket row trực tiếp làm payment; stale/offline phải trung thực |

**Lưu ý idempotency quan trọng:** GD2B exact replay trả **response_payment cũ đã lưu**, có thể awaiting version cũ dù GD3 hiện đã paid. Không chép thẳng response đó vào UI để rollback paid; refetch getter và giữ quy tắc newer-version của watcher. Timeout không rõ command đã commit: retry **cùng operationId + cùng payload/expectedVersion**. VERSION_CONFLICT khác tình huống timeout: refresh, đánh giá state mới rồi mới quyết định command mới. Không sinh operationId mới cho mọi network retry.

**Deployment truth:** Các báo cáo nói đã kiểm SQL trong PGlite/RAM và Dart với mock transport; chưa áp production và chưa verify live Supabase Realtime/JWT/websocket/multi-client. Tác vụ này không deploy/kiểm DB. Source cash ready để làm UI; trạng thái production vẫn **chưa xác minh**.

## 14. REAL NOW / FUTURE và states cần render

| State/tính năng | Phân loại | Quy tắc UI |
| --- | --- | --- |
| cash | REAL NOW trong source GD2B/GD3 | Enable sau load/prepare hợp lệ; chọn cash chỉ chọn cách trả |
| pending + method=null | REAL NOW | Payment Method, chờ lựa chọn; không gọi “đã trả” |
| awaiting_payment + cash | REAL NOW | Cash Awaiting, số tiền cần giao, chờ đối tác |
| paid + cash | REAL NOW | Cash Paid từ getter, amountReceived + cashReceivedAt/paidAt |
| realtime | REAL NOW source/service/controller GD4 | Subscription invalidation→getter; production delivery chưa verify |
| bank_transfer | FUTURE | Có schema allowlist không có nghĩa có flow; GD2B từ chối |
| QR, account/copy/intent/expiry | FUTURE | Không hiển thị placeholder cho người dùng chuyển tiền thật |
| webhook/bank verifying | FUTURE | Không timer tự tiến state; không false connected/syncing |
| paid + bank_transfer | FUTURE | Không route bank success production từ local event |
| failed/cancelled/refunded | Schema dự trữ, chưa có mutation flow GD1–GD4 tương ứng | Khi backend thật trả thì cần read-only fallback an toàn; không tự set để mô phỏng |
| Loading getter/prepare/select | UI state phải bổ sung | Disable duplicate command; giữ nội dung phù hợp, không đổi payment enum |
| Null payment | UI state phải bổ sung | Giải thích chưa có; prepare chỉ qua command và eligibility server |
| Stale/disconnected/network failure | GD4 có flags; design chưa đủ | Giữ last valid DTO đúng user/request với notice; retry getter; không fake failed/paid |
| Access denied/logout/user switch | GD4 có guard | Clear sensitive snapshot, không hiện amount/receipt user trước |
| Invalid DTO/unknown method/status | Có error guard/fallback cần UI | Không suy ra cash hoặc paid; báo không thể hiển thị an toàn |
| Zero amount | Backend ZERO_AMOUNT_REQUIRES_POLICY | Không auto-free/auto-paid từ UI |
| Request completed | Trạng thái rescue riêng | Không dùng nó làm payment paid |

Payment null/loading/error chưa có trong Stitch phải thiết kế bổ sung dựa trên shared feedback; ghi đây là phần plan cần thêm, không phải screen đã tìm thấy trong project.

## 15. Security review UI — MUST NOT IMPLEMENT AS-IS

| Phát hiện | Mức ảnh hưởng | Xử lý bắt buộc khi triển khai |
| --- | --- | --- |
| Method sheet cash alert “Đã ghi nhận thanh toán tiền mặt” | Khách bấm chọn phương thức nhưng được thông báo giống đã thu tiền | Đổi thành “Đã chọn tiền mặt. Chờ đối tác xác nhận thu tiền”; chỉ sau RPC thành công |
| Hai paid screen render success tĩnh | Fake paid nếu mở trực tiếp route hoặc dùng flag local | Paid chỉ từ authoritative getter đúng user/request/method/status |
| Current Flutter “Xác nhận thanh toán” chỉ đi history | Gây hiểu nhầm hoàn tất | Thay bằng chọn cash/awaiting thật; không navigate như bằng chứng thanh toán |
| QR image + account/transfer/ref mẫu | Chuyển sai tài khoản/fake transaction | Bank future-only, không đưa vào live asset hoặc enable copy |
| Simulated realtime, webhook, countdown, refresh1200ms | Báo kết nối/verification không có thật | Bind state/service thật; thiếu backend thì unavailable |
| Cash Awaiting cho đổi QR/thẻ | Không khớp GD2B; nguy cơ multiple payment methods | Ẩn hoặc disabled “Chưa hỗ trợ”; không reset local |
| Method bank enabled, thẻ “bảo trì” | Khẳng định capability chưa triển khai | Chỉ cash enable; “Chưa hỗ trợ” cho future |
| Copy thành công dù clipboard fail | Phản hồi sai khiến nhập nội dung/account sai | Future: chỉ báo thành công sau kết quả clipboard thành công |
| QR timer về0 nhưng QR còn khả dụng | Expiry chỉ giả | Future: expiry server, disable/recreate theo contract, không timer giả |
| Paid cash “Đã đối soát”/receipt với bank style | Nhầm thu tiền mặt với tiền vào tài khoản hệ thống | Copy rõ đối tác xác nhận; không bank settle/payout claim |
| VAT/PDF/share/warranty/certification/hotline claims | Chứng từ và cam kết giả | Không bật tính năng/khẳng định nếu chưa có nguồn và nghiệp vụ thật |
| Read completed/quote rồi tự suy amount hoặc paid | Vi phạm snapshot source of truth | Dùng payment DTO; completed ≠ paid; không ưu đãi do UI tự tính |
| Realtime raw payload hoặc select replay cũ | Rollback/stale/fake paid | GD4 getter/version guard, same-request/owner kiểm tra |
| Lẫn request contact với KTV | Gọi/hiển thị nhầm người nhận tiền | Chỉ bind verified recipient data; không lấy contactName/customer phone làm KTV |

**Không phát hiện nút customer “Tôi đã thanh toán” hoặc “Đã trả tiền” trực tiếp trong 6 HTML payment.** Dòng “Đã nhận đủ tiền” ở Cash Awaiting nằm trong hướng dẫn thao tác **rescuer**. Nút “Kiểm tra thanh toán” của Bank QR không tự set paid, nhưng hiện chỉ toast/timer giả. Alert ở Method và hai success page vẫn là rủi ro phải sửa như trên.

Không cho UI customer tự set status='paid', kể cả qua setState, biến controller, click đánh giá, mở history, timer hết hạn hoặc refresh. Customer cũng không trực tiếp UPDATE bảng payments hay đọc/ghi payment_events/private receipt.

## 16. Stitch → Flutter mapping (chỉ PLAN)

Tên widget dưới đây là đề xuất, chưa được tạo.

| Stitch screen / ID | Flutter screen/widget đề xuất | Input / rule |
| --- | --- | --- |
| Customer Payment Method / `83d8804a503246e2bf3e89baf949da16` | payment_screen.dart → PaymentMethodSection + PaymentSummaryCard + PaymentMethodCard + PaymentMethodConfirmationSheet | Route có requestId/controller; pending DTO; cash-only enabled |
| Customer Cash Awaiting / `6b12b965628e4666911b7d2f011bde09` | PaymentCashAwaitingSection + PaymentRecipientCard + PaymentConnectionNotice | method=cash/status=awaiting_payment; read-only receipt state |
| Customer Cash Paid / `ef8318c14b8c42b2b6c9865af26489e4` | PaymentSuccessSection + PaymentReceiptCard | method=cash/status=paid từ getter; receipt fields server |
| Customer Bank QR / `bd756e87ab6a4299876b1ef8d40c649d` | Future PaymentBankQrSection + PaymentBankDetailsCard | Chưa đưa vào production route; chờ intent/QR/backend |
| Customer Bank Verifying / `59a97c6c9d9c443a87671e93a29f3f3c` | Future PaymentBankVerifyingSection | Chỉ state bank do server cấp, không countdown-driven |
| Customer Bank Paid / `aba372441d284c2a90b4e4baf1051f53` | Future PaymentSuccessSection bank variant + bank receipt | Chờ bank-safe DTO/ref/settlement |
| Hai phần payment/VAT account / `753b...`, `c30...` | Future AccountPaymentPreferencesSection trong new_account_screen.dart | Ngoài cash scope; không linked card/VAT giả |
| Tracking/history context / `13c...`, `d1c...`, `23b...`, `ace3...` | Entry từ new_tracking_screen.dart hoặc history_details_screen.dart | Truyền requestId rõ ràng; return xem HistoryDetailsScreen đúng request |

Chung: PaymentHeader, PaymentStatusBadge, PaymentAmountText, PaymentInfoRow, PaymentLoading/Error/Unavailable. Không tạo6 route độc lập cho6 ảnh nếu3 cash states cùng thuộc một request payment; một container state-driven giúp tránh mở paid khi chưa paid.

## 17. Màn sẵn sàng làm cash và màn future-only

**Có thể triển khai UI cash với backend source hiện tại, sau khi loại mock:**

1. Customer Payment Method — chỉ nhánh cash, pending và xác nhận chọn phương thức; bank/card unavailable.
2. Customer Cash Awaiting — bỏ đổi sang bank, nối thật GD4 stale/loading/retry; không xác nhận trả tiền từ customer.
3. Customer Cash Paid — chỉ từ paid/cash getter; bỏ VAT/PDF/share/warranty giả, dùng navigation/review đã có nếu hợp lệ.

“Có thể triển khai” không nghĩa pixel-perfect copy hoặc đã chạy production. Cần bổ sung Flutter commands prepare/select và route; không cần đổi backend contract cash vì thiết kế.

**Future-only:** Customer Bank QR, Customer Bank Verifying, Customer Bank Paid; nhánh VietQR trong Method; đổi bank trong Cash Awaiting; thẻ/ví/VAT saved preferences. Không có bank intent/QR generation/webhook/settlement/verify-bank production trong GD1–GD4. Giữ toàn bộ URL/reference ở báo cáo, không tải QR vào asset và không dựng fake bank UI đang hoạt động.

PDF/e-invoice/share receipt/warranty là feature riêng chưa được xác nhận trong payment scope, không tự coi đã sẵn sàng chỉ vì cash backend có paid.

## 18. Files Flutter dự kiến sửa (đề xuất, chưa sửa)

| File | Mục đích |
| --- | --- |
| frontend/customer_app/lib/screens/payment_screen.dart | Redesign từ mock thành state-driven container/sections, nhận requestId/controller |
| frontend/customer_app/lib/widgets/payment_ui.dart (mới, đề xuất) | Cards, cash sections, amount/status/header/receipt, scoped payment styles |
| frontend/customer_app/lib/services/payment_service.dart | Bổ sung command boundary prepare/selectCash, parse response envelope; giữ read/watch contract |
| frontend/customer_app/lib/app/app_controller.dart | Expose commands + in-flight/errors/idempotency + getter refresh; giữ một watcher scope |
| frontend/customer_app/lib/main.dart và/hoặc lib/app/navigation.dart | Route payment có required requestId/controller, xử lý invalid entry |
| frontend/customer_app/lib/screens/history_details_screen.dart | Entry “Thanh toán” cho đúng request đủ điều kiện, không suy completed=paid |
| frontend/customer_app/lib/screens/new_tracking_screen.dart (nếu cần entry) | Entry completed request, scope rõ |
| frontend/customer_app/lib/core/utils/payment_format.dart (mới, đề xuất) | BigInt-safe amount formatting, không ép double/int |
| frontend/customer_app/test/payment_ui_test.dart (mới, đề xuất) | UI states, action permissions, responsive |
| frontend/customer_app/test/payment_commands_test.dart (mới, đề xuất) | Command contract/idempotency/version/network outcome |
| frontend/customer_app/test/payment_realtime_test.dart | Chỉ mở rộng nếu phát hiện gap integration mới; giữ regression hiện có |

**Ưu tiên giữ nguyên:** payment_dto.dart/payment_watcher.dart nếu contract không đổi; app_theme.dart/mobile_ui.dart chỉ đọc/reuse, không bắt buộc sửa toàn cục; app_shell.dart giữ5 tab; pubspec.yaml/fonts/assets không cần đổi; toàn bộ backend/migrations/RLS/RPC không nằm trong plan cash UI.

Nếu cần shared variant button/header, cân nhắc scoped payment wrapper trước; không đổi style các màn đã có để ép khớp ảnh payment. Các tên file mới là đề xuất, không phải file đã được tạo.

## 19. Implementation order đề xuất

1. Chốt cash-only và data mapping: requestId→owned request/CH; DTO→TT/amount/currency/method/status/version/timestamps. Không đủ dữ liệu KTV thì bỏ/hiện placeholder trung thực, không tạo mock.
2. Thêm đường vào payment từ completed request theo requestId rõ ràng. Đọc getter; null/eligibility cần UI phù hợp. Không dùng fallback “completed mới nhất” cho một route đã chọn request khác.
3. Bổ sung prepare command GD2A và select cash GD2B ở service/controller: timeout, operationId ổn định cho retry, expectedVersion BigInt, handle conflict; command xong refresh getter. Không side effect trong build/watch.
4. Xây PaymentHeader và tokens/card typography theo CSS, layout350 tại width390, max480 local; reuse feedback/buttons và text-scaling behavior.
5. Implement Payment Method nhánh cash + confirm sheet; disabled bank/cards với copy “Chưa hỗ trợ”; không alert “đã thanh toán”.
6. Implement Cash Awaiting với backend data, call action khi có contact hợp lệ, notice stale/offline, refresh an toàn.
7. Implement Cash Paid dựa getter; receipt truth fields; CTA xem đúng HistoryDetailsScreen, review hợp lệ; bỏ feature chứng từ chưa có.
8. Nối lifecycle/navigation request-scoped watcher, logout/access denial clear; giữ version monotonic, không nhận select replay cũ đè paid.
9. Khi được giao triển khai, test meaningful: loading/null/unauthorized; pending→cash-awaiting; paid chỉ sau getter; double-tap/idempotent retry/version conflict; network timeout unknown outcome; realtime out-of-order/reconnect/foreground; user/request switch; BigInt >2^53; zero amount policy; large text320/390/480; disabled bank không gọi RPC; paid không do completed/local action.
10. Sau khi source UI được review và môi trường được chỉ định riêng, verify end-to-end với2 tài khoản customer/rescuer, unrelated user, reconnect và backend đã deploy. Đây là việc tương lai, không thực hiện trong review.
11. Bank chỉ bắt đầu ở phase riêng sau contract intent/expiry/QR/copy/webhook/authentication/idempotency/reconciliation và safe DTO; không unlock bằng frontend feature flag đơn lẻ nếu backend chưa sẵn sàng.

## 20. Kết quả review và mức độ sẵn sàng

- Đúng project **15211892260039587534**; **32 screen resource** gồm6 hiện và26 ẩn;28 UI +4 image/reference;3 design-system instances tính riêng.
- **6 màn payment chính**, screenshot6/6 và HTML6/6 đọc được. Đã tìm theo nội dung toàn bộ HTML, không chỉ tên.
- **3 reference dùng cho cash hiện tại:** Method(cash-only), Cash Awaiting, Cash Paid. Cần nối Flutter commands/route và bỏ mock; production deployment chưa xác minh.
- **3 bank màn future-only:** Bank QR, Bank Verifying, Bank Paid.
- Có2 account payment/VAT references và4 tracking/history contexts, không cộng vào6 màn payment giao dịch.
- **Có rủi ro MUST NOT IMPLEMENT AS-IS:** cash selection alert gây hiểu nhầm paid, success tĩnh, fake QR/account/ref, fake connection/timer, bank-enabled khi backend cash-only, current Flutter confirmation chỉ navigation. Không phát hiện customer-paid button trực tiếp trong6 screen, nhưng tuyệt đối không triển khai customer tự set paid.
- Không code, không commit, không migration/deploy, không asset download ra đĩa. Không chạy tests vì đây là read/analyze/report-only; kết quả tests trong tài liệu GD1–GD4 là lịch sử được đọc, không phải test mới của phiên này.

## Phụ lục: link screenshot và HTML từ MCP

Resource identifier đầy đủ của mỗi screen: `projects/15211892260039587534/screens/{screen_id}`. Bảng mục2 giữ link trực tiếp do get_screen trả; những link này là design reference, không phải nguồn xác thực trạng thái giao dịch.


[img-7459672242727792880]: https://lh3.googleusercontent.com/aida/AEtjO1UZs5QcDl_G7xJ3ksISLzozYjfrApmLFbOS0zgRLeoEW3agckmWM9039Hi_jH7BQUsn1bV5nopNbIqJkoKLAFGod7JEnKZNQHhz1XfuCMr4bSXw8o7DanhXvRhcgcptfCzUWo3Xt-FF4v0J9Tonirwp6bKveOQWbdVbkIJRR6IJ5OPZ06sJRZ1kcGaIUnP7i50E708DWLcfklCpJu5p0t2bTRyT4GiP4k1tILebVSSeXqNgyrbj5UzBPJKPRmZy5u5_0hQOD0rf6Xk
[img-06c2a74b70b24267b7f1831431e17132]: https://lh3.googleusercontent.com/aida/AEtjO1WkFDI-pJ12SqzbunwA5s8AHvj0NB8tW_1ATvB3d29hzaMjatkR-AbtyThWyqMPvMWYULIDAMbIRuMlwXdNzo_97ShOJppk4dmGm3WWzbF0HRN0h3ERW1lkA5WPHMq8K-OAEi6BH811PMV309pPXZfPFeuh_MkFhkBqtf7urBPXivTD0splZnaFmnXkYlnDBgaBJ_-lvoR33WVI8-Zb4EIZlutxMmBHuTA6TlmepTBGd3JJDyPOEkW3jnk
[html-06c2a74b70b24267b7f1831431e17132]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2Q3ODk1ZjRlZjAwN2M0YzUxZDU1MTRmZGJhEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-13c6068d371b4f9cbbb2fdaed2bfdb47]: https://lh3.googleusercontent.com/aida/AEtjO1URCEoiddnIvMp4EuuX4QlUBrN8d6mg0es7Yr_Y6_PaTQW6VkCvIFeZ2ZhViD-a2ERed7x0ZlcLMFAf21Qhjiz5_VLunNmbfYPB1hehL7qq8RnGvEmmdr_7BpBhrVYTzPEhSGZRAIpH5oAg9WrLPNNjGjqx-Zrp75VqS9_h-PsYiBa499aBu-f-cZqyuAlHh58bvK16rBlybuOtv3eoiGvSbxMQquSmg56qDJlD8AWV4sDXA2BvE4xbOSk
[html-13c6068d371b4f9cbbb2fdaed2bfdb47]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YxNDBmYjJhMWYwMzM4NWJkMzhiMWM3YjY0EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-17810f18484c45f8a7eab51869ce7908]: https://lh3.googleusercontent.com/aida/AEtjO1W_2OeaauV4gNH4PYybxB7yvElXGmOIixW397z2ubLVZ93VRqiVpPOSQ0ahVb8jXXJilO-ClIUadMd6Vxdb1F76fz6A1icSz_9XaxKFbjiqgkVTbfPDKduJDIBEx7dyqiQhYWUlb3qtbqO09TfZopXBxJ2oGQxYAwAnKcaq00ORCSFkGk0sVQx1bwLC7XA58-zAsPYwuHCtGSgOdty5AsUP7NpJeGIrP4T3npBm3hRVMwztCf7GGHX2QkBm
[html-17810f18484c45f8a7eab51869ce7908]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2Q3OGI0MzJiZjkwNWMyZmMwMTlmMWQxNzQyEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-206ebde95ce344b48c691861024b2e4d]: https://lh3.googleusercontent.com/aida/AEtjO1VwTlasgZMAwsv7Lkme1OTNsddT_T8dzUBwgAbC_OA539XWp0VxqnuxUwjTjDq57JEg2a7FldiN8EFyecJ-cNbMayEcsL0CWv62Lw3pfUwnjtYTzUvVkGkAOpKpFdjzf2SPkAZ_lDr4gdXKuhCRFmMwTH6RrqNzTUyf3lHRu7JN3s424V5Od8EV2ZFYeAiuaVU2__c-_IwkPKtO91uVt2oxRuRxWwov4AB_dFiNg5osA4l79XVjuwbN2aY
[html-206ebde95ce344b48c691861024b2e4d]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YwYmVhMWJmNzcwMjA3OWZiMGI2MWIyNTcyEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-23b62b9902a946a7b99979413ba794f7]: https://lh3.googleusercontent.com/aida/AEtjO1X5frt1AkBJt7K2yAwf46RvnSwAjBy3yY-4IUma03zqUR8Uq_d9vWoqqDcoIHW_EPH4RwsZ2-Z2XWvx1hPAColupyP81yQju4_2ZBCsWSvzEsl6kf6JM7UGe9kSi53Mx5qZuIvcf48R_Q1mkkGh4hTy1lWmejbYe07noxXPx9t8yaMUI9wkjIPNIdwHKm9KZFDoYu2QGuW7u2t3vhROxtv78ywo46ar4JMAFlYXMKFJfXm9r9BqA535mlsk
[html-23b62b9902a946a7b99979413ba794f7]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YxNDA0ZTg1NDEwNTc2MDE0NTc4MDMyZjFiEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-3217cfce0239451f9dfd04f6d6169fe7]: https://lh3.googleusercontent.com/aida/AEtjO1WVS2dC_1kVtYybTsTzidzVIE7Zj2_hNbvntDX0Ja4STPv99argDm0kYrUEdCDElL0Tq0V5H1a25xGL3MkXPdlv67yJ54DTvsFO3VTS54Vo16RPr7uGEoAQdkhfwwml9lR4VAvFhdYL8r9huQvZo4_g8rVi8F7YwwYAhaXhDKMQDGrtyYsTX4binFZlaBlJNdqbGyPGr0FKy7UVohwnx-MQYecvvp-RZfAP-ZW0MsSM1fa3b0Hia_K-7a7U
[html-3217cfce0239451f9dfd04f6d6169fe7]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YwN2YxZTExOWUwN2M0ZGMxZDFiMmEzOWUwEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-398a688b68ea408481f628ffb814238b]: https://lh3.googleusercontent.com/aida/AEtjO1Wr7q0klb3VNNqICqfbMlNTcabDgwp1OXgGwHtUE3guzsRTZ6-Ra4pCrzUtl4mloR8ZgYj8DCbHBZVHWQ-_t2gftmw4Fdvx1XdWIxtJEC3u8ADCTWvKoE1KO_z0-4o3aglDQkZOLNzxiS52TIasHlj5RhSXON7urEFO6Os8aC7wJz3G7uI3jzPIkLAPfW_tW5xUIdoE4lldevlWhWzzEA6OZ0W4UUEUCJ9JLJTmrLjlRo9paaeY0C4dL0Br
[html-398a688b68ea408481f628ffb814238b]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2Q3ODg4MDA0MjIwN2UwMDQwN2FjMTA5MWMwEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-59a97c6c9d9c443a87671e93a29f3f3c]: https://lh3.googleusercontent.com/aida/AEtjO1WLacyMtBmpjD5hzR_RzrBCTBp-D0wt74usJqgV3KOZeUFxbWbx4JDEq6ahJn1usCKc8B4FtGsZQKNZCn9FFgr68G5XEqXEiL3p7LGFMMqb4KFLR7ZaSP1XCH6ypK7_EWEevGJjJ4TIAKPT2wmU_v-CZ6gVXfVyBlyBGxdeqYeRpmu3_ODNmVd67-GgLGFoupS9fie8bFhSEA8ekrE3njaJ_zJY8VnjoMhBI64NFSZe9RTWtO_ovtQj4deJ
[html-59a97c6c9d9c443a87671e93a29f3f3c]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZDdiMjI1NDY5MDMwN2M0ZTU2NTFhMmY5OTIyEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-694460bce8a042368f984c67e29c40af]: https://lh3.googleusercontent.com/aida/AEtjO1UsgU0G71hKfuZckFizu58iGMRMPOVAmAyq8MRr-KGQyPqacZ8Kgsbp6DTzmtmJM2qjGtVaTooWlAHvgb43UoAVrA6cpYWe0BWY7b2WWFz_qEHku3EP2DryhVwRPFL6ZktAyo13d8atLfJ55xmX4lP7J_Z52_1RnUM--9mlTaBS9jq2CceRyKsyKep0hiGAlWB-_9WMAb1cFQYQ3AhBBl9_6JxLQ5dn2vThbW_rklmYOqOf_IlV2hR6ZBEd
[html-694460bce8a042368f984c67e29c40af]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YwYmYwNjcyMDIwMjA3YTkwYzEwMWEwNDA5EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-6b12b965628e4666911b7d2f011bde09]: https://lh3.googleusercontent.com/aida/AEtjO1XLw45ga6LvM5zkzdIFEoU3iVbdw9O_wxEYBXYyh44GafpDu34jiuvzwlUURV7TpByd6E35uXeRGdglsF_7plEJ6tFbeAQZE456Nu7PrFfkWroWYe488P9Tn_-4OyI4D5q1fJHvRxErF6vqL0N6SQ3Br_YLn8OtWhxSbv-UZnDdOjffAQ8gCsg7_ZWjddBDTXzrxX4VaooEdxfW67tEnkpE5k6v7ErMAdfp3YD2MFwny6aNA3axzgA1X4oW
[html-6b12b965628e4666911b7d2f011bde09]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZDdiMjMyNjlkNTQwNWMyZmNlMDM5MGFmYjNmEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-753b331a6ffa4341aadfafde01a881a0]: https://lh3.googleusercontent.com/aida/AEtjO1WX9VQuex3-fXW-ix5IbENc9pH7MvX-8CPXXO6dreqb0gZvhplHI-uyrw7jXMpljp840nPs14SvGrPcYPANW8fzRDlf3kPbb2Uiatz7d7g3a6MOT6hha7EeUgIXf6YgqABgeH6lKOiyUl5QgLDpOnthMeOHfuZt3HZRJIcUV8gZVtfv-VWabp2JaUKHC1oo7N7_6rZOf1Qpt3TVc-Wq2SyWhv5228AFcAkFvY-LV82Vwa0lf_7o41ZEqegg
[html-753b331a6ffa4341aadfafde01a881a0]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YxNDBlZGE3ZTYwNWMyZmQzOTM4Mzc3MzBlEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-1553543826145774209]: https://lh3.googleusercontent.com/aida/AEtjO1WHxKzWlQHmnivCDMmK0Ke9UABSGYI7QLQDIu48vlON664V-qdV4KtCW4d_W-qAScxPAPUWHXCAZ6J5pBV7EQpmn96Jlgd7Mka_EEu2zBB61Ced9ccJ8kM8REQxRK4f9m98PKfBsCACDPHQ9nLrT4p0UrND9OIPh9K3FlG379chCrsGWpNdti0Q-9NRcYmo5AHmanQpyiHEod77s8hhSrikfPxoMh3f2fm5LqLoKNg8Lx8ThZRjZOb1EZAwZv3Zb7eTf4KEcnFKyQ
[img-83799155581b493085050ef9808ace01]: https://lh3.googleusercontent.com/aida/AEtjO1UIhcaVN5rik7fG5iZqhRdC5cfJ208g7sVo6v-cRjzf1J8u8NQvO16VWTozZ9tcbyFeorTcr2lkwlTC_xivrPMQjUBi97pNFyHYHfxPmkG0b_PSgJ7dU4Ux6Dovha-gOEVQOea6x-bU0r45kCbAkuCDTmAMDxRC81mL8am2YW3Gh0DQmN3mTfT1J3ejINhS9n9gnUkTJBPb6sYoKTXusDYhy065I_Jr3PWDRym8-2MMEifng21S0LEEW1Aq
[html-83799155581b493085050ef9808ace01]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YxNDA2OWM2N2UwNzNhZTExYTUxM2IwOTY1EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-83d8804a503246e2bf3e89baf949da16]: https://lh3.googleusercontent.com/aida/AEtjO1Ub4_lekGl_w-YxJGJKztAvYmp4Jk8KtbVv5ezhBxrIKyhfxiYfw1HBsCThXVbrUaXS4eAtVfj4ZKdLKMf3MpYk3fGRD5TBCnw3Wir9oz6JFNOJHwaSZ3_Eu_leyj-CFJw-z1WrBtgg1i9a-uQBEiMOPGmee0pp2hBfktY_llPCJSc7ihe0l690X_WvzM8s6OOz0qRJFBZhWH67ExB1KOMAV64YoZruFHtKoTXPwCNuaOAZurlxIZwdwrU0
[html-83d8804a503246e2bf3e89baf949da16]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZDdiMjJjMTNmYTEwYTRjNGYxNDVhMmNkNjBkEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-895f01efe5d244ceaf7a02b3cdb7ca53]: https://lh3.googleusercontent.com/aida/AEtjO1UWFVoouS0DwvdReCc-9a6Hfi-LfAlBv1yJ81l_V_e59PHqiknVDcWG4dPa4J4ayHwQez0rRk3HS8RwEOVCk1u2bhBI8h8WxHS-HBHUEjXje5cXCTrbXTZRGwv31vInzpYOD1GNqpL2NSBss_SMq4wAiDLXZn46xNUjfSJtHfcpI8xmEA2TSSpaRa5P_UrudmiMbIoAOaWx0NP6yLuCDa-cPmLyslRRp6zJxEZ-VBlW1RWEnCKvW0icvDIx
[html-895f01efe5d244ceaf7a02b3cdb7ca53]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZDI2MGExY2IyOWUwMjA3YjgyNTJjMWNmODVlEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-8fa1ff44887b48779665883082a01bc6]: https://lh3.googleusercontent.com/aida/AEtjO1XjDgldrZ5Ex8ZrNdkbieHOwgMCjNlayP_rPDVI6r8j8y0DLg4s3-FLaHG3CYCvXFrmPIRheYsp8EsVvdlrILufobSysZVBa8fD8uvXla-ArzEQz8ZMYKio3k87OYqeZrMRicGHK4IrH07tY7VKDf9fYwSUUJY-oo9PPi7eyGB4NZt6_7xqwDwClfkatOoEBxYWaXb1eS_jeSCrkiN9adjzeGG_EDwQYCkrnCoPj9F4LSGTw_yR2LvNN4wo
[html-8fa1ff44887b48779665883082a01bc6]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2Q3OGEwMjhiNGIwMzM4NWJkMzhiMWM3YjY0EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-940e363705f0463eae7b0ec107c47d3f]: https://lh3.googleusercontent.com/aida/AEtjO1WZP8N00rev274hRj0lZ93jrWTCfPUlZ79Ptft3qL6t72BEmoYrtbpOpRnmBRy1LKOBMaQth_4lsMefXJ73cQPboO1LcNmQ467tEkrylCpV0VX_iJoGL1U6IPoeArnPiG1gw8BXx04Mh6Fnr0EhHx_-VRW3fWi_-Ahq5r9jA4_m_dJH97MA9F_IZM38wFxLl4lQ6eYKDpt394TOA6G0tnWM4Yc4rhs-P78gZv76DmSYpJqnqZL1GdsVaV6_
[html-940e363705f0463eae7b0ec107c47d3f]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YwN2YwZDI1MzQwMDMwMWZhZTZjMjk4ZmE0EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-a367f086a20248b6a0ea0d9956656440]: https://lh3.googleusercontent.com/aida/AEtjO1WnMJpzddlhognTG0LtXejHIXaZe4Ivnm3QwRbTKf23axqnqHjUxOtOL4VgbS8glup2L_lQJ8HxgmmSAbkbSMMlQVpIW7-GMYtD_tvnLE2jD9bmOMlL-Y-sFRKYy0e3LwFuVWNzrCKR7QwyWeTyUdz4-0OsmF0KWrq18cpQ4YjzLL6_SlG91JKbqjpPIeYfvyHk0LY4p25XdM5P2Aoerq0u-KKiH0NsIjRIzbNywo3MlkkjNW9nwyZPwdxN
[html-a367f086a20248b6a0ea0d9956656440]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YwOTNhMjYxM2UwN2UwMDQwN2FjMTA5MWMwEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-aba372441d284c2a90b4e4baf1051f53]: https://lh3.googleusercontent.com/aida/AEtjO1UmhpKHTgyogGxzRkmI6YXz39IhoqWwOsL9ZiXwX1e14DPKP9IcB9R3VB3jOJ3j__uEoOwmAxvoLJEyKfaEx7V7A1pjUrIAiD3W0qkvjlQq3jSBLoGWB8UT7PuPZnvtBX_9U-Ts3mnOg5m-_5ZXabJmV9dr4vfW4T17nCAf2nG5ELvKV9JYhy4kOVBpHAGzcDmnVIx2qjDwLe6KW4AF_YzDwwb8h-raomdyLZcYy9GeBUrYI0saAENDxnof
[html-aba372441d284c2a90b4e4baf1051f53]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZDdiMjMxNWM1YTkwMzMyYzBlZDg0MzFlN2QwEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-ace3f779031845f9ae6fc73aeb36ad80]: https://lh3.googleusercontent.com/aida/AEtjO1W2UiuI8uHWaWPJcItHIBH8Pg2M68x79NS3C532D4dXSpTqRYLB4lsiQERCKW_BLM8dKud0LLt0LeaWFiYRpng3jKnJlJ5o6Q4QcrSx463gHbj8xIT1HYWmS7jQ-BSOtb2WRhEwSNp4yVget_ygd853XY6bZqSie5ca2vdTUcJ814c80KfBAaX73U5_JpmjaERrmCe6NYbCtjYWkSrcXcM7yLjvuJx1eagrg6zwlfl_9Z4utIQt0f3aTO4v
[html-ace3f779031845f9ae6fc73aeb36ad80]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YwYmViMWNjYWMwMmE5OWZlOWI4MWE2NWI0EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-b0c1364ba4e144fcba60b1616779dcc8]: https://lh3.googleusercontent.com/aida/AEtjO1Vxv83bblZW5JEQGLk4bjbcQHZ97FZAg0yLQ17XbSvQ2S9klweyfKx_aU9LigSeEYhKbw09dcydifGOcNdiG1Ff9fow4spDZInrSETnP2QZa5w4FUe5wntzeaLAmQpFiziuLrkG4Vuzhe27BngUIW9DVXu5YNTGO3iHOO1bNuBAl7zNVL9rKN89jzbq6Q9BHFp1NM7Q-4qTtrZoy9SzYw-D2Vcf2U3x8WMaIjEfCdp5AuLck-uG8KJnFf-n
[img-bd756e87ab6a4299876b1ef8d40c649d]: https://lh3.googleusercontent.com/aida/AEtjO1XaQy5gt7H_4kooPVb-GLPlxamp1-8QrfvBtlQ_JFyhqoeBQCjdDaBLl3KijeRvdrTccCSM_HfBVJF6I981-SrFvf7RY5gL_bVY6cb_po4G62W3RiWNuRfnDokqWmMbkh_V0YCuLrMsa1aYqGjsiB5USixOUL9ErriyQUJbTtQ3-ijDqZ_G8JcRsbMQTwP672lx6O4uJh6aTZgTTK0TOy2t5sHs8HwUyxHyx6U_qa23-jjBgPmVdwacVIXR
[html-bd756e87ab6a4299876b1ef8d40c649d]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZDdiMjMzMmE1YzgwNTc2MzE3MmVkMTExM2YyEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-c30e75d700b748cdacaf555d15021de2]: https://lh3.googleusercontent.com/aida/AEtjO1Whf4ntY53a4Lcd2MPe2Eny3v02ly6hDyFJEhAQQIfd9ZbFM1GAc-kqcycru-1HTj6xGAAYiorUqCD9sV4Vgjgd91fR9skXPEq9GrkPoY_CjBvd_ZEuYlwJyV0NRQz0zSTjUQFZu5J7CItpFHrUI5M8z7gdh4JXFx72gRd-2rU0VA7FDwVJotyTUABfcQmD8LCoL2ivl8D-q1Z3RPfemfOTJFP1FM3xxqeSm_i8842T-NYnJt8rDie3aFw
[html-c30e75d700b748cdacaf555d15021de2]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YwYmVkMDljODYwMjhmMDk1NjRlMDZhNDI4EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-c45e93e0decd4c1292c56d842d574b72]: https://lh3.googleusercontent.com/aida/AEtjO1XmWWE1U94zouThfsFHMe8FwPAnUCjAZs_o0zpPQGwJ0R50huk03LetSyxBhXUjVOh8DtKsxPn8lYrMUitnkG6-rxa03Hicz5v0ItQN_NNgkN9PKuxM4wikooXeT4HWN03B9n7KPCiDU-A7kQXJU2tNKgCyfh6tQVNX0WVtlLGbN8qwYfwg9ppy6Jh2EcamefTjh9CjHQW5yRTrcLjn73xM7vFyXMB_kXcZPYkBy0x-rRxEEFp2yW9eahG2
[html-c45e93e0decd4c1292c56d842d574b72]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2Q3OGI5ZjdjMDkwNzc5YWVmNmE4MTRhY2M0EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-d1c6f49df78c41dca159fb5b1402557b]: https://lh3.googleusercontent.com/aida/AEtjO1X53s09BaIFWt5czNPmqPBvMuywkNQxJmo7Rec67eOnSpm9mmA5FHkfSYqVuJCwilKT_pDAcpDWYlVln25uQE5YuuQWG5pLLI1gSoC8AVdLd5zICxeR30vL-EX9bL1PXJVNXLbzVwv7FEVAVytEgysqsf5upsflazkeIl1mFl-Cp6v16ni2xJtAY_5YpvyXg8kUIZDi9zxplfJu9Uc5UfeB09e8fjN0v_G6BW8369ekH1FOPVNBJeKSSmP1
[html-d1c6f49df78c41dca159fb5b1402557b]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YwYmYzMTgzOWEwMjA3OWZiMGI2MWIyNTcyEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-d2fcf03d7d2d4cb689524d23b10eb80a]: https://lh3.googleusercontent.com/aida/AEtjO1VsIQt0JUT_w3ghsUpscts4VKG9dNN2YsDteMyKD8GhLqqskM78y0UmEUcu9a5wCdUXrrqXYAHW1GAKTbydzdLEXyIO6yRZkQamfKo9EmBqF8OQIqAOB0T4NGECql8-GKOE_jjtfQaIVFjiEZDEgLN7eMIl9Y2623VYL_dSi35PUcjbL_9iITiegWK_vAE5oG67tOm-OL7-h_GdaNlTEAhMPb36aIVG5eVsvJo96ftMWLLDw4mTt6RCrVeO
[html-d2fcf03d7d2d4cb689524d23b10eb80a]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YwN2U3NDhkMDMwMjA3OTllNTcyMTFlNmY2EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[html-d4244d2210de42d1b6f5c8cdb531eb98]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2ZhNjVmMjcxNjYwNTc2MDE0NTc4MDMyZjFiEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-e7b2e94240f743769a19261e0ecf3cb1]: https://lh3.googleusercontent.com/aida/AEtjO1Uqu_1aWnMpBvzwXA_pxJQOj0zc3tJMXl3UrE6sv-LTwxtSYtWR1Puyj7IFtWXT6Pviooxy_fwqcKZiaNftfix1ZJjTK1J_QFqhdHbdCtT9GePfQHGHTINeLyDp1Bdpu0u9zN2uPuh6o4F1cGaybDZmsO_WK1Bx7XWH7cjalpmh8JR1_QvfD2mpJ6b2_YArXjJ2HESrnXpyC_9ZjN_VZWd-diwMqiUrh69pv2Blp4EnZ02-hUSHvAhkGGw
[html-e7b2e94240f743769a19261e0ecf3cb1]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2Q3ODVjNDMyN2UwNTNiNzM5MWJiMDk4Mjk5EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-e7c500e1b16e4ab9aa4a4f24256aaebb]: https://lh3.googleusercontent.com/aida/AEtjO1XGGY1DMLftYBiVNbbpBAI9bAzHu-RY40dOIFUk3BjOZvEaohFCaQAuqXGCmkRAGGWbtJkVOympN7EHYuQcx2qd4M6EBe7DuUxRmAlDXzIMSHGUM3f8XewdmlSeRY6Qwaj5sQORqD4fQI9JUffspajZqgBvLB3GVrCsxE7xuq0KOBBfY99H5HYSF591g1Hwb2lZzYKXISKtKtRSqgKUceKLjf4jGphXhnLNvcj5zjxw4u9yByr2ynCC1o0
[html-e7c500e1b16e4ab9aa4a4f24256aaebb]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2Q3OGIzNDdlNmUwNDMxMDNlMDkxMzQ5N2U1EgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-ef8318c14b8c42b2b6c9865af26489e4]: https://lh3.googleusercontent.com/aida/AEtjO1WaUEh7NNCUn--3Tet_r1p1s3UPF4xwyzMwjWDNEGQ6gqEIWo3R2gOFxSqyHQqqyxXWpyAZqhB3SS9qgJ6W1IoD6WSmWGOtlfH70nXzg8f_4UB04MqroeNyMn8CcuGo9ZOd1xSOEtEqLnz_GGkZSBnhk72z8RDXR5i-Zq06AtxkVb0HkSvpvZD7ng5WQZJt9gNiPgWCII0ORyLT5giCqyZ0I7UiK6nuKZt1lZVKHQVb__NOAKRtNSyF-oAt
[html-ef8318c14b8c42b2b6c9865af26489e4]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZDdiMjJhZGZiZDgwNzc5YTA1ZjhhMWU3ZTNjEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086
[img-ffe3f13b0106406b8a5c8fdd1067c207]: https://lh3.googleusercontent.com/aida/AEtjO1W2rZZ33Ou5TCEpFJ79ZlHaM-6fgBn9KqOFBwCywCRZKDtkPuk6IS6gYe1F3S_fjz6EBDaJbeLoZ6Co_YwfyGZH4c-WYAWzdbIf2g4Ppv3ZAsAJS15UZ6iB0dGzWn8vQn-bTeh-UQPihXV4-xQNHBHFlhQqJeffBtB_XCphrPC8pgavIwrFFIX96i9dBklHkPSgbYLllpzxx5pH6ArIhkDqLbSD-hCrrJPyGg9dUVRD8wbxYFda1-cq1MtJ
[html-ffe3f13b0106406b8a5c8fdd1067c207]: https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1Y2YwN2YyYTMzYWQwNTc2MDE0NTc4MDMyZjFiEgsSBxDrxaGksgQYAZIBJAoKcHJvamVjdF9pZBIWQhQxNTIxMTg5MjI2MDAzOTU4NzUzNA&filename=&opi=89354086

