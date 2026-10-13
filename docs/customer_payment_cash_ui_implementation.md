# Customer Payment Cash UI — implementation

Ngày: 10/10/2026. Workspace: `D:\DAndroidStudioProjects\flutter_app`.
Nguồn thiết kế: [Stitch review 15211892260039587534](customer_payment_stitch_review_15211892260039587534.md).
Phạm vi: customer cash only. Không thay đổi backend, migrations, RPC/RLS, rescuer/admin, pubspec, theme toàn app hoặc asset. Không commit.

## 1. Stitch screens implemented

| Screen | screen_id | Flutter / điều kiện render |
| --- | --- | --- |
| Customer Payment Method | `83d8804a503246e2bf3e89baf949da16` | `PaymentScreen`, `PaymentSummaryCard`, `PaymentMethodCard`, `PaymentConfirmationSheet`; getter pending + method null |
| Customer Cash Awaiting | `6b12b965628e4666911b7d2f011bde09` | `PaymentCashAwaitingSection`; getter cash + awaiting_payment |
| Customer Cash Paid | `ef8318c14b8c42b2b6c9865af26489e4` | `PaymentCashPaidSection`; getter cash + paid |

Áp dụng visual từ review screenshot + HTML đã hoàn thành; không phân tích lại project hoặc tạo/sửa screen Stitch.
Header xanh #0037B0, nền #F8F9FF, chữ #0B1C30 / #434655, panel #EFF4FF, awaiting amber, paid xanh #006C49 / mint #6CF8BB.
Plus Jakarta Sans dùng asset đã có. Body 14/20, title 18/24, amount 28/36; paid amount 36/44.
Content padding 20, reference 390 → content 350, max-width riêng 480; card radius 12/20, sheet 24; CTA min-height 56, nội dung tự tăng chiều cao theo text scale.
Sheet cuộn, hai CTA xếp dọc để không clip ở 320 / chữ lớn. Cash icon Material thay asset riêng. Paid CTA cam #F97316 mở chi tiết đúng đơn.
Không mô phỏng browser CSS pixel-for-pixel hoặc tuyên bố đã chạy golden/screenshot comparison Flutter–Stitch.

## 2. Files changed trong tác vụ này

| File dưới frontend/customer_app | Thay đổi |
| --- | --- |
| `lib/screens/payment_screen.dart` | Thay toàn bộ màn mock bằng state từ shared controller/getter; explicit request route; sheet, loading/null/error/stale/auth guards |
| `lib/widgets/payment_ui.dart` | Component/tokens chỉ dành payment, cash pending/awaiting/paid, responsive sheet và CTA |
| `lib/services/payment_service.dart` | Interface command; prepare/select cash RPC; immutable payload; UUID operation ID; timeout và safe error mapping |
| `lib/app/app_controller.dart` | Command orchestration, double-submit coalescing, retained retry payload, route/user pin và authoritative refresh |
| `lib/main.dart` | Route `/payment`, argument là requestId String; thiếu/sai kiểu → safe invalid-request state |
| `lib/screens/history_details_screen.dart` | CTA “Thanh toán” cho completed request đúng ID/phiên, mở route đúng request |
| `lib/core/utils/payment_format.dart` | BigInt decimal grouping và timestamp formatting |
| `test/payment_commands_test.dart` | 15 tests command/controller/HTTP contract |
| `test/payment_ui_test.dart` | 38 widget tests gồm route/auth/state/responsive |

Báo cáo mới: `docs/customer_payment_cash_ui_implementation.md`.
Giữ nguyên `payment_watcher.dart`, `payment_dto.dart`, `payment_realtime_test.dart`, `new_tracking_screen.dart`: reuse GD4 đủ cho flow này.
Workspace có nhiều thay đổi trước tác vụ. Đối chiếu SHA256 với baseline 460 file tracked/untracked (frontend/backend/admin/docs) xác nhận chỉ 9 file customer trên thay đổi/thêm trước khi ghi báo cáo; không suy ra phạm vi tác vụ từ toàn bộ git diff có sẵn.

## 3. Route, ownership và metadata

