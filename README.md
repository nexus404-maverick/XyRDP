# XyRDP-VN — RDP Miễn Phí qua Trình Duyệt (không cần Tailscale)

**Xem màn hình Windows bằng trình duyệt** · Không cần cài app RDP · Không dùng Tailscale

Dashboard / hướng dẫn: xem file này.  
Tín dụng gốc: KallAncrit (RdpFree) · Bản Việt hóa & viết lại: XyRDP-VN

---

## Điểm khác so với bản gốc

| Bản gốc (RdpFree) | Bản này (XyRDP-VN) |
|---|---|
| Tailscale (mạng riêng) | **FRP công khai** (IP + port mở ra ngoài) |
| Client RDP (mstsc / XyDesk) | **noVNC** — mở bằng Chrome/Firefox/Safari |
| Giao diện tiếng Indonesia | **Tiếng Việt 100%** |
| Chỉ cổng 3389 | Cổng VNC 5900 + noVNC web 6080 (qua FRP) |

Bạn chỉ cần mở link dạng `http://xxxx.proxy.rlwy.net:xxxxx` trên trình duyệt là xem và điều khiển được màn hình Windows.

---

## Kiến trúc

```
Điện thoại / Máy tính
        │  (trình duyệt)
        ▼
  http://PUBLIC_HOST:PUBLIC_PORT   ←  FRP TCP Proxy (Railway / VPS)
        │
        ▼
  frps (server FRP bạn tự deploy)
        │
        ▼
  frpc (chạy trong GitHub Actions runner)
        │
        ▼
  noVNC (port 6080)  ←→  TightVNC Server (port 5900)
        │
        ▼
  Desktop Windows của runner
```

- **Không cần Tailscale**, không cần VPN.
- Runner GitHub không có IP public → dùng FRP để “đẩy” cổng ra ngoài.
- noVNC = VNC qua WebSocket, chạy hoàn toàn trên trình duyệt.

---

## Chuẩn bị (chỉ làm 1 lần)

### 1. Deploy server FRP trên Railway (hoặc VPS bất kỳ)

1. Tạo project Railway → Deploy from GitHub → chọn repo này → **Root Directory = `railway-frp`**.
2. Thêm biến môi trường: `FRP_TOKEN` = một chuỗi mật khẩu dài ngẫu nhiên (ví dụ `XyRDP-vn-2026-secret-xyz`).
3. Networking → **TCP Proxy**:
   - Port nội bộ **7000** → ghi lại endpoint (vd: `roundhouse.proxy.rlwy.net:12345`) → đây là **máy chủ điều khiển FRP**.
   - Port nội bộ **13389** → ghi lại endpoint (vd: `roundhouse.proxy.rlwy.net:23456`) → đây là **cổng public cho noVNC**.
4. Trong repo GitHub → Settings → Secrets and variables → Actions:
   - Secret `FRP_TOKEN` = giá trị `FRP_TOKEN` ở trên.
   - Secret `RDP_PASSWORD` = mật khẩu đăng nhập desktop (tối thiểu 8 ký tự).
   - Variable `FRP_SERVER` = endpoint điều khiển (host:port, ví dụ `roundhouse.proxy.rlwy.net:12345`).
   - Variable `FRP_REMOTE_PORT` = `13389` (hoặc để trống, mặc định 13389).

> Nếu dùng VPS riêng: cài `frps`, mở port 7000 + 13389, điền `FRP_SERVER` = `IP_VPS:7000`.

### 2. Fork / tạo repo từ template

Tạo repository từ template này, bật GitHub Actions.

---

## Chạy phiên làm việc

1. Vào tab **Actions** → chọn workflow **XyRDP-VN — Màn hình 6 giờ**.
2. **Run workflow** → điền:
   - `thoi_gian_phut`: 10–360 (mặc định 360).
   - `ten_may`: tiền tố hostname (mặc định `xyrdp`).
   - `ten_nguoi_dung`: tài khoản Windows (mặc định `xyadmin`).
3. Đợi khoảng 3–8 phút (cài VNC + noVNC + FRP).
4. Xem log bước **Công bố địa chỉ truy cập** hoặc file artifact `trang-thai` → sẽ có dòng:

   ```
   Địa chỉ xem màn hình: http://roundhouse.proxy.rlwy.net:23456
   Mật khẩu VNC: (cùng RDP_PASSWORD)
   ```

5. Mở link trên trình duyệt → nhập mật khẩu VNC → dùng được ngay.

---

## Bảo mật

- `FRP_TOKEN` và `RDP_PASSWORD` **không** được in ra log công khai.
- FRP chỉ cho phép remote port cố định (13389).
- Nên đổi `FRP_TOKEN` định kỳ.
- Runner GitHub là máy dùng một lần, hết giờ tự hủy.
- **Không** dùng máy làm việc chính để chạy workflow này.

---

## Cấu trúc thư mục

```
.github/workflows/xyrdp-vn.yml   ← Workflow chính
scripts/
  lib-chung.ps1                  ← Hàm dùng chung
  cai-rdp-co-ban.ps1             ← Tạo user, bật desktop
  cai-vnc-novnc.ps1              ← Cài TightVNC + noVNC
  cai-frp.ps1                    ← Kết nối FRP public
  giu-phien.ps1                  ← Keepalive
  ket-thuc.ps1                   ← Dọn dẹp
  cong-bo-trang-thai.ps1         ← Xuất địa chỉ truy cập
railway-frp/                     ← Server FRP deploy lên Railway/VPS
README.md                        ← File này (tiếng Việt)
```

---

## Giới hạn

- Thời gian tối đa mỗi job GitHub-hosted: **360 phút** (6 giờ).
- Đây không phải máy chơi game chuyên dụng; có thể bị suspend.
- noVNC phù hợp làm việc văn phòng, duyệt web, code nhẹ. Game nặng nên cân nhắc client VNC native hoặc giữ RDP qua FRP (có thể bật lại sau).

---

## Giấy phép & ghi công

Dựa trên RdpFree / XyRDP của KallAncrit.  
Bản này được viết lại hoàn toàn: bỏ Tailscale, chuyển sang noVNC + FRP, Việt hóa 100%.
