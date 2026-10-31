# RdpFree: disconnect only its Tailscale/Portmap/Railway session, never kill unrelated SSH processes.
$XyTag='RdpFree:finalize'
. "$PSScriptRoot/lib-common.ps1"
# Stop only the Sunshine service/process created for this session.
$svc = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') {
  try { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue; Log 'Sunshine service dihentikan.' } catch {}
}
Get-Process -Name 'sunshine' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Log 'Sesi dihentikan. Mesin self-hosted tidak dihapus otomatis.'

$portmapRoot='C:\ProgramData\RdpFree\portmap'
foreach ($pf in @('pid.txt', 'railway-pid.txt')) {
  $pidFile = Join-Path $portmapRoot $pf
  if (Test-Path $pidFile) {
    $pidValue = 0
    if ([int]::TryParse((Get-Content $pidFile -Raw).Trim(), [ref]$pidValue)) {
      $process = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
      if ($process) { $process | Stop-Process -Force -ErrorAction SilentlyContinue }
    }
  }
}
Remove-Item (Join-Path $portmapRoot 'client.ovpn'), (Join-Path $portmapRoot 'pid.txt'), (Join-Path $portmapRoot 'railway-pid.txt') -Force -ErrorAction SilentlyContinue
Remove-NetFirewallRule -DisplayName 'RdpFree Portmap RDP' -ErrorAction SilentlyContinue
Log 'Tunnel sesi ini ditutup; konfigurasi privat lokal dibersihkan.'
