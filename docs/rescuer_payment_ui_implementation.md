# Rescuer payment UI implementation

Ngày thực hiện: 2026-10-12. Phạm vi: `frontend/rescuer_app`.

## Tiếp nối hiện trạng và Stitch

Đã inspect git status/diff và source hiện tại trước khi sửa. Giữ lại controller,
service, DTO, payment watcher, màn thu tiền, token UI và navigation năm tab đã có.
Không revert/rewrite phần công việc trước đó. Bảng dưới ánh xạ bộ mười trạng thái
UI được bàn giao; chín screen ID có trong yêu cầu hiện tại. Bản bàn giao nói đã
đọc đủ mười màn ở lượt trước nhưng không cung cấp ID/tên chính xác màn thứ mười;
không tự bịa ID hoặc tuyên bố đã kiểm tra lại screenshot của màn đó.

| Màn / trạng thái | Stitch ID | Áp dụng |
| --- | --- | --- |
| Thu tiền mặt — Chờ thu | `46738874d376427a9bf06d4bab8400d7` | Cash awaiting, số tiền cố định, CTA |
| Dialog xác nhận | `ea4b202d510f4834884e0002688a0909` | Snapshot amount/version, xác nhận/hủy |
| Đang xác nhận | `ae73279440ec43b483e10c7f98b551bc` | Loading, khóa thao tác/back |
| Đã nhận tiền mặt | `bbd7e314d223459485f7835b85f98240` | Success chỉ từ getter paid |
| Lịch sử — Đối soát thanh toán | `ff46247a12624a77a8d8167a4132e707` | Payment summary từng chuyến và detail |
| Bank awaiting | `95e534143cae4e1fbffd66e4dd7602a7` | Chỉ xem, chờ hệ thống xác minh |
| Bank verifying | `1932ab33cc054437baba5608f98695a1` | Chỉ xem, đang xác minh |
| Bank paid | `0bc7b6a320e747c09fe10984321ffc56` | Chỉ xem biên lai backend |
| Không thể cập nhật trạng thái | `5981118209ac4343b2f5678066078c67` | Lỗi mạng/API, Thử lại bằng getter |
| Màn thứ mười trong bàn giao: chưa có định danh để đối chiếu | Chưa có trong yêu cầu/source tài liệu | Giữ UI tổng quan/phương thức có sẵn (`payment-method`), không tạo state mẫu |

## Files changed trong lượt tiếp tục

Các đường dẫn dưới tương đối với `frontend/rescuer_app/`:

- `lib/app/cash_payment_controller.dart`: refetch sau lỗi/conflict; eligibility dựa
  trên payment thật, không phụ thuộc snapshot trạng thái job cũ trên màn hình.
- `lib/app/payment_watcher.dart`: getter version cũ không xác thực snapshot paid
  đang cache; giữ dữ liệu mới nhưng đánh dấu lỗi/stale và đọc lại có giới hạn.
- `lib/app/rescuer_controller.dart`: refresh active/payment, history resume,
  tái sử dụng subscription khi mở cùng history job; chuyển tab không gây đua
  giữa tải history list và tải detail khi quay từ biên lai.
- `lib/app/history_payment_controller.dart`: giữ triển khai đã có, thêm guard
  cho getter version cũ để summary không tin cached paid khi refetch stale.
- `lib/screens/payment/job_payment_section.dart`: summary dùng chung mới.
- `lib/screens/payment/rescuer_cash_screen.dart`: tái sử dụng màn Stitch; không
  hiện success từ cached paid khi getter lỗi/đang tải; chống trả lời dialog hai
  lần; reset vị trí cuộn khi chuyển loading/success/error để trạng thái dễ thấy.
- `lib/screens/payment/rescuer_payment_widgets.dart`: giữ widgets đã có, format.
- `lib/screens/preparation/active_job_panel.dart`: timeline → chi phí → payment.
- `lib/screens/preparation/history_panel.dart`: summary từng job và trong detail.
- `test/cash_payment_test.dart`: cập nhật assertion theo dialog/loading Stitch,
  scroll trên màn hẹp và text scale lớn, giữ kiểm tra security/idempotency.
- `test/payment_integration_test.dart`: bổ sung test flow active/history/bank,
  authoritative getter, conflict, stale, error/retry và lifecycle.
- Tài liệu này: `docs/rescuer_payment_ui_implementation.md`.

`lib/services/payment_service.dart`, `lib/models/payment_dto.dart`, service wiring,
navigation năm tab và các thay đổi trước đó được dùng lại. Những thay đổi customer,
backend/migration đã tồn tại trong worktree trước lượt này được giữ nguyên.

## Active Job integration

Payment summary nằm sau timeline và bảng kê chi phí. Summary hiển thị amount,
currency, phương thức, trạng thái và payment code từ DTO backend. Không lấy quote
để dựng payment giả khi getter không có payment.

Cash awaiting có CTA dẫn đến màn thu tiền hiện có; tại đó người dùng xem lại số
tiền, mở dialog và xác nhận. Màn payment sở hữu watcher/controller riêng, nên
chuyển lựa chọn trong History không đổi payment của dialog đang mở.

Backend hiện chỉ tạo payment theo completion snapshot và chỉ cho confirm khi
request/assignment completed. Nếu Active Job còn snapshot cũ nhưng getter đã có
cash awaiting, UI vẫn cho gửi RPC; backend xác thực trạng thái hoàn tất thực tế.
Không mở rộng quyền backend để thu tiền trước completion. Test active sử dụng
fixture có payment để kiểm chứng wiring và UI, không chứng minh backend cho phép
thu cash cho một request thực sự chưa completed.

## Completed / History cash flow

