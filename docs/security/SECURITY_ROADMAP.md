# Roadmap triển khai bảo mật

> Đây là kế hoạch, chưa thay đổi code, migration hoặc Supabase. Thời lượng là ước lượng để sắp xếp nguồn lực, không thay thế đánh giá đội dự án. Mỗi đợt cần staging, reviewer độc lập và phương án rollback trước deploy.

## Ưu tiên 1 — Chốt trước phát hành / trước mở rộng người dùng

| Việc | Chủ trì đề xuất | Đầu ra và tiêu chí hoàn thành |
|---|---|---|
| Kiểm thử RLS toàn bộ bảng customer/rescuer/admin | Backend + QA | Ma trận JWT A/B, 5 admin roles; REST SELECT/INSERT/UPDATE/DELETE trái quyền đều bị chặn; lưu bằng chứng đã che PII. |
| Rà soát RPC trạng thái, quote và admin | Backend | Kiểm tra `auth.uid()`, owner, role, status, idempotency, race và `GRANT EXECUTE`; test mutation trái quyền không đổi dữ liệu. |
| Chặn lộ liên hệ/GPS trước khi nhận đơn | Backend + mobile + QA | Discovery, REST, Realtime, Storage chỉ trả dữ liệu tối thiểu; đối tác đã nhận mới lấy chi tiết cần thiết. |
| Xác minh Storage private và secret | Backend + DevOps | Bucket thật `public=false`; quét source/history/bundle/CI không có service role/token; rotate nếu phát hiện. |
| Kiểm tra admin matrix và audit | Backend + Admin Web | User thường không gọi admin RPC/view; role thấp không xem quote/doanh thu hoặc thao tác vượt quyền; mutation có audit nguyên tử. |
| Kiểm tra Realtime | Backend + QA | Publication chỉ gồm bảng cần thiết; JWT chéo không nhận payload nhạy cảm; blocked/demoted không nhận sau refresh. |

**Cổng phát hành:** mọi ca P0 trong [checklist](SECURITY_CHECKLIST.md) đạt PASS hoặc có quyết định rủi ro bằng văn bản của người chịu trách nhiệm. Không dùng việc ẩn UI làm bằng chứng đạt.

## Ưu tiên 2 — Hoàn thiện vận hành chuyên nghiệp

| Việc | Phụ thuộc | Đầu ra và tiêu chí hoàn thành |
|---|---|---|
| `account_status` cho customer và chặn tạo đơn | Quy trình khóa/mở của support/admin được phê duyệt | Migration mới, RPC gate trạng thái, audit thao tác và test blocked/restore; không sửa migration cũ. |
| Quyền tải ảnh/giấy tờ có kiểm soát | Ma trận owner/assignment/reviewer đã chốt | Policy hoặc RPC cấp signed URL TTL ngắn; test chéo role, audit giấy tờ, không public object. |
| Test SQL/tích hợp tự động cho RLS/RPC/Storage | Staging và fixture role | Chạy CI sau mỗi migration; race test claim/quote/cancel; lưu báo cáo kết quả. |
| Giới hạn spam tạo đơn/upload | Số liệu lưu lượng thực tế | Rate limit/quota theo tài khoản và IP; giám sát và cơ chế mở khóa khi chặn nhầm. |
| Tách báo giá và thực thu | Định nghĩa nghiệp vụ thanh toán/kế toán | Dữ liệu và quyền finance riêng, dashboard gắn nhãn đúng nguồn tiền, test role. |
| Tra cứu audit và cảnh báo admin | Quyền xem audit/retention đã duyệt | Giao diện audit role-gated; cảnh báo đăng nhập lạ và hành vi bất thường; không log secret. |
| Giữ/xóa dữ liệu nhạy cảm | Chính sách nội bộ được duyệt | Lịch retention cho GPS, ảnh, giấy tờ, audit và backup; quy trình xử lý yêu cầu dữ liệu. |

## Ưu tiên 3 — Tính năng nâng cao theo nhu cầu sản phẩm

- 2FA bắt buộc cho admin, quản lý thiết bị/phiên và quy trình thu hồi khẩn cấp.
- Number masking, chat trong app hoặc gọi qua số trung gian; thiết kế quyền riêng tư và lưu giữ trước khi phát triển.
- SOS, chia sẻ trạng thái đơn cho người thân bằng link có hạn và quyền thu hồi.
- Rate limit nâng cao, phát hiện bất thường và security dashboard.

Các tính năng ưu tiên 3 là **đề xuất**, không tự thêm vào sản phẩm khi chưa được phê duyệt.

## Trình tự thực thi mỗi hạng mục

1. Ghi hiện trạng và ca thất bại có thể tái hiện; chốt chủ sở hữu, tác động UX và dữ liệu.
2. Viết migration **mới**/thay đổi code riêng khi được yêu cầu; review SQL `SECURITY DEFINER`, `search_path`, grant, RLS và hiệu năng.
3. Chạy test tự động và thủ công với JWT nhiều vai trò trên staging; so sánh migration với Supabase runtime.
4. Lập kế hoạch deploy, backup, theo dõi, rollback/mitigation; xác minh sau deploy bằng smoke test trái quyền.
5. Cập nhật checklist, sổ rủi ro và tài liệu kiến trúc bằng bằng chứng mới.

## Thay đổi kỹ thuật có thể cần ở giai đoạn sau

- Migration mới cho `customer_profiles.account_status` và gate trong RPC tạo đơn, cùng audit khóa/mở.
- Migration mới cho policy Storage hoặc RPC cấp signed URL đúng owner/assignment/admin role; test URL hết hạn.
- Test suite SQL/RPC/Realtime và CI secret scan; xem xét projection sự kiện Realtime tối thiểu.
- Admin Web nối audit log và bổ sung kiểm tra quyền khi role/status thay đổi; rescuer app chọn `rescuer_code` trong profile snapshot.

Không phần nào ở trên đã được triển khai trong đợt viết tài liệu này.
