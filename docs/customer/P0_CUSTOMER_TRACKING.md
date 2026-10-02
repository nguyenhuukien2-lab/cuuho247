# P0 tracking — app khách hàng Cứu Hộ 24/7

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

## Contract và triển khai

Áp dụng migration theo thứ tự trên project dev:

1. `backend/supabase/migrations/202609300001_initial_customer_rescue.sql` nếu chưa có schema ban đầu.
2. `backend/supabase/migrations/202610010001_customer_tracking.sql` là migration nâng cấp mới.

Không chạy lại migration khởi tạo trên database đã có bốn bảng. File
`backend/supabase/tests/inspect_dev.sql` kiểm tra schema, quyền và publication trước/sau triển khai.
Migration mới chạy trong transaction, khóa bảng khi thay index; chuyển
`assisting` thành `in_progress`. Triển khai bản Flutter tương ứng cùng đợt vì
client cũ chưa hiểu `in_progress`.

Luồng trạng thái: `searching → accepted → arriving → in_progress → completed`.
Backend tin cậy có thể chuyển bất kỳ trạng thái active nào sang `cancelled`.
Trigger từ chối đi lùi, bỏ bước hoặc mở lại đơn đã kết thúc.
Khách chỉ hủy qua RPC khi đơn còn `searching` hoặc `accepted`, không có quyền
UPDATE trực tiếp hay RPC tự chuyển sang các trạng thái xử lý.

`request_status_events` lưu `request_id`, `previous_status`, `status`,
`occurred_at`, `is_initial_snapshot`. Trigger tự ghi sự kiện tạo đơn và mỗi
lần đổi trạng thái trong cùng transaction; sửa trường khác/retry không sinh
sự kiện lặp. Các đơn có trước migration chỉ được ghi snapshot trạng thái hiện
tại, không dựng lịch sử chưa từng lưu. RLS cho khách SELECT timeline của đơn
thuộc `auth.uid()`; không cấp INSERT/UPDATE/DELETE cho khách hoặc quyền đọc cho anon.
Timeline hiện là contract dữ liệu; UI vẫn dùng thanh tiến độ trạng thái.

`create_customer_rescue_request` giữ các tham số cũ và thêm:

| Tham số | Kiểu | Mặc định |
|---|---|---|
| `p_latitude` | double precision | null |
| `p_longitude` | double precision | null |

Cả hai null hoặc cùng có giá trị, latitude trong [-90, 90], longitude trong
[-180, 180]. Một tọa độ thiếu hoặc ngoài miền bị từ chối với `22023`.
Tra idempotency key trước validation: retry trả nguyên đơn cũ, kể cả đã kết
thúc hoặc tọa độ lần retry khác/không hợp lệ. Giữ unique key và unique index
một đơn active/khách, kể cả `in_progress`. Thay signature cũ bằng signature mới
có default, không giữ overload gây mơ hồ khi PostgREST nhận RPC.

Flutter `AppController.createRequest` và `SupabaseService.createRescueRequest`
nhận `latitude/longitude` nullable và gửi xuống RPC. Form nhập địa chỉ hiện
tại gửi null; chưa thêm GPS/map picker.

## Realtime

Migration thêm `rescue_requests` vào publication `supabase_realtime`; dùng
RLS SELECT chủ đơn hiện có. Flutter đăng ký UPDATE với bộ lọc đúng ID đơn đang
theo dõi, kiểm tra owner và cập nhật controller/UI. Mỗi lần subscribe/reconnect
thành công đều đọc lại snapshot để bù sự kiện mất khi ngắt mạng.

Hủy stream sẽ gọi `removeChannel`. Màn tracking hủy khi đổi tab trong
IndexedStack, bị route khác che, dispose, app ra nền, đổi tài khoản/logout hoặc
đơn kết thúc. Trở lại màn/app sẽ đăng ký lại. Phản hồi muộn của subscription
cũ, snapshot trước sự kiện mới và trạng thái có updated_at cũ đều bị bỏ qua.
Đơn completed/cancelled được chuyển vào lịch sử, bỏ khỏi active request.
Lỗi kết nối có thông báo và nút kết nối lại; vẫn có nút cập nhật thủ công.

