# Admin redesign — Stitch

Nguồn: [CuuHo 247 Admin Dashboard](https://stitch.withgoogle.com/projects/4094609055269816912), project `4094609055269816912`, đọc qua Stitch MCP ngày 12/10/2026.

## Các màn hình đã đối chiếu

| Mẫu Stitch | Screen ID | Route |
| --- | --- | --- |
| Tổng quan hệ thống | 17247f429535447382eb27095ad2fbe0 | / |
| Quản lý yêu cầu cứu hộ | 1a7d91db4dc94dc78b7e28620c48aa93 | /requests |
| Chi tiết yêu cầu cứu hộ | fd6dda3900694a26a3d7e9789584892a | /requests/:id |
| Quản lý Khách hàng | 60f3f53c310c4863ad6ac72d235e3e9b | /customers |
| Quản lý Đối tác cứu hộ | 7582dd58960e462da5e524c2dfba9584 | /rescuers |
| Quản lý Dịch vụ | ca820000a21f456ca6d8015922323b7c | /services |
| Báo giá & Doanh thu | 0229dfc1e2c841a18c8f6f0e87ce3b05 | /quotes |
| Đánh giá dịch vụ | ac42ce82aa4a44e3ac61a08d8e563cda | /reviews |
| Bản đồ hoạt động | 5959518b6294440299005dec824d0390 | /map |
| Cài đặt hệ thống | 92542162bb334cc087cec7b061d5d06d | /settings |
| Logo Cứu Hộ 24/7 | dfd093571bf4455aa391efb48a66f984 | public/cuuho-logo.svg |

## Áp dụng

- Nền `#faf8ff`, sidebar `#283044`, màu chính `#1d4ed8`, bề mặt trắng; tiêu đề Plus Jakarta Sans và nội dung Inter.
- Dashboard được bố trí lại thành 8 KPI, biểu đồ yêu cầu, phân bổ trạng thái/dịch vụ, bảng 5 ca mới nhất, tình hình điều hành và liên kết bản đồ.
- Sidebar, thanh công cụ, thẻ, bảng, bộ lọc, hồ sơ, dịch vụ, đánh giá, thông báo trạng thái và responsive được áp dụng chung bằng `src/styles/stitch-admin.css`.
- Dùng dữ liệu Supabase hiện có. Không sao chép số liệu mẫu, phần trăm tăng trưởng, GPS hay sự kiện giả trong HTML Stitch.
- Thống kê và biểu đồ phân biệt 0, dữ liệu chưa có, lỗi tải và quyền xem tài chính. Biểu đồ gom thời gian tạo yêu cầu theo Asia/Ho_Chi_Minh.
- Giữ xác thực, phân quyền, RPC và luồng xác nhận. Các chức năng chưa có backend vẫn chưa được kích hoạt.
- Menu mobile có quản lý focus, Escape, Tab và khóa cuộn nền. Bảng rộng cuộn trong vùng bảng. Biểu đồ có bảng dữ liệu dành cho trình đọc màn hình.

## Xác minh

Build TypeScript/Vite, lint và Playwright. Kiểm thử mock Supabase, bao gồm các luồng hiện có, ngày giáp ranh UTC/Việt Nam, 7/14 ngày, phân loại trạng thái lạ, lỗi danh sách, quyền xem báo giá, điều hướng bàn phím và 14 route ở 390/768/1440px. Ảnh chụp desktop/mobile dùng dữ liệu giả lập của test, không phải dữ liệu sản xuất.