- `PaymentScreen` bắt buộc `requestId` và `AppController`; không tạo controller mới.
- Route payment pin một token + requestId + owner của payment source. Background tracking/history hydration không được chuyển watcher sang active/latest-completed request khi route đang mở.
- UUID không hợp lệ hiển thị lỗi an toàn, không gọi getter/prepare/select. Backend getter/RPC vẫn là authority xác minh quyền.
- Lần getter đầu tiên hoàn tất mới hiện null-payment/prepare. Không coi DTO chưa tải xong là null authoritative.
- Request details chỉ dùng CH code/service/eligibility khi row.id đúng request và row.customer_id đúng authenticated owner. Metadata lỗi không tạo mã CH/amount giả.
- Contact name/phone của customer không được dùng làm rescuer. Không hiển thị recipient/KTV/avatar/vehicle/phone khi chưa có nguồn đúng rescuer.
- Auth change xóa DTO qua watcher và xóa command state; route cũ bị vô hiệu kể cả A → B → A. Late response và sheet của phiên/request cũ không lộ lại thông tin.
- History completed chỉ cho phép mở payment; không tạo paid. Eligibility thật của prepare còn do backend kiểm tra assignment/quote snapshot.

## 4. Prepare command

`PaymentCommands.prepare` → `SupabasePaymentSource.prepare` → `customer_prepare_payment(p_request_id)`.

Chỉ chạy từ CTA “Chuẩn bị thanh toán” khi getter null và metadata owned request completed. Không gọi prepare trong build, watcher hoặc callback realtime.
Controller giữ single-flight task, kiểm tra auth/request scope, chặn khi DTO đã tồn tại/loading/getter error. Backend chịu trách nhiệm eligibility và idempotency request.
Sau command, gọi getter refresh; không đưa DTO trả từ prepare vào state.
Thông báo riêng cho `PAYMENT_NOT_ELIGIBLE`, `ZERO_AMOUNT_REQUIRES_POLICY`, `QUOTE_SNAPSHOT_INCONSISTENT`; không đổi missing payment thành 0.

## 5. Select cash command, idempotency và concurrency

`selectCashPayment(requestId)` → `selectCash(CashPaymentSelection)` → `customer_select_payment_method`:

- `p_request_id`: request được pin.
- `p_payment_id`: payment từ getter.
- `p_method`: cố định `cash`.
- `p_expected_version`: BigInt từ getter, serialize decimal String.
- `p_operation_id`: UUID v4 tạo bằng Random.secure cho một thao tác mới.

Controller reserve task trước notify; double tap dùng chung Future và chỉ gửi một RPC. Sheet có loading/disable CTA, khóa back trong submitting và kiểm tra lại submitting đồng bộ trước submit để tránh đóng route hai lần.
Nếu timeout/network outcome không rõ: giữ nguyên object payload, operationId, paymentId và expectedVersion cho lần retry. Không tái tạo key theo lần retry hoặc thay version theo getter mới.
Retry thủ công dùng lại payload trong controller, kể cả đã rời rồi mở lại cùng request trong cùng vòng đời controller. Không có vòng lặp retry command tự động.
Lỗi definitive như VERSION_CONFLICT được hiển thị, getter refresh, bỏ attempt cũ; thao tác mới sau đó dùng version mới.
Kết quả command/replay chỉ là acknowledgement, bị bỏ phần DTO. Getter/version guard luôn quyết định state. Nếu acknowledgement thành công nhưng getter vẫn pending/stale, không cho gửi thêm selection mới; có refresh an toàn.
Sau chọn thành công: “Đã chọn tiền mặt. Chờ đối tác xác nhận thu tiền.”; notice chờ không còn hiển thị khi getter đã paid.

## 6. Realtime, lifecycle, stale/offline

Reuse đúng `AppController.payments` / GD4 `PaymentWatcher`, một source và tối đa một subscription active. Không thêm watcher/subscription riêng trong UI.
Realtime INSERT/UPDATE là invalidation → getter refetch; không tin raw row để render paid. Giữ version guard, reconnect, resume, generation guard và cleanup auth có sẵn.
Màn payment chuyển lifecycle vào controller; watcher bỏ qua foreground value trùng nên không tạo subscription thứ hai với AppShell.
Network failure/disconnected giữ last valid DTO trong đúng user/request, hiện “Dữ liệu có thể chưa được cập nhật.” và refresh. Không biến lỗi mạng thành payment failed.
Lựa chọn cash bị disable trong UI khi loading/stale; pending có refresh. Không tự prepare hoặc chọn lại phương thức khi reconnect.

## 7. Paid guard và dữ liệu thật

Paid UI chỉ đi qua nhánh `PaymentDto.method == 'cash' && PaymentDto.status == 'paid'` của DTO getter.
Route, completed request, local bool, timer, chọn cash thành công hoặc command response không tự tạo paid.
Paid hiện amountReceived, paymentCode, CH nếu xác thực được, cashReceivedAt ?? paidAt và phương thức cash. Nếu optional field thiếu thì hiển thị thông tin chưa có; không suy ra amountReceived từ amountExpected hay giờ thiết bị.
Wording: “Đối tác đã xác nhận nhận tiền mặt.” Không claim settlement/đối soát/tiền vào hệ thống/khóa sổ.
Awaiting hiện amountExpected/currency/code và yêu cầu trả trực tiếp cho đối tác. Không có “Tôi đã thanh toán”, “Đã trả tiền” hoặc API customer confirm paid.