Theo [tài liệu Supabase Postgres Changes](https://supabase.com/docs/guides/realtime/postgres-changes),
bảng cần nằm trong publication và quyền đọc được kiểm tra qua RLS.

## Test thủ công trên dev

1. Áp migration, điền URL/publishable key trong `frontend/customer_app/config/supabase.dev.json`.
   Chạy `flutter run -d chrome --dart-define-from-file=config/supabase.dev.json`.
2. Đăng nhập A, tạo đơn và mở tab Đang xử lý; lấy UUID từ mã đơn.
3. Trong SQL Editor của project dev (role postgres), mở
   `backend/supabase/tests/dev_advance_request.sql`, thay placeholder bằng UUID đơn này.
   Chạy một lần rồi quan sát UI, lặp lại để lần lượt thấy accepted, arriving,
   in_progress, completed. Không cần bấm Cập nhật. Đơn cuối xuất hiện ở Lịch sử.
4. Đọc timeline trên SQL Editor để đối chiếu:

   ```sql
   select previous_status, status, occurred_at, is_initial_snapshot
   from public.request_status_events
   where request_id = 'UUID_DON_DEV'
   order by occurred_at, id;
   ```

5. Tạo đơn khác và hủy bằng app: đúng một sự kiện cancelled. Khi tới arriving,
   nút hủy không còn và gọi RPC hủy trực tiếp phải bị từ chối.
6. Chuyển tab/rời route/đưa app ra nền, cập nhật trạng thái bằng SQL rồi trở lại:
   UI tải trạng thái mới. Thử ngắt/bật mạng; UI cần đồng bộ sau reconnect.
7. Đăng xuất, đăng nhập B: không còn dữ liệu/subscription của A. Dùng JWT của B
   đọc request và timeline A qua Data API phải nhận mảng rỗng. Khách gọi PATCH
   trạng thái hoặc INSERT/UPDATE/DELETE timeline phải bị từ chối.
   SQL Editor role postgres không phải phép kiểm tra RLS của khách.
8. Trong DevTools → Network → WebSocket, xác nhận `phx_leave` khi rời tracking
   hoặc logout và kênh mới khi quay lại. Không dùng số kết nối WebSocket làm
   số subscription, vì Supabase có thể dùng chung một socket.

Script API mở rộng kiểm tra tọa độ, idempotency trước validation, timeline/RLS
A-B/anon, cấm ghi timeline, null/omitted coordinates và gửi đồng thời:

```powershell
dart run tool/verify_backend.dart --verify-dev PROJECT_REF_DEV
```

Cần hai tài khoản test mới trong `frontend/customer_app/config/backend-tests.dev.json` theo file
example. Script tạo/hủy đơn test và giữ lịch sử để đối chiếu; không cập nhật
trạng thái thay hệ thống. SQL dev chỉ dành cho việc quan sát lifecycle/Realtime,
không được đưa khóa quản trị vào Flutter.

## Các file thay đổi

- Backend: migration mới, `backend/supabase/tests/dev_advance_request.sql`,
  `backend/supabase/tests/inspect_dev.sql`.
- Flutter: `frontend/customer_app/lib/services/supabase_service.dart`, `frontend/customer_app/lib/app/app_controller.dart`,
  `frontend/customer_app/lib/screens/new_tracking_screen.dart`, `frontend/customer_app/lib/app/app_shell.dart`,
  `frontend/customer_app/lib/app/navigation.dart` (mới), `frontend/customer_app/lib/main.dart`, `frontend/customer_app/lib/widgets/rescue_widgets.dart`.
- Kiểm thử: `frontend/customer_app/test/tracking_test.dart` (mới), `frontend/customer_app/test/request_failure_test.dart`,
  `frontend/customer_app/tool/verify_backend.dart`.
- Tài liệu: file này và `SUPABASE_SETUP.md`.

Không bổ sung ứng dụng người cứu hộ, admin hay thanh toán. Chuyển trạng thái
thực tế vẫn cần bên vận hành/hệ thống tin cậy; SQL dev chỉ mô phỏng phần đó.

## Kết quả kiểm tra trong workspace (01/10/2026)

- `flutter test`: **12/12 đạt**. Kiểm tra mapping sáu trạng thái/tọa độ,
  cập nhật UI từ stream giả lập, bỏ bản cũ/đơn khác, chuyển lịch sử,
  đổi đơn, đổi tab, logout, route/dispose, background/resume và kết nối lại.
- `flutter analyze`: **exit code 1**, không có error; còn **4 warning và
  46 info** từ code có sẵn (unused trong màn login cũ và withOpacity deprecated).
  Không sửa lan sang các màn ngoài phạm vi chỉ để làm sạch thông báo.
- Migration được rà soát trong source, **chưa áp lên Supabase**.
  Chưa chạy `frontend/customer_app/tool/verify_backend.dart` hoặc kiểm thử WebSocket với server thật:
  workspace có URL/publishable key nhưng chưa có
  `frontend/customer_app/config/backend-tests.dev.json` với hai tài khoản test, cũng chưa có kết nối
  quản trị database để áp migration. Test stream giả lập không chứng minh RLS,
  publication hay truyền sự kiện thực tế trên project.
