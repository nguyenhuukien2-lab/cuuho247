# Ưu tiên xử lý sau kiểm thử bảo mật

> Tài liệu này dùng để xếp việc sau khi có kết quả test; chưa sửa code, migration hoặc database. “Lỗ hổng xác nhận” chỉ ghi khi đã tái hiện trên môi trường triển khai với fixture hợp lệ. Mọi sửa DB về sau dùng migration **mới** và có rollback plan.

## P0 — Chặn phát hành nếu xác nhận

| Kết quả test | Hành động khi FAIL | Điều kiện đóng |
|---|---|---|
| CUS: A đọc được dữ liệu B | Khoanh đường REST/RPC/Realtime, tạm tắt đường truy cập lỗi nếu cần; sửa RLS/GRANT hoặc projection | JWT A/B âm tính cho mọi đường, B vẫn tự đọc được; log đánh giá phạm vi ảnh hưởng. |
| PRE: đối tác chưa nhận thấy phone/GPS chính xác | Giảm projection discovery, rà direct table/view và payload Realtime | Trước claim chỉ còn dữ liệu tối thiểu; sau claim đúng đối tác mới thấy chi tiết cần thiết. |
| ADM: user thường gọi RPC/view admin | Kiểm tra gate `auth.uid()`/role/status, `EXECUTE`, SECURITY DEFINER và grants | Gọi trực tiếp bằng JWT thường bị từ chối trước mutation; audit không có hành động giả. |
| ROLE: finance/operator/support/reviewer vượt quyền | Sửa gate từng RPC/view, tách dữ liệu quote/doanh thu | Ma trận role PASS với cả URL/RPC trực tiếp, không chỉ UI. |
| STO: bucket public hoặc tải chéo | Khóa public access, kiểm tra object policy/signed URL, đánh giá link đã phát | Anonymous/cross-user không tải được; chủ hợp lệ vẫn tải được. |
| RT: event nhạy cảm tới JWT sai | Thu hẹp publication/row policy/projection, ngắt kênh không an toàn | JWT A/B và role thấp không nhận payload; test cả reconnect/JWT cũ. |
| SEC-005: lộ giá trị service role/token thật | Thu hồi/rotate ngay, rà log/history/artifact, điều tra phạm vi | Secret cũ vô hiệu, bundle mới sạch, quyền được giảm. |

Thứ tự trong P0: chặn đường lộ dữ liệu đang hoạt động trước, rồi phân tích và sửa gốc; phối hợp chủ hệ thống để tránh phá luồng cứu hộ. Rủi ro chưa tái hiện vẫn cần test, không tự đánh dấu “an toàn”.

## P1 — Khoảng trống đã thấy hoặc cần hoàn thiện vận hành

| Hạng mục | Lý do | Đề xuất đợt sau / tiêu chí |
|---|---|---|
| Khóa customer | Chưa có `account_status`/gate tạo đơn theo tài liệu hiện trạng | Migration mới thêm trạng thái và RPC kiểm tra; test blocked/restore, audit. |
| Quyền xem ảnh sau claim | Bucket ảnh hiện owner-only | Thiết kế policy hoặc signed URL cấp đúng assignment/admin role, TTL ngắn; test trước/sau claim. |
| Quyền xem giấy tờ cho reviewer | View admin chỉ có metadata, Storage owner-only | Gateway cấp URL sau role check, audit truy cập; không public bucket. |
| Test SQL/JWT trong CI | Test thủ công dễ bỏ sót sau migration | Fixture giả cho CA/CB/RA/RB/5 role; chạy negative tests sau mỗi deploy. |
| Audit UI và quyền đọc log | BE có log, UI chưa nối; tất cả admin active có thể đọc log | Nối UI có role gate, cân nhắc lọc metadata/retention, test giả mạo log. |
| Spam và tranh chấp quote | Chưa xác nhận giới hạn tạo đơn theo giờ; giá cần bất biến sau chốt | Rate limit đo theo lưu lượng; race/idempotency/quote revision tests. |

## P2 — Nâng cấp khi sản phẩm yêu cầu

2FA admin, quản lý phiên/thiết bị, cảnh báo bất thường, number masking, chat/SOS/share request và dashboard bảo mật. Đây là đề xuất về sau, không tự triển khai trong đợt tạo test.

## Quy tắc chuyển từ FAIL sang CLOSED

1. Ghi ticket kèm ID ca, môi trường, persona, fixture tồn tại, bằng chứng đã che PII và mức ảnh hưởng.
2. Thiết kế thay đổi nhỏ nhất; review RLS/RPC/Storage/Realtime, hiệu năng và tương thích app. Migration mới, không sửa migration cũ.
3. Chạy lại ca thất bại và ca liên quan trên staging bằng JWT thật; kiểm tra UI khách/đối tác/admin không hỏng.
4. Deploy có backup, theo dõi và phương án khôi phục; kiểm tra lại trên môi trường đích bằng dữ liệu test được phép.
5. Cập nhật [sổ rủi ro](SECURITY_RISKS.md), [checklist](SECURITY_CHECKLIST.md) và quyết định phát hành.
