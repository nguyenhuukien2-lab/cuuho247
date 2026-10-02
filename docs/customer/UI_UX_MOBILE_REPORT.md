Báo cáo nâng cấp UI/UX khách hàng Cứu Hộ 24/7 — 02/10/2026

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

Đã nâng cấp giao diện app khách hàng theo Material 3, nền sáng, xanh đậm làm thương hiệu và cam cho hành động cứu hộ. Giữ các controller/service, Supabase, RPC, migration, GPS, chọn vị trí OSM, upload ảnh và realtime hiện có. Không thêm dependency hoặc Google Maps API key.

**Những thay đổi chính**

- Theme chung: màu trạng thái, spacing 4/8/12/16/20/24, radius 8/12/16, card viền mỏng không shadow, input radius 12, focus xanh đậm, lỗi được wrap. CTA cao 54; nút phụ tối thiểu 48. Cam `#C94D0A` đạt tương phản khoảng 4,62:1 với chữ trắng.
- Home: lời chào theo tên, hero “Bạn cần cứu hộ?”, CTA “Gọi cứu hộ ngay”, đầy đủ năm dịch vụ và lựa chọn phương tiện. Dịch vụ mở form với lựa chọn tương ứng. Có card đơn đang xử lý. Bỏ bản đồ vẽ minh họa và thông báo giả về tích hợp bản đồ.
- Bottom navigation: Material 3 NavigationBar giữ đủ năm tab, chữ 12, indicator xanh nhạt, icon/chữ active xanh đậm. Fade nhẹ khi đổi tab, giữ IndexedStack để không mất draft. Tôn trọng thiết lập giảm animation của hệ thống.
- Tạo yêu cầu: section dịch vụ, phương tiện, vị trí, GPS/map, ảnh, mô tả, liên hệ và xác nhận. Chọn xe/địa chỉ dùng kiểu input đồng nhất. Xác nhận ở gần nút gửi màu cam. Giữ validation, disable, lỗi, idempotency và retry ảnh còn thiếu.
- Tracking: trạng thái và timeline ở đầu, các bước dọc có icon/đường nối; map/vị trí, thông tin yêu cầu và ảnh thành các section riêng. Hủy dùng đỏ tiết chế. Bỏ các nút gọi/chat và card người hỗ trợ chưa có dữ liệu/chức năng thật; giữ subscription/lifecycle/cập nhật trạng thái/hủy đang hoạt động.
- Lịch sử: tên dịch vụ và chip được tách dòng, ngày giờ và địa chỉ dễ scan, phương tiện/chi phí có thể wrap. Empty state có hành động tạo yêu cầu.
- Chi tiết lịch sử: header trạng thái, thông tin yêu cầu, vị trí/map, ảnh, timeline, báo giá và đánh giá. Không thay đổi repository hoặc nguồn dữ liệu. Sao đánh giá có vùng bấm tối thiểu 48 và tooltip.
- Tài khoản/hồ sơ: card avatar, thông tin rõ, sửa hồ sơ và lưu theo theme chung; menu tập trung vào xe, địa chỉ và đăng xuất. Bỏ các mục thanh toán/hotline/thông báo/pháp lý chưa triển khai. Hồ sơ tiếp tục dùng editor tích hợp trong màn tài khoản.
- Xe/địa chỉ: card cách nhau 12, icon theo loại xe/nhãn địa chỉ, badge mặc định/có tọa độ, nút sửa/xóa và dialog đồng nhất. Editor cuộn và đóng bàn phím khi kéo. Editor địa chỉ giữ nhập tọa độ hiện có; không thêm một luồng GPS/map mới.
- Ảnh/map: preview đã chọn chia đều ba ô, ảnh đã gửi chia hai cột theo chiều rộng, bo góc, loading/error tải ảnh gọn. OSM radius 16, marker cam có semantic label, overlay hướng dẫn, attribution chữ 12 và state thiếu tọa độ có icon. Giữ retry tile và chọn tọa độ thật.

**File sửa/thêm**

| Nhóm | File |
| --- | --- |
| Theme và shell — sửa | `frontend/customer_app/lib/app/app_theme.dart`, `frontend/customer_app/lib/app/app_shell.dart` |
| Home, form, tracking — sửa | `frontend/customer_app/lib/screens/new_home_screen.dart`, `frontend/customer_app/lib/screens/new_request_screen.dart`, `frontend/customer_app/lib/screens/new_tracking_screen.dart` |
| Lịch sử — sửa | `frontend/customer_app/lib/screens/new_history_screen.dart`, `frontend/customer_app/lib/screens/history_details_screen.dart` |
| Tài khoản/xe/địa chỉ — sửa | `frontend/customer_app/lib/screens/new_account_screen.dart`, `frontend/customer_app/lib/screens/customer_vehicles_screen.dart`, `frontend/customer_app/lib/screens/customer_saved_addresses_screen.dart` |
| Widget chung — sửa | `frontend/customer_app/lib/widgets/rescue_widgets.dart`, `frontend/customer_app/lib/widgets/saved_vehicle_picker.dart`, `frontend/customer_app/lib/widgets/saved_address_picker.dart` |
| Map/ảnh — sửa | `frontend/customer_app/lib/widgets/rescue_location_map.dart`, `frontend/customer_app/lib/widgets/request_location_card.dart`, `frontend/customer_app/lib/widgets/request_photos_card.dart` |
| Hồ sơ/đánh giá — sửa | `frontend/customer_app/lib/widgets/customer_profile_card.dart`, `frontend/customer_app/lib/widgets/customer_request_review_card.dart` |
| Widget mới | `frontend/customer_app/lib/widgets/form_section.dart`, `frontend/customer_app/lib/widgets/request_timeline.dart` |
| Test hiện có — sửa | `frontend/customer_app/test/customer_saved_addresses_test.dart`, `frontend/customer_app/test/customer_vehicles_test.dart`, `frontend/customer_app/test/request_failure_test.dart`, `frontend/customer_app/test/request_location_test.dart`, `frontend/customer_app/test/request_photos_test.dart`, `frontend/customer_app/test/tracking_test.dart` |
| Test mới | `frontend/customer_app/test/mobile_ui_test.dart` |
| Báo cáo mới | `UI_UX_MOBILE_REPORT.md` |

