# XyRDP: stop only this session's Radmin VPN GUI; never kill unrelated processes.
$XyTag='RdpFree:finalize'
. "$PSScriptRoot/lib-common.ps1"
# Stop only the Radmin VPN GUI process started by the session.
Get-Process -Name 'RvRvpnGui' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$svc = Get-Service -Name 'RvControlSvc' -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') { try { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue; Log 'Radmin VPN service dihentikan.' } catch {} }
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
