# XyRDP-VN — Giữ phiên sống đến hết thời gian
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot/lib-chung.ps1"
$XyTag = 'XyRDP-VN:giu-phien'

$dur = [int](($env:THOI_GIAN -replace '\D', ''))
if ($dur -lt 10) { $dur = 60 }
if ($dur -gt 360) { $dur = 360 }

# Trừ thời gian setup ước lượng (~8 phút)
$conLai = [Math]::Max(5, $dur - 8)
$hetGio = (Get-Date).AddMinutes($conLai)

Log "Giữ phiên sống thêm khoảng $conLai phút (đến $($hetGio.ToString('HH:mm:ss')))."

$lan = 0
while ((Get-Date) -lt $hetGio) {
  $lan++
  $con = [int](($hetGio - (Get-Date)).TotalMinutes)
  if ($lan % 5 -eq 1) {
    Log "Còn khoảng $con phút | Kiểm tra dịch vụ..."
    # Kiểm tra VNC + noVNC + frpc
    $vnc = Get-NetTCPConnection -LocalPort 5900 -State Listen -ErrorAction SilentlyContinue
    $http = Get-NetTCPConnection -LocalPort 6080 -State Listen -ErrorAction SilentlyContinue
    $frpc = Get-Process -Name 'frpc' -ErrorAction SilentlyContinue
    Log "  VNC5900=$(if($vnc){'OK'}else{'OFF'})  noVNC6080=$(if($http){'OK'}else{'OFF'})  frpc=$(if($frpc){'OK'}else{'OFF'})"

    if (-not $frpc) {
      Log 'frpc đã tắt — thử khởi động lại...'
      $frpcExe = Get-ChildItem 'C:\XyRDP\frp' -Recurse -Filter 'frpc.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
      $cfg = 'C:\XyRDP\frp\frpc.toml'
      if ($frpcExe -and (Test-Path $cfg)) {
        Start-Process -FilePath $frpcExe.FullName -ArgumentList @('-c', $cfg) -WindowStyle Hidden -ErrorAction SilentlyContinue
      }
    }
    if (-not $http) {
      Log 'noVNC đã tắt — thử khởi động lại websockify...'
      $py = 'python'
      $novnc = 'C:\XyRDP\vnc\noVNC'
      if (Test-Path $novnc) {
        Start-Process -FilePath $py -ArgumentList @('-m','websockify','--web',$novnc,'6080','127.0.0.1:5900') `
          -WindowStyle Hidden -ErrorAction SilentlyContinue
      }
    }
  }
  # Heartbeat nhẹ để GitHub không coi job idle
  Start-Sleep -Seconds 60
}

Log 'Hết thời gian phiên. Kết thúc keepalive.'
