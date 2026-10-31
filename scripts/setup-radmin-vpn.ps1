# XyRDP: install and start Radmin VPN. Network join is intentionally left to the
# user in the official GUI because Famatech documents Create/Join through its UI;
# no supported unattended network-join CLI/API was verified.
$ErrorActionPreference = 'Stop'
function Log([string]$m) { Write-Host "[XyRDP:RadminVPN] $m" }
$work = 'C:\ProgramData\XyRDP\radmin-vpn'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$installer = Join-Path $work 'Radmin_VPN_2.1.4951.1.exe'
$uri = 'https://download.radmin-vpn.com/download/files/Radmin_VPN_2.1.4951.1.exe'
try {
  Log 'Downloading Radmin VPN 2.1.4951.1 from the supplied official URL...'
  Invoke-WebRequest -Uri $uri -OutFile $installer -TimeoutSec 180
  $signature = Get-AuthenticodeSignature -FilePath $installer
  if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Famatech') { throw "Installer signature is not valid from Famatech. Status: $($signature.Status); signer: $($signature.SignerCertificate.Subject)" }
  Log 'Authenticode signature verified. Installing silently...'
  $p = Start-Process -FilePath $installer -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/LOG=C:\ProgramData\XyRDP\radmin-vpn\install.log' -Wait -PassThru
  if ($p.ExitCode -notin @(0,3010)) { throw "Radmin VPN installer exit code: $($p.ExitCode)" }
  $service = Get-Service -Name 'RvControlSvc' -ErrorAction SilentlyContinue
  if ($service) {
    Set-Service -Name $service.Name -StartupType Automatic
    if ($service.Status -ne 'Running') { Start-Service -Name $service.Name }
    Log 'Radmin VPN control service is running.'
  } else { Log 'Radmin VPN service was not found yet; GUI launch will be attempted.' }
  $gui = @(
    'C:\Program Files (x86)\Radmin VPN\RvRvpnGui.exe',
    'C:\Program Files\Radmin VPN\RvRvpnGui.exe'
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $gui) { throw 'Radmin VPN installed but RvRvpnGui.exe was not found.' }
  $running = Get-Process -Name 'RvRvpnGui' -ErrorAction SilentlyContinue
  if (-not $running) { Start-Process -FilePath $gui -ArgumentList '/minimized'; Log 'Radmin VPN GUI launched minimized.' }
  else { Log 'Radmin VPN GUI is already running.' }
  Start-Sleep -Seconds 8
  $adapter = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -match 'Radmin VPN' -or $_.Name -match 'Radmin VPN' } | Select-Object -First 1
  $ip = ''
  if ($adapter) {
    $ip = (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -like '26.*' } | Select-Object -First 1 -ExpandProperty IPAddress)
  }
  $status = if ($ip) { 'adapter_detected' } else { 'awaiting_network_join' }
  $adapterName = if ($adapter) { $adapter.Name } else { '' }
  $out = Join-Path (Get-Location) 'out\rdp-status.json'
  if (Test-Path $out) {
    $json = Get-Content $out -Raw | ConvertFrom-Json
    if (-not $json.akses) { $json | Add-Member -NotePropertyName akses -NotePropertyValue ([pscustomobject]@{}) -Force }
    $json.akses | Add-Member -NotePropertyName mode -NotePropertyValue 'radmin' -Force
    $json.akses | Add-Member -NotePropertyName radmin -NotePropertyValue ([pscustomobject]@{status=$status;ip=$ip;adapter=$adapterName;version='2.1.4951.1';note='Join the same Radmin VPN network on host and client using the official GUI. Radmin VPN network name/password are not account credentials.'}) -Force
    $json | ConvertTo-Json -Depth 8 | Set-Content -Path $out -Encoding utf8
  }
  if ($ip) { Log "Radmin adapter detected. IPv4: $ip" }
  else { Log 'Radmin VPN installed. Join/create a network in its GUI; then use the displayed 26.x.x.x address.' }
  Log 'No Tailscale client or auth key is used by this Windows access path.'
} catch {
  Log "ERROR: $($_.Exception.Message)"
  throw
}