BigInt không chuyển qua double/int khi format hoặc serialize version; test kiểm tra 9007199254740993 và 9223372036854775807. VND hiển thị dạng `850.000 đ`.
Zero amount/unsupported currency được xử lý an toàn, không cho chọn phương thức như một giao dịch hợp lệ.

## 8. Fake data removed và bank handling

Đã bỏ khỏi payment UI: 170.000đ, #RQ-8839, fake line items/discount/time, MoMo default, lựa chọn VNPay/cards giả, nút giả xác nhận thanh toán rồi mở history, bảo hành giả, PCI-DSS claim.
Không thêm VAT PDF/XML/chữ ký số/share receipt/QR/bank ref/account/hotline chưa xác thực/rating giả/avatar hoặc thông tin KTV giả.
Bank card chỉ là disabled reference “Chưa hỗ trợ”; callback null, không gọi RPC. Không dùng “Bảo trì” hoặc “Miễn phí 24/7”. MoMo/Visa/MasterCard/VNPay không triển khai.
Các design bank/QR/verifying tiếp tục future-only; không có production wiring.

## 9. Validation

`flutter test --reporter expanded`: **538 passed, 0 failed** (suite cuối hoàn tất 01:18). Bao gồm **53 tests mới** (15 command + 38 UI) và các test hiện có. Lần chạy trước phát hiện timeout trong test harness route; đã sửa thứ tự pump/runAsync và chạy lại toàn bộ suite thành công.

Coverage mới: loading (không prepare trước getter), null, explicit prepare, pending cash, submitting/double tap, unchanged getter sau ack, timeout retry same operationId/payload, version conflict, definitive zero/eligibility errors, awaiting, paid chỉ từ getter, paid bank không thành cash paid, disabled bank không RPC, không customer-paid action, không fake recipient, stale/offline refresh, logout/user switch/A→B→A, request switch, history route ID, invalid route, realtime out-of-order, BigInt > 2^53, 320/390/480 với text scale 1 và 2.
15 command tests có HTTP mock cho RPC names/params, decimal bigint, stale replay, timeout và business/access errors. 32 GD4 tests cũ tiếp tục kiểm tra raw realtime không đáng tin, reconnect/resume/version guard/auth cleanup.
Các test dùng fake/HTTP mock; không gửi command vào database production.

`flutter analyze`: **0 error mới, 4 warning cũ**, exit code 1 vì warning. Giữ nguyên:
- login_screen.dart:73 — unused password.
- login_screen.dart:86 — unused response.
- login_screen.dart:507 — unused _NetworkChip.
- login_screen.dart:524 — unused _SocialBtn.

Không sửa warning unrelated. Format file thay đổi; git diff --check không có whitespace error trong file tracked sửa.

## 10. Security notes và remaining gaps

- Authorization cuối cùng vẫn do customer JWT + existing owner-only getter/RPC/RLS. Frontend không ghi payments trực tiếp, không gọi rescuer confirm.
- Production deployment/GD1–GD4 migrations/realtime publication không được thay đổi hoặc xác nhận live trong tác vụ này. Cần môi trường đã triển khai đúng backend contract.
- Chưa chạy end-to-end hai tài khoản customer/rescuer trên backend live hoặc thiết bị thật. Test xác minh contract bằng mock và logic watcher/UI hiện tại.
- Operation retry được giữ trong RAM của shared controller; không lưu bền sau process/tab restart. Sau khởi động lại phải đọc getter mới; backend version/idempotent state rules vẫn chống chọn lại tạo paid. Không tuyên bố operationId tồn tại qua restart.
- Recipient card chưa hiển thị vì chưa có verified rescuer data source. Không lấy customer contact thay thế.
- Cash paid chứng minh rescuer đã xác nhận nhận tiền trong contract hiện có, không khẳng định settlement kế toán.
- Pixel-level Flutter screenshot/golden comparison chưa thực hiện; responsive/interaction đã được widget-test theo kích thước và text scaling yêu cầu.
- Bank/QR/webhook/verifying bank chưa triển khai; chưa enable bất kỳ phương thức điện tử nào.

**Không sửa backend. Không migration. Không commit.**

