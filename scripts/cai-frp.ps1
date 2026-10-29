# XyRDP-VN — Kết nối FRP để mở IP công khai + port ra ngoài internet
# Yêu cầu secret: FRP_TOKEN, biến: FRP_SERVER (host:port), FRP_REMOTE_PORT (mặc định 13389)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/lib-chung.ps1"
$XyTag = 'XyRDP-VN:frp'

$work = 'C:\XyRDP\frp'
New-Item -ItemType Directory -Path $work -Force | Out-Null

$token = $env:FRP_TOKEN
$server = $env:FRP_SERVER
$remotePort = if ($env:FRP_REMOTE_PORT) { $env:FRP_REMOTE_PORT.Trim() } else { '13389' }

if (-not $token) { throw 'Thiếu secret FRP_TOKEN. Hãy đặt trong GitHub Secrets.' }
if (-not $server -or $server -notmatch ':') {
  throw 'Thiếu biến FRP_SERVER (định dạng host:port, ví dụ roundhouse.proxy.rlwy.net:12345).'
}

$parts = $server -split ':', 2
$frpHost = $parts[0]
$frpPort = $parts[1]

Log "FRP server = ${frpHost}:${frpPort} | remotePort = $remotePort"

# Tải frpc (Windows amd64)
$ver = '0.61.1'
$zipName = "frp_${ver}_windows_amd64.zip"
$zipPath = Join-Path $work $zipName
$url = "https://github.com/fatedier/frp/releases/download/v${ver}/${zipName}"

Log "Đang tải frpc v${ver}..."
if (-not (Tai-Tep $url $zipPath 90)) {
  throw "Không tải được frpc từ $url"
}
Expand-Archive -Path $zipPath -DestinationPath $work -Force
$frpcDir = Get-ChildItem $work -Directory | Where-Object { $_.Name -like 'frp_*' } | Select-Object -First 1
$frpcExe = Join-Path $frpcDir.FullName 'frpc.exe'
if (-not (Test-Path $frpcExe)) { throw 'Không tìm thấy frpc.exe sau khi giải nén.' }

# Tạo file cấu hình frpc — proxy noVNC (6080)
$toml = @"
serverAddr = "$frpHost"
serverPort = $frpPort
auth.method = "token"
auth.token = "$token"

[[proxies]]
name = "xyrdp-novnc"
type = "tcp"
localIP = "127.0.0.1"
localPort = 6080
remotePort = $remotePort
"@
$cfgPath = Join-Path $work 'frpc.toml'
$toml | Set-Content -Path $cfgPath -Encoding UTF8

Log 'Khởi động frpc (nền)...'
$logFile = Join-Path $work 'frpc.log'
Start-Process -FilePath $frpcExe -ArgumentList @('-c', $cfgPath) `
  -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err" `
  -WorkingDirectory $work

Start-Sleep -Seconds 6

# Kiểm tra frpc còn sống
$frpcProc = Get-Process -Name 'frpc' -ErrorAction SilentlyContinue
if (-not $frpcProc) {
  Log 'frpc không chạy. Log:'
  if (Test-Path $logFile) { Get-Content $logFile -Tail 30 | ForEach-Object { Log $_ } }
  if (Test-Path "$logFile.err") { Get-Content "$logFile.err" -Tail 30 | ForEach-Object { Log $_ } }
  throw 'frpc khởi động thất bại. Kiểm tra FRP_TOKEN và FRP_SERVER.'
}

Log "frpc đang chạy (PID $($frpcProc.Id))."

# Địa chỉ public (user cần biết endpoint TCP proxy của Railway tương ứng remotePort)
# Thường là cùng host với FRP_SERVER nhưng port khác (port TCP proxy 13389).
# Ta lưu remotePort; dashboard/user tự ghép với host public đã ghi khi deploy.
CapNhat-TrangThai @{
  frp = @{
    trang_thai   = 'ok'
    server       = $server
    remote_port  = [int]$remotePort
    local_port   = 6080
    ghi_chu      = 'Mở http://<HOST_PUBLIC_TCP_PROXY>:<PORT_PUBLIC> trên trình duyệt. Mật khẩu VNC = RDP_PASSWORD.'
  }
  truy_cap = @{
    loai         = 'novnc'
    cong_local   = 6080
    cong_public  = [int]$remotePort
    huong_dan    = 'Dùng endpoint TCP Proxy của Railway/VPS (port map tới 13389). Ví dụ: http://roundhouse.proxy.rlwy.net:23456'
  }
} | Out-Null

Log "FRP sẵn sàng. Public remotePort = $remotePort → local noVNC 6080"
Log 'Mở trình duyệt tới endpoint TCP Proxy (port public bạn đã tạo trên Railway) để xem màn hình.'
