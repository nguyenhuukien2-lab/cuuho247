# Cứu Hộ 24/7 Admin Web

React, Vite, TypeScript, React Router, Lucide và Recharts. Admin dùng Supabase Auth, các admin view/RPC và cập nhật Realtime; tài khoản phải có quyền quản trị.

## Chạy cục bộ

Từ thư mục `admin_web`:

```sh
npm install
npm run dev
npm run build
npm run lint
npm run test:e2e
```

Cấu hình `VITE_SUPABASE_URL` và `VITE_SUPABASE_ANON_KEY` trong `.env` cục bộ. Không đưa service-role key vào trình duyệt. Route `/login` dùng xác thực thật; trang `/` là dashboard.

## Thiết kế Stitch

Tham chiếu [CuuHo 247 Admin Dashboard](https://stitch.withgoogle.com/projects/4094609055269816912), đọc qua Stitch MCP. Chi tiết ánh xạ và phạm vi trong [ghi chú thiết kế](STITCH_REDESIGN.md).

Giao diện dùng sidebar xanh đậm, nền tím nhạt, thẻ thống kê, bảng và bộ lọc chung. Font Inter, Plus Jakarta Sans và logo được phục vụ từ `public/`; giấy phép font đi kèm tài nguyên. Hỗ trợ desktop, tablet, mobile, phím Ctrl/Cmd+K để tìm yêu cầu và Escape để đóng menu.

Dashboard tổng hợp biểu đồ 7/14 ngày từ toàn bộ danh sách yêu cầu, theo múi giờ Việt Nam; biểu đồ trạng thái và dịch vụ dùng dữ liệu thực đã tải. Doanh thu hiển thị là giá trị báo giá, chưa phải thực thu. Dữ liệu chưa có và dữ liệu lỗi có trạng thái riêng.

Các luồng hủy yêu cầu, duyệt/khóa đối tác, bật/tắt dịch vụ giữ RPC và xác nhận hiện có. Bản đồ GPS, thông báo, cấu hình và các thao tác chưa có API tiếp tục hiển thị trạng thái chưa hỗ trợ.

## Kiểm thử

Playwright chạy Edge headless, giả lập Supabase Auth, REST/RPC và WebSocket; không gửi thao tác thử vào backend thật. Bộ kiểm thử bao gồm quyền truy cập, hủy yêu cầu, bật/tắt dịch vụ, tổng hợp ngày theo giờ Việt Nam, hiển thị lỗi/quyền tài chính, menu bàn phím và responsive. Ảnh dashboard được lưu trong `test-results/stitch-dashboard-desktop.png` và `test-results/stitch-dashboard-mobile.png` khi chạy toàn bộ bộ kiểm thử.