Các test hiện có được cập nhật theo CTA mới/thao tác cuộn tới section mới. Test chọn xe đóng snackbar sau lần gửi thành công trong fake controller để nút gửi lần hai không bị che. Không xóa test hoặc giảm assertion về nghiệp vụ.

**Kết quả kiểm tra tự động**

- `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`: PASS, exit code 0; không có error. Còn 44 issue từ các màn cũ: 4 warning về biến/widget không dùng trong `login_screen.dart` và 40 info deprecation `withOpacity`. Các file UI được chỉnh không có issue trong lần analyze cuối.
- `flutter test --no-pub --reporter compact`: PASS, 118/118 test, gồm 108 test hiện có và 10 test mobile mới.
- Test mới kiểm tra viewport 360×800 và 390×844: năm tab/CTA/giữ draft, ba ảnh preview, CTA khi bàn phím cao 300, tracking các trạng thái đang xử lý, lịch sử với địa chỉ dài/chi phí, receipt/timeline/sao đánh giá và editor xe/địa chỉ/hồ sơ. Tracking/history còn được kiểm tra với text scale 1,3. Không ghi nhận exception overflow trong các trường hợp này.
- Test map dùng tile provider xác định trong `flutter_test_config.dart`; không kiểm chứng việc tải tile OSM ngoài mạng.
- Không đổi `frontend/customer_app/pubspec.yaml` hoặc dependency, nên không cần `flutter pub get` cho thay đổi này.

Lệnh analyze mặc định có bước resolve package và gặp lỗi quyền tạo thư mục `D:\FlutterCache\Pub\_temp`. Flutter trong sandbox cũng không hoàn tất bước cache. Vì vậy kiểm tra cuối chạy ngoài sandbox trên chính workspace với `--no-pub`, dùng package frontend/customer_app/config/package đã có. Không tạo bản sao tạm. Đây là kiểm tra mã và test thực tế, không phải xác nhận một lần cài package mới thành công.

**Chưa kiểm thử thực tế trong lượt này**

Chưa chạy app trên Chrome hoặc OPPO `86ab44a0`, chưa build APK. Chưa kiểm chứng cảm giác cuộn/animation, bàn phím thật, TalkBack, tile qua mạng, GPS thật, camera/gallery/quyền truy cập, upload Supabase hoặc realtime qua mạng trên điện thoại. Widget test dùng fake repository và tọa độ/tile xác định; không thay thế kiểm thử thiết bị.

**Lệnh kiểm thử thủ công**

Chrome:

```powershell
flutter run -d chrome --dart-define-from-file=config/supabase.dev.json
```

OPPO qua cáp:

```powershell
flutter run -d 86ab44a0 --dart-define-from-file=config/supabase.dev.json
```

APK debug:

```powershell
flutter build apk --debug --dart-define-from-file=config/supabase.dev.json
```

Nếu môi trường vẫn bị lỗi quyền ở cache package, có thể dùng các package đã có bằng cách bổ sung `--no-pub` vào các lệnh trên.

**Checklist trên điện thoại — cần thực hiện**

1. Mở app ở chiều rộng 360–390px; kiểm tra chữ và spacing với cỡ chữ Android mặc định/phóng lớn.
2. Kiểm tra Home, lời chào, CTA cam và chọn nhanh đủ năm dịch vụ.
3. Chuyển đủ năm tab; kiểm tra nav không cắt chữ và draft form được giữ.
4. Tạo yêu cầu bằng xe/địa chỉ đã lưu, GPS/chạm map, ảnh camera/gallery và mô tả/liên hệ.
5. Kiểm tra mất mạng/loading/submit lỗi/upload ảnh lỗi; form và ảnh được giữ, retry đúng, không gửi trùng.
6. Kiểm tra tracking realtime, timeline/map/card và hủy với confirmation.
7. Kiểm tra lịch sử, bộ lọc, địa chỉ dài và chi phí.
8. Kiểm tra detail có/không có map, ảnh, timeline, báo giá; gửi và xem đánh giá cho đơn hoàn tất.
9. Kiểm tra Account/Profile/Vehicle/Address đồng nhất; thêm/sửa/xóa, validation, lưu thành công/lỗi và đăng xuất.
10. Kiểm tra overflow/cắt chữ, tap target, cuộn qua bản đồ, nút cuối khi bàn phím mở và nội dung không bị nav che.
