# XyRDP-VN — Cài đặt cơ bản: tạo user + bật Remote Desktop (dự phòng)
# noVNC là cách xem chính; RDP vẫn được bật để dùng khi cần.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/lib-chung.ps1"
$XyTag = 'XyRDP-VN:co-ban'

if (-not $env:RDP_PASSWORD -or $env:RDP_PASSWORD.Length -lt 8) {
  Log 'LỖI: Secret RDP_PASSWORD chưa được đặt hoặc ngắn hơn 8 ký tự.'
  exit 1
}

$dur = [int](($env:THOI_GIAN -replace '\D', ''))
if ($dur -lt 10) { $dur = 60 }
if ($dur -gt 360) { $dur = 360 }

$u = if ($env:TEN_NGUOI_DUNG) { $env:TEN_NGUOI_DUNG.Trim() } else { 'xyadmin' }
$reserved = @('administrator','guest','defaultaccount','wdagutilityaccount','system','localservice','networkservice')
if ($u -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]{2,19}$' -or $reserved -contains $u.ToLower()) {
  Log 'LỖI: Tên người dùng không hợp lệ (3–20 ký tự, chữ/số/_/-).'
  exit 1
}

$hostBase = ($env:TEN_MAY -replace '[^a-zA-Z0-9-]', '').ToLower().Trim('-')
if (-not $hostBase) { $hostBase = 'xyrdp' }
if ($hostBase.Length -gt 30) { $hostBase = $hostBase.Substring(0, 30) }
$hostName = "$hostBase-$env:GITHUB_RUN_NUMBER"

Log "Bắt đầu | hostname=$hostName | thời gian=${dur} phút | user=$u"

# --- Tạo / cập nhật user ---
$sp = ConvertTo-SecureString $env:RDP_PASSWORD -AsPlainText -Force
if ($u.ToLower() -eq 'runneradmin') {
  Log 'Dùng tài khoản runneradmin có sẵn.'
  try { Set-LocalUser -Name $u -Password $sp -PasswordNeverExpires $true -AccountNeverExpires -ErrorAction Stop | Out-Null } catch {
    & net user $u $env:RDP_PASSWORD 2>&1 | Out-Null
  }
} else {
  if (Get-LocalUser -Name $u -ErrorAction SilentlyContinue) {
    Remove-LocalUser -Name $u -ErrorAction SilentlyContinue
  }
  New-LocalUser -Name $u -Password $sp -FullName 'XyRDP-VN Admin' `
    -PasswordNeverExpires -AccountNeverExpires -Description 'XyRDP-VN remote user' | Out-Null
  Log "Đã tạo user $u"
}

# Thêm vào Administrators + Remote Desktop Users
try { Add-LocalGroupMember -Group 'Administrators' -Member $u -ErrorAction SilentlyContinue } catch {}
try { Add-LocalGroupMember -Group 'Remote Desktop Users' -Member $u -ErrorAction SilentlyContinue } catch {}

# --- Bật Remote Desktop (dự phòng, không bắt buộc dùng) ---
try {
  Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0
  Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue | Out-Null
  Set-Service -Name 'TermService' -StartupType Automatic -ErrorAction SilentlyContinue
  Start-Service -Name 'TermService' -ErrorAction SilentlyContinue
  Log 'Remote Desktop (3389) đã bật (dự phòng).'
} catch {
  Log "Cảnh báo khi bật RDP: $($_.Exception.Message)"
}

# Đặt hostname
try {
  Rename-Computer -NewName $hostName -Force -ErrorAction SilentlyContinue
} catch {}

$os = try { (Get-CimInstance Win32_OperatingSystem).Caption } catch { 'Windows' }
CapNhat-TrangThai @{
  phien = @{
    hostname     = $hostName
    nguoi_dung   = $u
    thoi_gian_phut = $dur
    he_dieu_hanh = $os
    bat_dau      = (Get-Date).ToUniversalTime().ToString('o')
  }
} | Out-Null

Log "Cài đặt cơ bản xong. User: $u | Hostname: $hostName"
