# XyRDP-VN — Windows RDP qua hypertunnel

Workflow tạo phiên Windows tạm trên GitHub Actions và công bố cổng TCP để kết nối bằng ứng dụng Remote Desktop.

> **Cảnh báo bảo mật:** hypertunnel dùng relay TCP công khai. Endpoint không phải lớp xác thực bổ sung; ai biết endpoint có thể thử kết nối tới RDP. Dùng mật khẩu mạnh, không chia sẻ endpoint, và chỉ chạy trong môi trường/tài khoản mà bạn được phép quản trị. Hypertunnel là dự án cũ; relay công cộng mặc định có thể ngừng hoạt động hoặc không ổn định.

## Cấu hình bắt buộc

Trong repository GitHub, mở **Settings → Secrets and variables → Actions → New repository secret** và tạo:

- `RDP_PASSWORD`: mật khẩu Windows dài, mạnh (ít nhất 16 ký tự, có chữ hoa/thường, số và ký tự đặc biệt). Không đặt mật khẩu trực tiếp trong YAML.

Không cần `FRP_TOKEN`, `FRP_SERVER` hay `FRP_REMOTE_PORT` cho workflow này.

## Chạy workflow

1. Vào **Actions → XyRDP-VN — RDP 6 giờ**.
2. Nhấn **Run workflow**.
3. Chọn thời gian 10–360 phút và tên tài khoản (mặc định `xyadmin`).
4. Đợi bước **Khởi chạy hypertunnel** báo endpoint dạng `hypertunnel.ga:19432`.
5. Trên Windows mở `mstsc`; nhập `hypertunnel.ga:19432` vào ô Computer. Trên điện thoại, dùng ứng dụng Remote Desktop hỗ trợ địa chỉ `host:port`.
6. Đăng nhập bằng username đã chọn và giá trị của secret `RDP_PASSWORD`.
7. Nếu cần xem lại thông tin, tải artifact `xyrdp-connection-details` trong run tương ứng.

## Những điểm cần biết

- Đây là GitHub-hosted runner tạm thời, tối đa khoảng 6 giờ theo workflow; không phải VM chạy 24/7.
- `npx hypertunnel` tạo TCP relay đến cổng RDP 3389. Nó không tạo địa chỉ cố định; host/port được cấp có thể thay đổi mỗi lần chạy.
- Nếu bước tunnel không tìm thấy endpoint, xem log của bước **Khởi chạy hypertunnel**. Relay công cộng mặc định có thể không khả dụng.
- RDP chỉ hoạt động nếu Windows runner có RDP listener đang lắng nghe trên cổng 3389.
- Không dùng máy này để lưu dữ liệu nhạy cảm hoặc làm máy chủ sản xuất.

## Cấu trúc

- `.github/workflows/xyrdp-vn.yml` — workflow RDP + hypertunnel.
- `scripts/cai-rdp-co-ban.ps1` — tạo tài khoản Windows và bật RDP.
- `scripts/` — các script hỗ trợ từ bản XyRDP-VN gốc.
- `railway-frp/` — cấu hình FRP cũ, không còn được workflow này sử dụng.
