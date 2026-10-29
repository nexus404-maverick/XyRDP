# XyRDP-VN — Công bố địa chỉ truy cập (in ra log + ghi file)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot/lib-chung.ps1"
$XyTag = 'XyRDP-VN:trang-thai'

$st = Lay-CauHinh
$dir = 'C:\XyRDP\out'
New-Item -ItemType Directory -Path $dir -Force | Out-Null

$remotePort = $null
if ($st.frp -and $st.frp.remote_port) { $remotePort = $st.frp.remote_port }
elseif ($env:FRP_REMOTE_PORT) { $remotePort = $env:FRP_REMOTE_PORT }
else { $remotePort = 13389 }

$server = $env:FRP_SERVER
$hostPublic = if ($server) { ($server -split ':')[0] } else { '(chưa cấu hình FRP_SERVER)' }

# Ghi chú: trên Railway, port public TCP proxy KHÁC với port nội bộ 13389.
# User phải dùng đúng endpoint TCP Proxy đã tạo (ví dụ :23456), không phải 13389.
$msg = @"

============================================================
  XyRDP-VN — ĐỊA CHỈ XEM MÀN HÌNH
============================================================
  Cách xem : Mở TRÌNH DUYỆT (Chrome / Firefox / Safari)
  Địa chỉ  : http://<HOST_TCP_PROXY_RAILWAY>:<PORT_PUBLIC>
             (HOST thường giống $hostPublic)
             Port public = endpoint TCP Proxy bạn tạo
             map tới cổng nội bộ $remotePort

  Mật khẩu VNC : (dùng secret RDP_PASSWORD)

  Không cần cài app RDP.
  Không cần Tailscale.
============================================================
"@

Write-Host $msg
$msg | Set-Content -Path (Join-Path $dir 'dia-chi-truy-cap.txt') -Encoding UTF8

# Upload artifact để user tải về
try {
  # Chỉ ghi file; bước upload do workflow hoặc actions/upload-artifact xử lý nếu cần
  ($st | ConvertTo-Json -Depth 8) | Set-Content (Join-Path $dir 'trang-thai.json') -Encoding UTF8
} catch {}

Log 'Đã công bố địa chỉ truy cập.'
