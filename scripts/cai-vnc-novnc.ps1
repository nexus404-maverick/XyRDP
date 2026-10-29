# XyRDP-VN — Cài TightVNC Server + noVNC (xem màn hình bằng trình duyệt)
# Không cần client RDP. Chỉ cần mở link HTTP trên Chrome/Firefox.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/lib-chung.ps1"
$XyTag = 'XyRDP-VN:vnc'

$work = 'C:\XyRDP\vnc'
New-Item -ItemType Directory -Path $work -Force | Out-Null
$pass = $env:RDP_PASSWORD
if (-not $pass -or $pass.Length -lt 8) { throw 'Thiếu RDP_PASSWORD (dùng làm mật khẩu VNC).' }

# ------------------------------------------------------------------
# 1. Cài TightVNC Server
# ------------------------------------------------------------------
$tvncMsi = Join-Path $work 'tightvnc.msi'
$tvncUrl = 'https://www.tightvnc.com/download/2.8.81/tightvnc-2.8.81-gpl-setup-64bit.msi'

Log 'Đang tải TightVNC...'
if (-not (Tai-Tep $tvncUrl $tvncMsi 120)) {
  # Fallback mirror
  $tvncUrl2 = 'https://github.com/TigerVNC/tigervnc/releases/download/v1.13.1/tigervnc64-1.13.1.exe'
  Log 'TightVNC chính thức lỗi, thử cách khác...'
  throw 'Không tải được TightVNC. Kiểm tra mạng runner.'
}