Completion giữ hành vi hiện tại: xóa active job, chuyển tab History, tải lịch sử
và đọc lại payment. Không đưa completed job trở lại Active Job.

History load đọc summary bằng `HistoryPaymentController` (tối đa bốn getter đồng
thời, có user/generation/revision guard). Mở detail gọi getter theo request đúng
assignment; danh sách và detail đều mở được màn payment. Cash awaiting vẫn xác
nhận được dù `activeJob == null`, offline đối với discovery hoặc GPS không sẵn
sàng; vẫn cần kết nối backend để xác nhận.

Cash paid chỉ xem. Bank awaiting/verifying/paid chỉ xem. Không payment thì hiển
thị chưa có thông tin, không sinh amount/status/payment code. Khi rời màn payment,
summary lịch sử và watcher đang chọn được refetch.

## Cash RPC và authoritative refetch

1. Getter `rescuer_get_job_payment(p_request_id)` trả DTO có quyền truy cập.
2. CTA mở dialog; amount/version/payment ID là snapshot bất biến đã xem.
3. Khóa double tap, dialog response, back/navigation trong lúc đang gửi.
4. Gọi `rescuer_confirm_cash_received` qua Supabase client đăng nhập với
   request ID, payment ID, amount_expected, expected version và operation UUID.
5. Bỏ qua payload settlement của command; gọi lại getter.
6. Chỉ DTO getter trả `paid` hợp lệ mới hiện success. Getter lỗi hoặc vẫn
   awaiting không được xem là thành công.
7. Version conflict/already settled/state conflict, lỗi mạng hoặc timeout đều
   refetch để hòa giải kết quả. Nếu getter thấy paid thì hiển thị paid; nếu không
   thì hiển thị lỗi an toàn. Retry chỉ đọc, không tự gửi lại command.

Operation UUID/payload được giữ cho kết quả chưa chắc chắn; thao tác ghi tiếp
theo cần người dùng xác nhận lại. Không gán paid local, không chỉnh amount,
actor, timestamp hoặc status từ UI.

## Bank, refresh và lỗi

Bank hoàn toàn chỉ đọc DTO từ `rescuer_get_job_payment`. Không có confirm bank,
mark paid, RPC bank mới, provider/webhook giả hay action “đã nhận chuyển khoản”.
Provider thật vẫn BLOCKED theo trạng thái bàn giao; UI không tự chuyển bank paid.

Getter được gọi khi mở Active Job, manual refresh, completion thành công, mở
history detail, trở lại từ cash screen, sau cash command, retry và app resume.
Realtime chỉ báo invalidation; trạng thái vẫn lấy lại bằng getter. Watcher gộp
refresh đang chạy, giữ một subscription trong scope, bỏ response user/request cũ,
và dừng retry khi background/dispose. History chỉ mở realtime cho payment đang
được chọn; summary list dùng các getter giới hạn concurrency.

Lỗi mạng/API hiển thị “Không thể cập nhật trạng thái” và “Thử lại”; không đổi
payment sang failed. Không hiển thị raw backend exception. Lỗi quyền/không có
payment hiển thị chưa có thông tin. Cached paid không hiện success khi refresh
lỗi hoặc getter trả version cũ. Status failed chỉ xuất hiện nếu DTO thật là failed.

## Security

Amount chỉ hiển thị; không TextField, tip, partial amount hay override. BigInt và
version được truyền bằng decimal string. Backend xác thực ownership, approval,
completed snapshot, amount/version và idempotency. User JWT được dùng cho RPC;
không service-role key trong UI. Auth change/logout xóa scope; phản hồi trễ không
khôi phục dữ liệu user cũ. Bank không đi vào nhánh `CashPaymentCommands`.

## Tests và analyze

Thực thi trong `frontend/rescuer_app`:

```text
flutter test
flutter analyze
```

Kết quả cuối ngày 2026-10-12:

- `flutter test`: **203 PASS, 0 FAIL**, exit code 0.
- `flutter analyze`: **No issues found**, 0 errors, 0 warnings, 0 infos,
  exit code 0. Hai lint braces trong màn payment đã được sửa; không sửa warning
  unrelated hoặc nâng package để xử lý thông báo có phiên bản mới.
- `git diff --check -- frontend/rescuer_app docs/rescuer_payment_ui_implementation.md`:
  exit code 0, không lỗi whitespace. Các thông báo LF/CRLF là cấu hình Git.

Coverage payment gồm: active cash awaiting/dialog/loading/double tap/RPC success
và error; getter chứng minh paid; không CTA sau paid; completed History không có
active job vẫn thu được cash; history cash paid và cả ba trạng thái bank chỉ xem;
không bank mutation; network/retry/stale snapshot; no payment; amount không editable;
getter sau refresh/completion/resume; auth isolation và idempotency.

Các test transport dùng Supabase HTTP mock kiểm đúng tên RPC/JWT/payload; widget
và controller dùng fake backend fixtures trong thư mục test. Không thực hiện
thu tiền thật hoặc xác minh live database trong lượt này. Full suite còn bao gồm
login/onboarding, service/vehicle capability, GPS, online/offline, discovery,
nhận đơn/progress/quote/completion/history/account và navigation năm tab.

## Backend changes và limitations

- Không sửa/thêm migration trong lượt này; dùng RPC cash/getter hiện có.
- Không sửa customer app, Admin UI, provider bank hoặc webhook.
- Chưa chạy giao dịch end-to-end trên backend production; backend đích cần có
  migrations và quyền RPC/realtime đã được cấu hình từ các bước trước.
- Thiếu định danh màn Stitch thứ mười trong bản bàn giao hiện tại; bảng đã ghi
  rõ giới hạn truy vết, không suy đoán một ID mới.
- Không deploy. Không commit.
