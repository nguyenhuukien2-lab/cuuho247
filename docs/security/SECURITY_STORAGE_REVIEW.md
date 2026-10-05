# Rà soát Supabase Storage

> Đối chiếu migration trong `backend/supabase/migrations`. Bucket/policy trên môi trường Supabase thật có thể khác mã nguồn; phải xác minh trực tiếp trước phát hành.

## 1. Ảnh sự cố

- Bucket thực tế: `rescue-request-photos`, khai báo **private**. Metadata nằm ở `rescue_request_photos` (không phải `request_photos`). Giới hạn trong migration: JPEG/PNG/WebP, 5 MB, tối đa ba vị trí ảnh trên một đơn.
- Policy `storage.objects` hiện cho khách là chủ đơn đọc/upload trong đường dẫn được kiểm soát; metadata chỉ chủ đơn SELECT. Không có policy tải ảnh dành cho đối tác sau khi nhận hoặc admin trong migration đã đọc. Đây là **khoảng trống chức năng/quyền truy cập**, cần thiết kế riêng trước khi mở; không phải bằng chứng bucket đang public.
- Customer app tạo signed URL thời hạn 600 giây trong `request_photo_service.dart`. URL đã ký là bearer capability: không gửi vào log, analytics, clipboard hoặc thông báo; hết hạn thì cấp lại sau khi xác thực.
- Mục tiêu: khách chỉ xem/upload ảnh đơn của mình; đối tác đã nhận đơn mới xem ảnh cần cho công việc; admin có vai trò điều phối phù hợp mới xem. Kiểm tra cả metadata lẫn object path/bucket, không chỉ ẩn nút UI.

## 2. Giấy tờ đối tác

- Bucket thực tế: `rescuer-documents`, khai báo **private**; JPEG/PNG/PDF, tối đa 10 MB. Đối tác chỉ đọc/upload object của mình qua policy hiện có.
- `admin_rescuer_documents_view` cho `super_admin`/`partner_reviewer` xem **metadata**; migration chưa cấp lối tải object cho hai vai trò này. Cần luồng cấp signed URL ngắn hạn sau khi kiểm tra role và ghi audit nếu nghiệp vụ duyệt đòi hỏi xem file.
- Không dùng public URL, không mở bucket cho toàn bộ `authenticated`. Với giấy tờ thay thế/thu hồi, cần bảo đảm object cũ không tiếp tục có link vô thời hạn.

## 3. Avatar/profile nếu bổ sung

Chưa xác nhận bucket avatar riêng trong các migration đã rà soát. Nếu thêm, phải xác định trước public hay private theo loại ảnh; avatar công khai và giấy tờ pháp lý phải tách bucket/policy, đặt giới hạn MIME/size/path và kiểm tra quyền cập nhật.

## 4. Thiết kế truy cập đề xuất

| Tài nguyên | Trước nhận đơn | Sau nhận đơn | Sau hoàn tất |
|---|---|---|---|
| Ảnh sự cố | Khách chủ đơn; admin điều phối có quyền | Thêm đúng đối tác được phân công | Chỉ các bên cần xử lý lịch sử/khiếu nại, theo thời hạn giữ dữ liệu |
| Giấy tờ đối tác | Chủ hồ sơ; reviewer/super_admin khi có nghiệp vụ duyệt | Không phụ thuộc trạng thái đơn | Quyền review theo vai trò, thu hồi khi hết nhu cầu |

Ưu tiên policy `storage.objects` gắn path với bảng metadata và quyền ở DB; nếu dùng RPC cấp signed URL thì xác thực lại owner/assignment/admin role ngay lúc cấp, TTL ngắn, ghi audit cho truy cập giấy tờ. Kiểm tra quyền trên mỗi lần cấp URL, đồng thời hiểu rằng URL đã ký có thể còn dùng đến hết TTL sau khi thu hồi quyền.

## 5. Checklist kiểm thử

- [ ] Trên môi trường thật, cả hai bucket đều `public=false`; anonymous/public URL không tải được object.
- [ ] Customer A không đọc/upload/xóa ảnh đơn B; path giả/đổi UUID không vượt policy.
- [ ] Đối tác chưa nhận đơn không tải được ảnh; đối tác đã nhận chỉ tải ảnh đơn được giao khi luồng này được triển khai.
- [ ] Partner reviewer xem metadata theo quyền; chỉ tải giấy tờ sau khi có luồng kiểm tra quyền; finance/support không tải được.
- [ ] Đối tác A không đọc/upload giấy tờ B; object sai MIME/size/path bị chặn.
- [ ] Signed URL hết hạn đúng; sau thu hồi quyền không cấp được URL mới; không log URL đã ký.
- [ ] Metadata và object được dọn theo chính sách lưu giữ, tránh object mồ côi; test cả phiên đăng nhập cũ sau khi đổi role.

## Việc cần triển khai sau

Thiết kế policy hoặc RPC cấp signed URL cho đối tác đã nhận đơn và admin reviewer/operator, kèm test chéo tài khoản; chưa sửa migration/policy trong giai đoạn này.