# Cài silent: SET_USEVNCAUTHENTICATION=1, SET_PASSWORD, SET_VIEWONLY_PASSWORD, đăng ký service
$msiArgs = @(
  '/i', "`"$tvncMsi`"",
  '/quiet', '/norestart',
  'ADDLOCAL=Server',
  'SET_USEVNCAUTHENTICATION=1',
  "VALUE_OF_PASSWORD=$pass",
  "VALUE_OF_VIEWONLY_PASSWORD=$pass",
  'SET_USECONTROLAUTHENTICATION=1',
  "VALUE_OF_CONTROLPASSWORD=$pass",
  'SET_RUNCONTROLINTERFACE=0',
  'SET_DISCONNECTACTION=1',
  'SET_ALLOWLOOPBACK=1',
  'SERVER_REGISTER_AS_SERVICE=1',
  'SERVER_ADD_FIREWALL_EXCEPTION=1'
)
Log 'Đang cài TightVNC Server...'
$inst = Chay-LenhGioiHan 'msiexec.exe' $msiArgs 180
Log "TightVNC installer exit code: $($inst.code)"
if ($inst.code -notin @(0, 3010)) {
  Log "Cảnh báo cài TightVNC: $($inst.error)"
}

# Đảm bảo service chạy và lắng nghe 5900
$tvncSvc = 'tvnserver'
try {
  Set-Service -Name $tvncSvc -StartupType Automatic -ErrorAction SilentlyContinue
  Restart-Service -Name $tvncSvc -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
} catch {
  # Nếu service name khác (bản mới)
  Get-Service | Where-Object { $_.Name -match 'vnc|tight' } | ForEach-Object {
    Set-Service -Name $_.Name -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $_.Name -ErrorAction SilentlyContinue
  }
}

# Mở firewall cho 5900
try {
  New-NetFirewallRule -DisplayName 'XyRDP-VN VNC 5900' -Direction Inbound -Protocol TCP -LocalPort 5900 -Action Allow -ErrorAction SilentlyContinue | Out-Null
} catch {}

# Kiểm tra listener
$vncOk = $false
for ($i = 0; $i -lt 15; $i++) {
  $c = Get-NetTCPConnection -LocalPort 5900 -State Listen -ErrorAction SilentlyContinue
  if ($c) { $vncOk = $true; break }
  Start-Sleep -Seconds 2
}
if (-not $vncOk) {
  Log 'CẢNH BÁO: Cổng 5900 chưa lắng nghe. Thử khởi động tvnserver thủ công...'
  $tvn = "${env:ProgramFiles}\TightVNC\tvnserver.exe"
  if (Test-Path $tvn) {
    Start-Process $tvn -ArgumentList '-start' -NoNewWindow -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
  }
}

Log "TightVNC: cổng 5900 = $(if ($vncOk) { 'OK' } else { 'chưa chắc' })"

# ------------------------------------------------------------------
# 2. Cài noVNC + websockify (Python)
# ------------------------------------------------------------------
Log 'Đang chuẩn bị noVNC...'

# Đảm bảo Python có sẵn (runner Windows thường có)
$py = $null
foreach ($c in @('python', 'py', 'python3')) {
  try {
    $v = & $c --version 2>&1
    if ($v -match 'Python') { $py = $c; break }
  } catch {}
}
if (-not $py) {
  Log 'Không tìm thấy Python. Thử cài qua winget/choco...'
  try {
    & winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $py = 'python'
  } catch {
    throw 'Không có Python để chạy websockify/noVNC.'
  }
}
Log "Dùng Python: $py ($(& $py --version 2>&1))"

# Cài websockify
& $py -m pip install --quiet --upgrade pip websockify 2>&1 | Out-Null

# Tải noVNC
$novncDir = Join-Path $work 'noVNC'
if (-not (Test-Path $novncDir)) {
  $zip = Join-Path $work 'novnc.zip'
  $ok = Tai-Tep 'https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.zip' $zip 90
  if (-not $ok) { throw 'Không tải được noVNC.' }
  Expand-Archive -Path $zip -DestinationPath $work -Force
  Rename-Item (Join-Path $work 'noVNC-1.5.0') 'noVNC' -ErrorAction SilentlyContinue
}

# Mở firewall 6080
try {
  New-NetFirewallRule -DisplayName 'XyRDP-VN noVNC 6080' -Direction Inbound -Protocol TCP -LocalPort 6080 -Action Allow -ErrorAction SilentlyContinue | Out-Null
} catch {}

# Chạy websockify + noVNC ở nền
$novncHtml = Join-Path $novncDir 'vnc.html'
if (-not (Test-Path $novncHtml)) { $novncHtml = Join-Path $novncDir 'vnc_lite.html' }

$wsLog = Join-Path $work 'websockify.log'
$wsArgs = @(
  '-m', 'websockify',
  '--web', $novncDir,
  '6080',
  '127.0.0.1:5900'
)
Log "Khởi động noVNC trên cổng 6080 → VNC 5900..."
Start-Process -FilePath $py -ArgumentList $wsArgs -WindowStyle Hidden `
  -RedirectStandardOutput $wsLog -RedirectStandardError "$wsLog.err" `
  -WorkingDirectory $work

Start-Sleep -Seconds 4

$httpOk = $false
for ($i = 0; $i -lt 10; $i++) {
  $c = Get-NetTCPConnection -LocalPort 6080 -State Listen -ErrorAction SilentlyContinue
  if ($c) { $httpOk = $true; break }
  Start-Sleep -Seconds 2
}

if (-not $httpOk) {
  Log "CẢNH BÁO: noVNC chưa lắng nghe 6080. Xem log: $wsLog"
  if (Test-Path $wsLog) { Get-Content $wsLog -Tail 20 | ForEach-Object { Log $_ } }
} else {
  Log 'noVNC đã sẵn sàng tại http://127.0.0.1:6080/vnc.html'
}

CapNhat-TrangThai @{
  vnc = @{
    trang_thai = if ($vncOk) { 'ok' } else { 'canh_bao' }
    cong       = 5900
    mat_khau   = '(dùng RDP_PASSWORD)'
  }
  novnc = @{
    trang_thai = if ($httpOk) { 'ok' } else { 'canh_bao' }
    cong       = 6080
    duong_dan  = '/vnc.html'
  }
} | Out-Null

Log 'Hoàn tất cài TightVNC + noVNC.'
