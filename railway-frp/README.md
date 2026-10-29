# Server FRP cho XyRDP-VN (mở IP công khai)

Gói này là **máy chủ frp (frps)** — deploy **một lần** lên Railway (hoặc VPS).

Sau khi chạy, workflow XyRDP-VN sẽ kết nối frpc từ runner GitHub → frps của bạn → cổng TCP public, để bạn mở trình duyệt xem màn hình noVNC.

## Luồng kết nối

```
Điện thoại/PC (trình duyệt)
    → http://HOST_PUBLIC:PORT_PUBLIC
    → TCP Proxy Railway (map tới 13389)
    → frps (trong container Railway)
    → frpc (trong GitHub Actions)
    → noVNC :6080 → TightVNC :5900 → Desktop Windows
```

## Deploy trên Railway (1 lần)

1. Railway → New Project → Deploy from GitHub → chọn repo XyRDP-VN  
   → Settings → **Root Directory = `railway-frp`**.
2. Variables → thêm `FRP_TOKEN` = mật khẩu dài ngẫu nhiên  
   (sẽ dùng lại làm secret `FRP_TOKEN` trên GitHub).
3. Networking → **TCP Proxy** thêm 2 dòng:
   - Cổng nội bộ **7000** → ghi endpoint (vd `xxx.proxy.rlwy.net:12345`)  
     → đây là **FRP_SERVER** (host:port).
   - Cổng nội bộ **13389** → ghi endpoint (vd `xxx.proxy.rlwy.net:23456`)  
     → đây là **địa chỉ mở trình duyệt** để xem màn hình.
4. GitHub repo → Settings → Secrets and variables → Actions:
   - Secret **`FRP_TOKEN`** = giá trị ở bước 2
   - Secret **`RDP_PASSWORD`** = mật khẩu desktop / VNC
   - Variable **`FRP_SERVER`** = endpoint cổng 7000 (host:port)
   - Variable **`FRP_REMOTE_PORT`** = `13389` (có thể bỏ trống)

## Chạy phiên

Actions → **XyRDP-VN — Màn hình 6 giờ** → Run workflow.  
Sau 3–8 phút, mở link `http://<endpoint-cổng-13389>` trên trình duyệt, nhập mật khẩu VNC (= RDP_PASSWORD).

## Lưu ý

- Railway tính phí theo usage; gói Hobby thường đủ cho cộng đồng nhỏ.
- `allowPorts` chỉ cho phép remote port 13389.
- Không chia sẻ `FRP_TOKEN`.
- Thời gian phiên vẫn bị giới hạn bởi GitHub Actions (tối đa ~6 giờ).
