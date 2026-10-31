# XyRDP: Sunshine host setup for Moonlight clients.
# No Tailscale account or identity provider is used. Network reachability is configured separately.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$XyTag = 'XyRDP:sunshine'
. "$PSScriptRoot/lib-common.ps1"

$work = 'C:\ProgramData\XyRDP\sunshine'
New-Item -ItemType Directory -Path $work -Force | Out-Null

function Set-SunshineStatus([hashtable]$value) {
  $path = Join-Path $env:GITHUB_WORKSPACE 'out\rdp-status.json'
  if (-not (Test-Path $path)) { return }
  try {
    $json = Get-Content $path -Raw | ConvertFrom-Json
    if (-not $json.PSObject.Properties['akses']) { $json | Add-Member -NotePropertyName akses -NotePropertyValue ([pscustomobject]@{}) }
    foreach ($key in $value.Keys) {
      $obj = $value[$key]
      if ($json.akses.PSObject.Properties[$key]) { $json.akses.$key = $obj }
      else { $json.akses | Add-Member -NotePropertyName $key -NotePropertyValue $obj }
    }
    $json | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8 $path
  } catch { Log "Không cập nhật được status Sunshine: $($_.Exception.Message)" }
}

try {
  Log 'Lấy bản Sunshine stable mới nhất từ GitHub Releases...'
  $headers = @{ 'User-Agent' = 'XyRDP-Sunshine-Setup'; 'Accept' = 'application/vnd.github+json' }
  $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/LizardByte/Sunshine/releases/latest' -Headers $headers -TimeoutSec 30
  $asset = @($release.assets | Where-Object { $_.name -eq 'Sunshine-Windows-AMD64-installer.msi' }) | Select-Object -First 1
  if (-not $asset -or -not $asset.browser_download_url) { throw 'Release stable không có MSI Windows AMD64.' }
  $msi = Join-Path $work 'Sunshine-Windows-AMD64-installer.msi'
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msi -Headers @{ 'User-Agent' = 'XyRDP-Sunshine-Setup' } -TimeoutSec 180
  if (-not (Test-Path $msi) -or (Get-Item $msi).Length -lt 1000000) { throw 'File MSI tải về không hợp lệ hoặc bị thiếu.' }
  $sig = Get-AuthenticodeSignature -FilePath $msi
  if ($sig.Status -ne 'Valid') { throw "Chữ ký MSI không hợp lệ: $($sig.Status)" }

  Log "Cài Sunshine $($release.tag_name) bằng MSI..."
  $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i',"`"$msi`"",'/qn','/norestart') -Wait -PassThru
  if ($proc.ExitCode -notin @(0,3010)) { throw "Cài Sunshine thất bại, msiexec exit $($proc.ExitCode)" }

  # Sunshine streaming ports. Web UI 47990 is intentionally NOT opened to the Internet.
  $tcpPorts = @(47984,47989,48010)
  $udpPorts = @(47998,47999,48000,48002,48010)
  foreach ($port in $tcpPorts) {
    Get-NetFirewallRule -DisplayName "XyRDP Sunshine TCP $port" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "XyRDP Sunshine TCP $port" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port -Profile Any | Out-Null
  }
  foreach ($port in $udpPorts) {
    Get-NetFirewallRule -DisplayName "XyRDP Sunshine UDP $port" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "XyRDP Sunshine UDP $port" -Direction Inbound -Action Allow -Protocol UDP -LocalPort $port -Profile Any | Out-Null
  }

  $service = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
  if (-not $service) { $service = Get-Service | Where-Object { $_.DisplayName -match '^Sunshine' } | Select-Object -First 1 }
  if ($service) {
    Set-Service -Name $service.Name -StartupType Automatic
    Start-Service -Name $service.Name
    Log "Sunshine service đang chạy: $($service.Name)"
  } else {
    $exe = @(
      "$env:ProgramFiles\Sunshine\sunshine.exe",
      "$env:ProgramFiles\Sunshine\tools\sunshine.exe",
      "${env:ProgramFiles(x86)}\Sunshine\sunshine.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $exe) {
      $exe = Get-ChildItem "$env:ProgramFiles\Sunshine" -Filter sunshine.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $exe) { throw 'Đã cài MSI nhưng không tìm thấy sunshine.exe hoặc Windows service.' }
    Start-Process -FilePath $exe -WindowStyle Hidden
    Log 'Sunshine được khởi chạy nền.'
  }

  Start-Sleep -Seconds 5
  $localIps = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } |
    Select-Object -ExpandProperty IPAddress -Unique)
  $sunshine = @{
    status = 'ok'
    version = "$($release.tag_name)"
    host = ($localIps -join ', ')
    ports_tcp = $tcpPorts
    ports_udp = $udpPorts
    web_ui = 'https://localhost:47990'
    web_ui_public = $false
    pairing = 'Open Sunshine Web UI on the host, finish first-run setup, then pair Moonlight using its PIN.'
    note = 'No Tailscale account. Forward TCP 47984, 47989, 48010 and UDP 47998-48000, 48002, 48010 on the router/provider. Public inbound access is not guaranteed on hosted CI runners or CGNAT.'
  }
  Set-SunshineStatus @{ mode='sunshine'; sunshine=$sunshine; tunnel=@{status='pending'; note='Sunshine ready; external route/port forwarding must be provided by the host network.'} }
  Log "Sunshine $($release.tag_name) đã sẵn sàng. Web UI nội bộ: https://localhost:47990"
  Log 'Moonlight pairing yêu cầu PIN; không cần tài khoản Tailscale/Sunshine.'
} catch {
  Log "SUNSHINE ERROR: $($_.Exception.Message)"
  Set-SunshineStatus @{ mode='sunshine'; sunshine=@{status='failed';note=$_.Exception.Message} }
  throw
}
