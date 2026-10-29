# XyRDP-VN — Kết thúc phiên, dọn dẹp
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot/lib-chung.ps1"
$XyTag = 'XyRDP-VN:ket-thuc'

Log 'Đang kết thúc phiên...'

# Dừng frpc
Get-Process -Name 'frpc' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Dừng websockify / python liên quan
Get-Process -Name 'python','python3' -ErrorAction SilentlyContinue | Where-Object {
  try {
    $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine
    $cmd -match 'websockify'
  } catch { $false }
} | Stop-Process -Force -ErrorAction SilentlyContinue

CapNhat-TrangThai @{
  phien = @{
    trang_thai = 'ket_thuc'
    ket_thuc   = (Get-Date).ToUniversalTime().ToString('o')
  }
} | Out-Null

Log 'Phiên đã kết thúc. Runner sẽ tự hủy.'
